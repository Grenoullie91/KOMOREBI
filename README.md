# KOMOREBI

> *Zerstöre die Schatten, bevor das Licht erlischt.*

Ein kleines, schnelles Arcade-Spiel für Android: **Tap-Tap-Kill** in einer
Dämmerungs-Waldlichtung. Schatten treiben aus der Dunkelheit ins Bild, man
tippt sie weg, hält die Kombo am Laufen und sammelt Gaben ein, bevor die Zeit
abläuft.

Gebaut mit **Godot 4.7** (GLES 3, `gl_compatibility`), Hochformat, ohne
Werbung, ohne Login, ohne Server, ohne In-App-Käufe, ohne Internet.

| | |
|---|---|
| Engine | Godot 4.7.2 |
| Application ID | `de.komorebi.game` |
| Version | 1.0.0 (Version Code 1) |
| min / target SDK | 24 / 36 |
| Permissions | keine |
| Store | Google Play, Play-Console-Upload erfolgt separat |

---

## Spielprinzip

| | |
|---|---|
| **Kern** | Schatten antippen, bevor die Zeit abläuft |
| **Ziel** | Soll-Zahl an Schatten pro Kapitel erreichen |
| **Risiko** | Fehlgriffe brechen die Kombo, Zeit läuft ab |
| **Belohnung** | Punkte, Kombo-Multiplikator, Sterne, freigeschaltete Kapitel |

### Gegner

| Typ | Verhalten | Punkte | Besonderheit |
|---|---|---|---|
| **Schatten** | treibt langsam | 10 | Ein Tipp, und er zerfällt |
| **Funkenleiter** | zickt, stößt in kurzen Schüben | 16 | muss abgewartet werden |
| **Splitter** | treibt langsam | 20 | zerfällt beim Tod in drei Scherben (je 6) |
| **Panzerschatten** | sehr langsam | 30 | drei Treffer; beim Tod Sprengladung, die alle Nachbarn mitnimmt |
| **Großer Schatten** | pendelt zur Mitte | 150 | Kapitel-Boss, 6–8 erlöschende Kerzen |

### Mechanik

- **Kombo** — jeder Treffer ohne Fehlgriff erhöht die Kombo (Fenster 2,6 s).
  Ab vier Treffern steigt der Multiplikator Schritt für Schritt bis **×9**.
- **Kritisch** — mit wachsender Kombo werden Treffer häufiger kritisch:
  doppelte Punkte, weißer Blitz, Goldring, kurze Zeitlupe.
- **Mehrfach** — mehrere Schatten binnen 0,3 s: Bonus und ein sichtbares
  Zeichen („MEHRFACH x3“).
- **Gaben** — fallen gelegentlich und müssen angetippt werden, bevor sie verblassen:
  - **Sonnenstich** (bernstein) — 5 s doppelte Punkte
  - **Reif** (cyan) — alle Gegner fliegen deutlich langsamer
  - **Kette** (mint) — die nächsten 6 Töte zünden durch und reißen Nachbarn mit

### Kapitel

Acht Kapitel mit steigendem Druck, danach ein Endlos-Modus (60 Sekunden).

| # | Name | Soll | Zeit | Neu |
|---|---|---|---|---|
| 1 | Erster Schein | 14 | 45 s | Schatten |
| 2 | Glutflug | 20 | 45 s | Funkenleiter |
| 3 | Splitternebel | 22 | 45 s | Splitter |
| 4 | Panzerlicht | 24 | 45 s | Panzerschatten |
| 5 | Dämmerung | 28 | 48 s | alles, dichter |
| 6 | Kagura | 18 + Boss | 55 s | Großer Schatten (6 Kerzen) |
| 7 | Nebelsturm | 32 | 48 s | härteste Mischung |
| 8 | Großer Schatten | 22 + Boss | 60 s | Endgegner (8 Kerzen) |

Jedes Kapitel vergibt bis zu **drei Sterne** über Score-Schwellen. Ein Stern ist
das sichere Abschaffen, drei Sterne verlangen eine gehaltene Kombo.

---

## Aufbau des Projekts

