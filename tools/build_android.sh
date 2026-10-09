#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

# Safety boundary: require a valid KOMOREBI project root.
if [[ ! -f "$PROJECT_DIR/project.godot" ]]; then
    echo "[ERROR] Refusing to run outside a Godot project root."
    exit 90

fi

export ANDROID_HOME="${ANDROID_HOME:-$HOME/Android/Sdk}"
export ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-$ANDROID_HOME}"
export JAVA_HOME="${JAVA_HOME:-$HOME/tools/jdk21}"

export PATH="$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"

# apksigner/bundletool liegen in den Build-Tools, nicht im Haupt-Bin.
APKSIGNER="$(find "$ANDROID_HOME/build-tools" -name apksigner -type f 2>/dev/null | sort -V | tail -n 1)"
export PATH="$(dirname "${APKSIGNER:-$ANDROID_HOME/build-tools/35.0.0}"):$PATH"

GODOT="${GODOT:-flatpak run org.godotengine.Godot}"
AVD="${AVD:-starq}"
ADB_SERIAL="${ADB_SERIAL:-emulator-5554}"
PACKAGE="${KOMOREBI_PACKAGE:-de.komorebi.game}"

# SwiftShader (Software-GL) ueberschreitet weder Vulkan-Present noch das
# GLES3-Uniform-Limit des Emulators gut genug fuer stabile Screenshots.
# Host-GPU rendert hier zuverlaessig.
EMULATOR_GPU="${EMULATOR_GPU:-host}"
# Im headless-Betrieb kein Fenster oeffnen; Ueber ADB ist alles steuerbar.
EMULATOR_FLAGS="${EMULATOR_FLAGS:--no-window}"

BUILD_DIR="$PROJECT_DIR/build/android"
ARTIFACTS="$PROJECT_DIR/artifacts"

# Artefaktpfade. `debug` ist die schnelle Testschleife, `release` und `aab`
# sind die Release-Artefakte. Alle drei teilen sich Application ID und
# Version, damit der Emulator-Test das echte Release-Binary trifft.
DEBUG_APK="$BUILD_DIR/komorebi-debug.apk"
RELEASE_APK="$BUILD_DIR/komorebi-release.apk"
RELEASE_AAB="$BUILD_DIR/komorebi-release.aab"
PRESET_DEBUG="Android Debug"
PRESET_RELEASE="Android Release"
PRESET_AAB="Android AAB"

mkdir -p "$ARTIFACTS" "$BUILD_DIR"

log() {
    echo
    echo "==> $*"
}

die() {
    echo "[ERROR] $*" >&2
    exit 1
}

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || die "Nicht gefunden: $1"
}

wait_for_device() {
    log "Warte auf ADB-Gerät $ADB_SERIAL ..."
    for _ in {1..120}; do
        if adb devices | awk '$1 == "'"$ADB_SERIAL"'" && $2 == "device" { found=1 } END { exit !found }'; then
            break
        fi
        sleep 1
    done

    adb devices | grep -q "^${ADB_SERIAL}[[:space:]]\+device$" \
        || die "Emulator wurde nicht als 'device' erkannt."

    log "Warte auf Android-Boot ..."
    for _ in {1..120}; do
        [[ "$(adb -s "$ADB_SERIAL" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" == "1" ]] && return 0
        sleep 1
    done

    die "Android-Boot wurde nicht innerhalb des Zeitlimits abgeschlossen."
}

ensure_emulator() {
    if adb devices | grep -q "^${ADB_SERIAL}[[:space:]]\+device$"; then
        if [[ "$(adb -s "$ADB_SERIAL" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" == "1" ]]; then
            log "Emulator läuft bereits: $ADB_SERIAL"
            return
        fi
    fi

    log "Starte AVD '$AVD' mit GPU '$EMULATOR_GPU' ..."
    adb start-server >/dev/null

    if pgrep -af "emulator.*-avd[[:space:]]+$AVD" >/dev/null 2>&1; then
        log "AVD-Prozess läuft bereits."
    else
        # shellcheck disable=SC2086
        nohup emulator -avd "$AVD" -no-snapshot-load -gpu "$EMULATOR_GPU" $EMULATOR_FLAGS \
            >"$ARTIFACTS/emulator.log" 2>&1 &
        echo $! > "$ARTIFACTS/emulator.pid"
    fi

    wait_for_device
}

