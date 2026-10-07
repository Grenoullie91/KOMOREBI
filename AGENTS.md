# AGENTS.md — Arbeitsregeln für dieses Projekt

## Mission

Dieses Verzeichnis enthält **KOMOREBI**, ein kleines Android-Arcade-Spiel
(Tap-Tap-Kill) in Godot 4.7. Der Agent arbeitet autonom und bringt Änderungen
bis zu einem lauffähigen, getesteten Release-Build (APK und AAB) auf dem
Emulator.

Typische Arbeitsweise:

1. Projekt prüfen
2. Kleinste sinnvolle Änderung planen
3. Dateien anpassen
4. Headless prüfen (`godot --check-only`, `--autoplay`)
5. Release-APK exportieren (`build_android.sh build`)
6. Emulator starten bzw. wiederverwenden
7. APK installieren, App starten
8. Gameplay automatisiert testen, Screenshots ansehen, Logcat auswerten
9. Bei Problemen eigenständig diagnostizieren und beheben
10. Wiederholen, bis ein stabiler Release-Kandidat steht

Nicht bei jedem einzelnen technischen Schritt anhalten. Normale, umkehrbare
Entwicklungsarbeit in diesem Verzeichnis braucht keine Rückfrage.

## Vollständige Beschreibung

Spielidee, Feature-Übersicht, Projektstruktur und Testumfang stehen in
[`README.md`](README.md). Dort auch die Liste bekannter, harmloser
Logcat-Meldungen.

## Projektumfang

Nur `~/android-agent-test` steht unter Kontrolle des Agenten.

### Niemals ändern

- `~/mini-mysteries`
- `~/projects/PocketPals`
- `~/projects/StarSprinkler`
- `~/projects/PocketInventors`
- `~/streambridge/android`

Keine Dateien aus diesen Projekten kopieren. Keine Produktions-Signing-Keys,
keine Play-Console-Zugänge, keine Service-Accounts, kein Upload, keine
Veröffentlichung. Keine externen Dienste, keine Zahlungsabwicklung.

## Umgebung

- Android SDK: `$HOME/Android/Sdk`
- JDK: `$HOME/tools/jdk21`
- Godot: `flatpak run org.godotengine.Godot` (4.7.2)
- Emulator: AVD `starq`, GPU `host`, headless (`-no-window`)
- Paketname: `de.komorebi.game`
- Release-APK: `build/android/komorebi-release.apk`
- Release-AAB: `build/android/komorebi-release.aab`

SwiftShader ist auf diesem Host unbrauchbar (Vulkan-Present und GLES3-Uniform-
Limits). Bei Grafikproblemen darf der Agent Renderer und GPU-Modus ändern, so
fern nur dieses Projekt betroffen ist, und die Änderung im Abschlussbericht
nennen.

Der Emulator beendet sich unter Last gelegentlich von selbst (GL-Kontext).
Das ist ein Umgebungs-, kein Spielproblem: Emulator neu starten und den Test
wiederholen. Der Test erkennt ein fehlendes Gerät und meldet es als Hinweis.

## Befehle

```bash
./tools/build_android.sh emulator   # AVD starten und auf Boot warten
./tools/build_android.sh debug      # Debug-APK bauen (schnelle Schleife)
./tools/build_android.sh build      # Release-APK bauen
./tools/build_android.sh aab        # Android App Bundle bauen
./tools/build_android.sh release    # APK + AAB bauen und analysieren
./tools/build_android.sh install    # Release-APK installieren
./tools/build_android.sh run        # starten + Screenshot + Logcat
./tools/build_android.sh test       # vollständiger Gameplay-Test
./tools/build_android.sh analyze    # Artefakte technisch prüfen
./tools/build_android.sh full       # Release-APK + Emulator-Test
./tools/build_android.sh logcat     # rohes Logcat
./tools/build_android.sh clean      # erzeugte Artefakte entfernen
```

Der AAB-Export braucht die Android-Buildvorlage im Projekt. Sie wird einmalig
erzeugt mit:

```bash
flatpak run org.godotengine.Godot --headless --path . \
    --install-android-build-template
```

`android/` steht in der `.gitignore` (Bibliotheken über 100 MB) und wird nach
einem frischen Clone vor dem AAB-Build erzeugt.

Schnelle Logikprüfung ohne Emulator:

```bash
flatpak run org.godotengine.Godot --headless --path . --check-only --script res://scripts/main.gd
flatpak run org.godotengine.Godot --headless --path . -- --autoplay=6
```

Der Test ist die Verifikationsbasis. Ein Build gilt erst als fertig, wenn
`tools/gameplay_test.py` ohne Fehler durchläuft **und** die Screenshots in
`artifacts/` geprüft wurden.

## Repository

- Remote: `https://github.com/Grenoullie91/KOMOREBI.git`, Branch `main`.
- Commit-Zustand: `android-agent-test` ist die Quelle; was dort liegt und nicht
  von `.gitignore` ausgenommen wird, gehört ins Repository.
- Ausgeschlossen bleiben: `signing/`, `android/`, `build/`, `artifacts/`,
  `.godot/`.
- **Vor jedem Commit** prüfen, dass kein Key, kein Passwort und keine
  Play-Credentials im Index liegen. `git diff --cached` ist der Maßstab,
  nicht die `.gitignore`.

## Signing

- Der Release-Key liegt in `signing/komorebi-upload.jks`, das Passwort in
  `signing/.pass`. Beides ist von `.gitignore` ausgenommen und **darf nie
  committet werden**.
- `./tools/make_release_keystore.sh` erzeugt einen neuen Key, überschreibt aber
  nie einen vorhandenen.
- Das Passwort wird nur während des Exports in `export_presets.cfg`
  eingetragen und danach wieder entfernt (`tools/release_keystore.py`). Nach
  jedem Export prüfen, dass keine `keystore/release_password`-Zeile in der
  Datei steht.
- **Kein Debug-Key als Release ausliefern.** Das Release-Artefakt muss mit dem
  projektspezifischen Key signiert sein.

## Konventionen im Code

- Ein `class_name` pro Datei, Dateiname = Klassenname.
- Kommentare erklären **warum**, nicht was. Auf Deutsch, mit Umlauten.
- Farben, Radien und Schriftgrößen kommen aus `core/palette.gd`,
  Widget-Bausteine aus `core/ui.gd`. Keine Literale im UI-Code.
- Spielregeln gehören in `game/game_screen.gd`, Geometrie und Darstellung in
  `game/arena.gd`, `game/enemy.gd`, `game/fx.gd`.
- Jede neue Verknüpfung mit dem Test bekommt eine Logcat-Zeile mit
  `[Game]`-Präfix, inklusive Pixelposition, sobald der Test sie antippen soll.
- Keine externen Abhängigkeiten, keine Fremd-Assets ohne Lizenz-Hinweis.

## Bekannte Fallen in dieser Umgebung

- `adb logcat d` hängt sich auf — immer `adb logcat -d`.
- Ein Logcat-Dump ohne `-s godot:V` ist auf diesem Emulator zu langsam; die
  Systemzeilen verdrängen die `[Game]`-Meldungen aus dem Ringpuffer.
- Aggressives Pollen (Logcat alle 0,25 s) lastet den Emulator so stark, dass
  die App Eingaben erst sekundenlang später verarbeitet. Der Test pollt
  bewusst langsam und wartet pro Tipp auf dessen Reaktion.
- Nach dem Export `SCRIPT ERROR` suchen, nicht nur nach `ERROR` — ein
  Parse-Fehler im GDScript fällt beim Export sonst nicht auf.

## Release-Kandidat

Am Ende stehen ein sauberes Release-APK unter
`build/android/komorebi-release.apk` und ein Release-AAB unter
`build/android/komorebi-release.aab`, beide mit dem projektspezifischen Key
signiert. Kein Play-Console-Upload, keine Veröffentlichung.