```
scenes/main.tscn            Wurzel der Anwendung (nur ein Control mit Skript)
scripts/
  main.gd                   Seitenwechsel, Persistenz, Audio, Eingabe
  core/
    palette.gd              Farben, Radien, Typo
    fonts.gd                Schriften (Inter, SIL OFL)
    ui.gd                   Theme, Stylebox-Fabrik, Widget-Bausteine
    log.gd                  Logcat-Schnittstelle inkl. Viewport→Pixel
    save_data.gd            Fortschritt, Sterne, Bestwerte (ConfigFile)
    sfx.gd                  prozeduraler Sound (in AudioStreamWAV gerendert)
    backdrop.gd             animierter Dämmerungs-Hintergrund
    autoplay.gd             Entwicklungshilfe: spielt headless durch
  ui/
    app_screen.gd           Basis aller Seiten
    overlay.gd              Basis aller Karten (Pause, Intro, Ergebnis)
    title_text.gd           Display-Schrift mit Laufweite, Verlauf, Glow
    stars_row.gd            Sterne als Bewertung
    title_screen.gd         Titelbildschirm
    level_select_screen.gd  Kapitelauswahl
    howto_screen.gd         Kurzanleitung
    title_showcase.gd       drifting Schatten auf dem Titelbildschirm
  game/
    levels.gd               Leveltabelle und Endlos-Kurve
    game_screen.gd          Spielbildschirm: Regeln, Punkte, Levelabschluss
    arena.gd                Spielfeld, Gegner, Gaben, Trefferauflösung
    enemy.gd                Gegnertypen (Verhalten + prozedurale Zeichnung)
    powerup.gd              Gaben
    fx.gd                   Partikel, Ringe, Blitze (ein Pool)
    hud.gd                  Kopfzeile, Balken, Kombo-Anzeige, Gaben-Chips
    stat_bar.gd             Statusleiste
    level_intro_sheet.gd    Kapitel-Intro
    pause_sheet.gd          Pause
    result_sheet.gd         Ergebnis (Sieg/Niederlage, Sterne, Kennzahlen)
tools/
  build_android.sh           Build / Install / Start / Test auf dem Emulator
  gameplay_test.py           automatisiertes End-to-End-Gameplay
  make_icons.gd              erzeugt Launcher-Icon und Boot-Splash aus den SVGs
  make_release_keystore.sh   erzeugt den projektspezifischen Release-Key
  release_keystore.py        trägt das Passwort temporär ins Export-Preset ein
  bundletool.sh              Klasspfad für bundletool (AAB-Prüfung)
  icons/                     SVG-Quellen für Icon und Splash
assets/icons/                erzeugte PNGs (Launcher, Adaptive Icon, Splash)
signing/                     Release-Key und Passwort (nicht versioniert)
store/icon-512.png           512er Icon für den Play-Store-Eintrag
```

Nicht im Repository, sondern lokal erzeugt:

```
.godot/                      Godot-Importcache
artifacts/                   Screenshots und Logcat aus den Testläufen
build/android/               Release-APK und Release-AAB
android/                     Android-Buildvorlage (siehe unten)
```

Die Buildvorlage entpackt Godot aus den Export-Templates. Sie enthält
fertige Bibliotheken von über 100 MB und bleibt deshalb außen vor. Der
AAB-Build holt sie sich selbst:

```bash
flatpak run org.godotengine.Godot --headless --path . \
    --install-android-build-template
```

### Bewusste Entscheidungen

- **Oberfläche im Code.** Farben, Radien, Abstände und Schriftgrößen liegen an
  genau einer Stelle (`core/palette.gd`, `core/ui.gd`). Jede Seite wird aus
  denselben Bausteinen zusammengesetzt — das hält das Bild konsistent und
  macht Umbauten sicher.
- **Keine Fremd-Assets.** Alle Grafiken (Gegner, Partikel, Hintergrund, Sterne,
  Logo) sind prozedural gezeichnet. Der einzige Fremd-Bestandteil ist die
  Schrift **Inter** (SIL OFL 1.1, siehe `assets/fonts/README.md`).
- **Prozeduraler Sound.** Alle 15 Effekte werden beim Start aus reinen
  Funktionen in `AudioStreamWAV`-Puffer gerendert — kein Audio-Asset,
  keine Abhängigkeit, konsistent auf jedem Gerät.