## Exportiert ein Preset. Godot schreibt bei Erfolg kein "OK" auf stdout,
# deshalb wird die Datei direkt geprüft - nur so fällt ein Parse-Fehler im
## GDScript auf, der den Export ohne APK/AAB abbricht.
export_preset() {
    local preset="$1" target="$2" mode="$3" label="$4"
    log "Exportiere $label ($preset) -> $target"

    rm -f "$target" "$target.idsig"
    local log_file="$ARTIFACTS/godot-export-${label}.log"

    # Das Release-Passwort steht nur waehrend des Exports im Preset und wird
    # danach wieder entfernt - so liegt kein Secret in einer versionierten Datei.
    if [[ "$mode" == "release" ]]; then
        python3 "$PROJECT_DIR/tools/release_keystore.py" apply
    fi

    set +e
    $GODOT --headless --path "$PROJECT_DIR" \
        "--export-$mode" "$preset" "$target" \
        2>&1 | tee "$log_file"
    local status="${PIPESTATUS[0]}"
    set -e

    if [[ "$mode" == "release" ]]; then
        python3 "$PROJECT_DIR/tools/release_keystore.py" clear
    fi

    [[ $status -eq 0 ]] || die "Godot-Export beendet mit Status $status (siehe $log_file)."
    [[ -f "$target" ]] || die "Godot hat kein Artefakt erzeugt: $target"

    # Ein GDScript-Parse-Fehler ist eine ERROR-Zeile und bricht den Export ab.
    # Beides wird hier geprüft, nicht nur ERROR allein.
    if grep -nE "SCRIPT ERROR|Parse Error|^ERROR|FATAL|Exception" "$log_file"; then
        die "Der Export hat Fehler gemeldet (siehe $log_file)."
    fi
    log "$label gebaut: $(du -h "$target" | cut -f1)"
}

build_debug() {
    export_preset "$PRESET_DEBUG" "$DEBUG_APK" debug debug
}

build_release_apk() {
    export_preset "$PRESET_RELEASE" "$RELEASE_APK" release release-apk
}

build_aab() {
    export_preset "$PRESET_AAB" "$RELEASE_AAB" release aab
}

## Welches APK wird getestet? Standardmaessig das Release-Binary, weil nur
## dieses dem Play-Artefakt entspricht. `KOMOREBI_TEST_APK=debug` testet die
## schnellere Debug-Schleife.
test_apk() {
    if [[ "${KOMOREBI_TEST_APK:-release}" == "debug" ]]; then
        printf '%s\n' "$DEBUG_APK"
    else
        printf '%s\n' "$RELEASE_APK"
    fi
}

install() {
    local apk="$1"
    log "Installiere $(basename "$apk") ..."
    adb -s "$ADB_SERIAL" uninstall "$PACKAGE" >/dev/null 2>&1 || true
    adb -s "$ADB_SERIAL" install -r "$apk" \
        2>&1 | tee "$ARTIFACTS/adb-install.log"
    grep -q "Success" "$ARTIFACTS/adb-install.log" || die "Installation fehlgeschlagen."
}

