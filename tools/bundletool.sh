#!/usr/bin/env bash
# Legt eine lauffaehige bundletool-Klasspfad-Umgebung fuer dieses Projekt an.
#
# bundletool liegt nicht im Android-SDK, sondern als Gradle-Artefakt im
# lokalen Cache. Ohne die transitive Klasspfad-Kette startet das Tool nicht.
# Diese Datei sammelt sie einmalig - aufgerufen von tools/build_android.sh.
set -Eeuo pipefail

BUNDLETOOL_VERSION="${BUNDLETOOL_VERSION:-1.17.1}"
GRADLE_CACHE="${GRADLE_CACHE:-$HOME/.gradle/caches/modules-2/files-2.1}"

jar_of() {
    # Neueste passende Version eines Artefakts nehmen.
    find "$GRADLE_CACHE/$1" -name "$2" -type f 2>/dev/null | sort -V | tail -n 1
}

bundletool_jar="$(jar_of com.android.tools.build/bundletool "bundletool-$BUNDLETOOL_VERSION.jar")"
if [[ -z "$bundletool_jar" ]]; then
    echo "[ERROR] bundletool $BUNDLETOOL_VERSION nicht im Gradle-Cache gefunden." >&2
    echo "        Vorhandene Versionen:" >&2
    find "$GRADLE_CACHE/com.android.tools.build/bundletool" -name "*.jar" 2>/dev/null | sed 's#.*/##' >&2
    exit 1
fi

# bundletool braucht zwingend Guava, Protobuf und Annotations; der Cache
# liefert sie als transitive Abhaengigkeiten des Gradle-Builds mit.
classpath="$bundletool_jar"
for group in com.google.guava com.google.protobuf com.google.code.gson \
            com.google.errorprone com.google.j2objc org.ow2.asm \
            com.android.tools com.android.tools.build org.jetbrains.annotations; do
    while read -r jar; do
        [[ -n "$jar" ]] && classpath="$classpath:$jar"
    done < <(find "$GRADLE_CACHE/$group" -name "*.jar" -type f 2>/dev/null | sort -V)
done

printf '%s' "$classpath"