- **Regeln und Darstellung getrennt.** `arena.gd` weiß nichts über Punkte oder
  Level, `game_screen.gd` weiß nichts über Treffer-Geometrie. Beide kommunizieren
  über Signale.
- **Testbarkeit als Feature.** Das Spiel schreibt Knopf- und Gegnerpositionen
  inklusive Skalierung nach Logcat. Der Test liest diese Werte, statt
  Farb-Heuristiken zu raten — und prüft Screenshots als zweite, unabhängige
  Quelle. `ENEMY_POS` meldet viermal pro Sekunde ein vollständiges Bild aller
  lebenden Figuren; Spawn-Zeilen allein sind zu alt, weil die Gegner driften.
- **Hintergrund als Textur, nicht als Geometrie.** Der Dämmerungsgrund wird mit
  30 Hz neu gezeichnet, die Lichtschäfte als ein einziges texturiertes Trapez
  statt als 48 gefüllte Streifen. Auf dem Emulator kostete der alte Aufbau
  rund zwei Drittel der Bildzeit (20 statt 60 Bilder pro Sekunde), optisch ist
  er identisch.

---

## Release-Identität

| | |
|---|---|
| Anzeigename | KOMOREBI |
| Application ID | `de.komorebi.game` |
| Version Name / Code | 1.0.0 / 1 |
| min / target SDK | 24 / 36 (Android 7.0 / Android 16) |
| Bildformat | Hochformat, Portrait-only |
| ABIs (AAB) | `arm64-v8a`, `armeabi-v7a` |
| ABIs (Release-APK) | zusätzlich `x86_64` für Emulator und x86-Geräte |
| Permissions | **keine** |
| Internet | nicht erforderlich, App ist vollständig offline |
| Konten / Werbung / Tracking | keines |

`store/icon-512.png` ist das Icon für den Play-Store-Eintrag.

**Im Repository liegen keine Geheimnisse.** Weder der Signing-Key noch das
Passwort noch Play-Credentials sind eingecheckt — `signing/` steht vollständig
in der `.gitignore`. Der Release-Key wird lokal erwartet und ist nicht Teil
der Versionsverwaltung. `./tools/build_android.sh release` bricht deshalb ab,
solange `signing/komorebi-upload.jks` fehlt; es wird kein Debug-Key als
Release ausgegeben.

## Bauen und testen

```bash
./tools/build_android.sh emulator   # AVD starten (Host-GPU, headless)
./tools/build_android.sh debug      # Debug-APK (schnelle Schleife)
./tools/build_android.sh build      # Release-APK -> build/android/komorebi-release.apk
./tools/build_android.sh aab        # App Bundle -> build/android/komorebi-release.aab
./tools/build_android.sh release    # APK + AAB bauen und technisch prüfen
./tools/build_android.sh install    # Release-APK auf emulator-5554 installieren
./tools/build_android.sh run        # starten, Screenshot + Logcat
./tools/build_android.sh test       # vollständiger Gameplay-Test
./tools/build_android.sh analyze    # Artefakte mit apkanalyzer/bundletool prüfen
./tools/build_android.sh full       # Release-APK bauen + Emulator-Test
```

`install`, `run` und `test` verwenden standardmäßig die **Release**-APK, weil
nur sie dem Play-Artefakt entspricht. Mit `KOMOREBI_TEST_APK=debug` läuft die
schnellere Debug-Schleife.

### Release-Key

Der Release-Key ist **lokal**, nicht Teil des Repositorys. Wer hier einen
Release bauen will, legt ihn zuerst an:

```bash
./tools/make_release_keystore.sh    # erzeugt signing/komorebi-upload.jks
```

Ablage (beides von `.gitignore` ausgenommen):

| Datei | Inhalt |
|---|---|
| `signing/komorebi-upload.jks` | der Release-Key |
| `signing/.pass` | das Passwort, eine Zeile |

Wer einen vorhandenen Key verwenden möchte, legt Datei und Passwort unter
dieselben Namen ab — das Skript wird dann nicht gebraucht. Es überschreibt
niemals einen vorhandenen Key.