resolve_activity() {
    log "Ermittle Launcher-Activity ..."

    local result
    result="$(adb -s "$ADB_SERIAL" shell cmd package resolve-activity \
        --brief "$PACKAGE" 2>/dev/null | tr -d '\r' | tail -n 1)"

    [[ "$result" == "$PACKAGE"/* ]] \
        || die "Keine gültige Launcher-Activity gefunden: '$result'"

    printf '%s\n' "$result" | tee "$ARTIFACTS/launcher.txt"
    ACTIVITY="$result"
}

start_app() {
    log "Starte $ACTIVITY ..."
    adb -s "$ADB_SERIAL" shell am force-stop "$PACKAGE" || true

    timeout 90 adb -s "$ADB_SERIAL" shell am start -W -n "$ACTIVITY" \
        2>&1 | tee "$ARTIFACTS/app-start.log"
}

capture() {
    log "Erzeuge Screenshot ..."
    # screencap kann bei rendernden Apps haengen; daher hart begrenzen.
    if ! timeout 45 adb -s "$ADB_SERIAL" exec-out screencap -p \
        > "$ARTIFACTS/screenshot.png"; then
        echo "[WARN] screencap fehlgeschlagen oder Timeout." >&2
    fi

    log "Sammle Logcat ..."
    local app_pid
    app_pid="$(adb -s "$ADB_SERIAL" shell pidof "$PACKAGE" 2>/dev/null | tr -d '\r')"

    if [[ -n "$app_pid" ]]; then
        timeout 60 adb -s "$ADB_SERIAL" logcat -d --pid="$app_pid" -t 500 \
            > "$ARTIFACTS/logcat.txt" || true
    else
        timeout 60 adb -s "$ADB_SERIAL" logcat -d -t 500 \
            > "$ARTIFACTS/logcat.txt" || true
    fi

    log "Extrahiere relevante Fehler ..."
    grep -iE 'FATAL EXCEPTION|AndroidRuntime|SIGSEGV|SIGABRT|SCRIPT ERROR|^.*: E |Error:|ERROR:' \
        "$ARTIFACTS/logcat.txt" \
        > "$ARTIFACTS/relevant-logcat.txt" || true
}

status() {
    log "Status"
    echo "Projekt:    $PROJECT_DIR"
    echo "Package:    $PACKAGE"
    echo "Debug-APK:  $DEBUG_APK"
    echo "Release-APK:$RELEASE_APK"
    echo "AAB:        $RELEASE_AAB"
    echo "Emulator:   $ADB_SERIAL"
    echo "AVD:        $AVD"
    echo "Godot:      $GODOT"
    echo "Java:       $JAVA_HOME"
    echo "SDK:        $ANDROID_HOME"
    echo
    adb devices
    echo
    adb -s "$ADB_SERIAL" shell getprop ro.product.model 2>/dev/null || true
    adb -s "$ADB_SERIAL" shell getprop ro.build.version.release 2>/dev/null || true
}

gameplay_test() {
    require_cmd adb
    ensure_emulator
    KOMOREBI_PACKAGE="$PACKAGE" ADB_SERIAL="$ADB_SERIAL" \
        python3 "$PROJECT_DIR/tools/gameplay_test.py" ${GAMEPLAY_ARGS:-} \
        2>&1 | tee "$ARTIFACTS/gameplay-test.log"
    return "${PIPESTATUS[0]}"
}

## Vollstaendiger Release-Durchgang: sauberer Build, Analyse, Test.
analyze() {
    log "Analysiere Release-Artefakte ..."

    for artifact in "$RELEASE_APK" "$RELEASE_AAB"; do
        [[ -f "$artifact" ]] || continue
        {
            echo "=============================================================="
            echo "Artefakt: $artifact"
            echo "Groesse:  $(du -h "$artifact" | cut -f1)"
            echo "Typ:      $(file -b "$artifact")"
            echo "=============================================================="
            if [[ "$artifact" == *.aab ]]; then
                analyze_aab "$artifact"
            else
                analyze_apk "$artifact"
            fi
            echo
        } | tee -a "$ARTIFACTS/release-report.txt"
    done

    log "Release-Prüfbericht: $ARTIFACTS/release-report.txt"
}

## APK: Application ID, Version, SDK, ABIs, Permissions, Signatur.
analyze_apk() {
    local apk="$1"
    echo "--- Application ID / Version ---"
    echo "applicationId: $(apkanalyzer manifest application-id "$apk")"
    echo "versionName:   $(apkanalyzer manifest version-name "$apk")"
    echo "versionCode:   $(apkanalyzer manifest version-code "$apk")"
    echo "--- SDK ---"
    echo "minSdk:        $(apkanalyzer manifest min-sdk "$apk")"
    echo "targetSdk:     $(apkanalyzer manifest target-sdk "$apk")"
    echo "--- ABIs ---"
    unzip -l "$apk" | awk -F/ '/lib\// {print $2}' | sort -u
    echo "--- Permissions ---"
    local permissions
    permissions="$(apkanalyzer manifest permissions "$apk")"
    echo "${permissions:-keine}"
    echo "--- Signing ---"
    if [[ -x "$APKSIGNER" ]]; then
        "$APKSIGNER" verify --print-certs -v "$apk" 2>&1 | head -20
    else
        echo "apksigner nicht gefunden - Signatur nicht geprueft"
    fi
    echo "--- Manifest (Auszug) ---"
    apkanalyzer manifest print "$apk" | grep -E "debuggable|versionCode|versionName|package=|minSdkVersion|targetSdkVersion|screenOrientation|label=" | head -12
    echo "--- native Bibliotheken ---"
    unzip -l "$apk" | awk '/lib\// {print $1, $4}' | sort -k2
}

## AAB: Manifest, ABIs und Signatur über bundletool.
analyze_aab() {
    local aab="$1"
    local classpath
    classpath="$(bash "$PROJECT_DIR/tools/bundletool.sh")"

    echo "--- Validierung (bundletool) ---"
    "$JAVA_HOME/bin/java" -cp "$classpath" com.android.tools.build.bundletool.BundleToolMain \
        validate --bundle="$aab" 2>&1 | sed -n '1,12p'

    echo "--- Manifest ---"
    for xpath in "/manifest/@package" \
                 "/manifest/@android:versionName" \
                 "/manifest/@android:versionCode" \
                 "/manifest/@android:compileSdkVersion" \
                 "/manifest/uses-sdk/@android:minSdkVersion" \
                 "/manifest/uses-sdk/@android:targetSdkVersion" \
                 "/manifest/application/@android:debuggable" \
                 "/manifest/application/@android:allowBackup" \
                 "/manifest/application/@android:label"; do
        local value
        value="$("$JAVA_HOME/bin/java" -cp "$classpath" \
            com.android.tools.build.bundletool.BundleToolMain \
            dump manifest --bundle="$aab" --xpath="$xpath" 2>/dev/null | tail -n 1)"
        printf '%-56s %s\n' "$xpath" "${value:-<nicht gesetzt>}"
    done

    echo "--- Permissions ---"
    local permissions
    permissions="$("$JAVA_HOME/bin/java" -cp "$classpath" \
        com.android.tools.build.bundletool.BundleToolMain \
        dump manifest --bundle="$aab" --xpath="/manifest/uses-permission" 2>/dev/null | tail -n 5)"
    echo "${permissions:-keine}"

    echo "--- ABIs ---"
    unzip -l "$aab" | awk -F/ '/^.*base\/lib\// {print $3}' | sort -u

    echo "--- Signatur (JAR-Signatur im Bundle) ---"
    unzip -l "$aab" | grep -E "META-INF/.*\.(RSA|SF|DSA|EC)$"

    echo "--- Debug-Reste im Bundle ---"
    local suspects
    suspects="$(unzip -l "$aab" | grep -icE "autoplay|_probe|test" || true)"
    echo "Dateien mit Test-/Debug-Bezug: $suspects"
}

clean() {
    log "Entferne erzeugte Test-Artefakte ..."
    rm -rf "$ARTIFACTS"
    rm -rf "$PROJECT_DIR/build"
    mkdir -p "$ARTIFACTS" "$BUILD_DIR"
}

case "${1:-full}" in
    emulator)
        require_cmd adb
        require_cmd emulator
        ensure_emulator
        status
        ;;
    debug)
        build_debug
        ;;
    build)
        build_release_apk
        ;;
    aab)
        build_aab
        ;;
    install)
        require_cmd adb
        ensure_emulator
        apk="$(test_apk)"
        [[ -f "$apk" ]] || die "APK fehlt: $apk"
        install "$apk"
        ;;
    run)
        require_cmd adb
        ensure_emulator
        apk="$(test_apk)"
        [[ -f "$apk" ]] || die "APK fehlt: $apk"
        resolve_activity
        start_app
        capture
        ;;
    test)
        gameplay_test
        ;;
    analyze)
        analyze
        ;;
    full)
        require_cmd adb
        require_cmd emulator
        build_release_apk
        ensure_emulator
        apk="$(test_apk)"
        install "$apk"
        resolve_activity
        start_app
        capture
        gameplay_test
        status
        ;;
    release)
        # Kompletter Release-Durchgang ohne Emulator: sauber bauen, AAB
        # erzeugen und beide Artefakte technisch pruefen.
        build_release_apk
        build_aab
        analyze
        ;;
    logcat)
        require_cmd adb
        adb -s "$ADB_SERIAL" logcat -d -t 1000
        ;;
    status)
        require_cmd adb
        status
        ;;
    clean)
        clean
        ;;
    *)
        cat <<USAGE
Verwendung:
  ./tools/build_android.sh emulator   AVD starten und auf Boot warten
  ./tools/build_android.sh debug      Debug-APK bauen (schnelle Schleife)
  ./tools/build_android.sh build      Release-APK bauen
  ./tools/build_android.sh aab        Android App Bundle bauen
  ./tools/build_android.sh release    Release-APK + AAB bauen und analysieren
  ./tools/build_android.sh install    getestetes APK installieren
  ./tools/build_android.sh run        starten + Screenshot + Logcat
  ./tools/build_android.sh test       vollständiger Gameplay-Test
  ./tools/build_android.sh analyze    Artefakte technisch prüfen
  ./tools/build_android.sh full       Release-APK + Emulator-Test
  ./tools/build_android.sh logcat
  ./tools/build_android.sh status
  ./tools/build_android.sh clean

Umgebungsvariablen:
  KOMOREBI_TEST_APK=debug   Test/Install nutzt die Debug-APK statt Release
  GAMEPLAY_ARGS="--hits 4" wird an tools/gameplay_test.py durchgereicht
USAGE
        exit 2
        ;;
esac