Das Passwort wird ausschließlich für die Dauer des Exports in
`export_presets.cfg` eingetragen und danach wieder entfernt
(`tools/release_keystore.py`). **Kein Secret-Wert gehört in eine versionierte
Datei, ins README oder in dieses Repository.**

Ohne den Key bricht `./tools/build_android.sh release` ab — es wird niemals
ein Debug-Key als Release ausgegeben.

**Vor dem echten Upload:** Key und Passwort getrennt und sicher sichern. Ohne
beide ist die App später nicht mehr signierbar, sofern Play App Signing den
App-Key nicht selbst verwaltet.

Der Upload zu Google Play erfolgt separat und ist nicht Teil dieses
Repositorys.

### AAB-Voraussetzungen

Der AAB-Export braucht die Android-Buildvorlage im Projekt. Sie wird einmalig
von Godot erzeugt:

```bash
flatpak run org.godotengine.Godot --headless --path . \
    --install-android-build-template
```

`tools/bundletool.sh` baut die Klasspfad-Kette für `bundletool`, das weder im
Android-SDK noch als Flatpak-Binary vorliegt, sondern als Gradle-Artefakt im
lokalen Cache.

Headless ohne Emulator (Logik, Persistenz, Levelwechsel):

```bash
flatpak run org.godotengine.Godot --headless --path . -- --autoplay=6
#                    --autoplay=1        Kapitel 1
#                    --autoplay=endless   Endlos-Modus
#                    --notap              nichts antippen (Game-Over-Pfad)
#                    --maxsec=45          Zeitlimit
```

### Automatisierter Test

Der Test prüft in rund 40 Prüfschritten:

1. App-Start und Titelbildschirm (inkl. Bildhelligkeit und Knopffläche)
2. Hauptmenue: Kampagne, Endlos, Anleitung
3. Levelauswahl und Kapitel-Intro
4. Rundenstart, Spielfeldvermessung, HUD
5. Pause und Fortsetzen
6. Mehrere Treffer mit Bildbeleg („war am Tipp-Punkt wirklich etwas zu sehen?“)
7. Kombo-Aufbau
8. Fehlgriff verändert den Score nicht
9. Gabe einsammeln und Aktivierung prüfen
10. Kapitelabschluss, Sterne, Fortschritt
11. Levelwechsel ins nächste Kapitel
12. Game Over durch Zeitablauf
13. Persistenz nach App-Neustart
14. Endlos-Modus inklusive Pause
15. Logcat auf echte Fehler, Exceptions und Script-Fehler

Screenshots und Logcat-Auszüge landen in `artifacts/`.

### Bekannte, harmlose Logcat-Meldungen

| Meldung | Warum harmlos |
|---|---|
| `WARNING: Failed to load cached shader, recompiling.` | `gl_compatibility` überschreibt den Shader-Cache im ersten Frame |
| `WARNING: 2D MSAA is not yet supported for GLES3.` | 2D-MSAA ist unter GLES3 nicht verfügbar |

Beide werden vom Test erkannt und ausgefiltert (inklusive Stack-Trace).

---

## Persistenz

`user://komorebi.cfg` — Bestwert und Sterne je Kapitel, freigeschaltetes
Kapitel, Endlos-Bestwert, Klang-Einstellung, gelesene Kurzanleitung.
Keine Cloud, keine Konten, keine externen Dienste.

## Bekannte Schwächen

- Der Emulator auf diesem Host beendet sich unter Last gelegentlich selbst
  (GL-Kontext). Der Test erkennt das als Umgebungsproblem und bricht sauber ab.
- Ein echter Play-Upload ist nicht erfolgt. Vor dem Hochladen muss die App in
  der Play Console angelegt und — falls gewünscht — ein eigener App-Key
  hinterlegt werden; siehe oben „Release-Key“.
- Godot erzeugt aus jedem Touch zusätzlich ein emuliertes Mausereignis. Eine
  kurze Eingabesperre direkt nach Rundenende fängt das ab; auf echten Geräten
  ist das Fenster deutlich kleiner als die Latenz zwischen den Ereignissen.
- Der Titelbildschirm zeigt eine kuratierte Vorschau der Gegnerformen, aber
  keine echte Spielschleife.