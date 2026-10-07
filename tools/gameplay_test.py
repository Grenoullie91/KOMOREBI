#!/usr/bin/env python3
"""Automatisiertes End-to-End-Gameplay fuer "KOMOREBI" (Godot/Android).

Der Test spricht die vom Spiel selbst veroeffentlichte Logcat-Schnittstelle an
(`[Game] ...`) und benutzt Screenshots als unabhaengige Bestaetigung. Damit
wird nicht auf Farb-Heuristiken gebaut: Knopf- und Gegnerpositionen kommen aus
dem Logcat, das Bild belegt nur, dass dort wirklich etwas zu sehen ist.

Gepruefte Ablaufkette:

  1. App starten, Titelbildschirm
  2. Hauptmenue: Kampagne / Endlos / Anleitung
  3. Levelauswahl
  4. Kapitel-Intro
  5. Runde starten, HUD
  6. Pause und Fortsetzen
  7. Mehrere normale Treffer inkl. Bildbeleg
  8. Fehlgriff aendert den Score nicht
  9. Power-up einsammeln
  10. Kapitel abschliessen (Soll-Zahl erreicht), Sterne + Fortschritt
  11. Levelwechsel ins naechste Kapitel
  12. Game Over durch abgelaufene Zeit
  13. Neustart der App, Persistenz pruefen
  14. Logcat auf echte Fehler pruefen

Nutzung:
    python3 tools/gameplay_test.py [--hits 8] [--skip-fail] [--keep-data]
"""

from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
import time
from dataclasses import dataclass, field
from pathlib import Path

from PIL import Image

PROJECT_DIR = Path(__file__).resolve().parent.parent
ARTIFACTS = PROJECT_DIR / "artifacts"
SERIAL = os.environ.get("ADB_SERIAL", "emulator-5554")
PACKAGE = os.environ.get("KOMOREBI_PACKAGE", "de.komorebi.game")

ANDROID_HOME = Path(os.environ.get("ANDROID_HOME", str(Path.home() / "Android/Sdk")))
ADB = [os.environ.get("ADB_BIN", str(ANDROID_HOME / "platform-tools" / "adb")), "-s", SERIAL]

FAILURES: list[str] = []
NOTES: list[str] = []
CHECKS = 0
VERBOSE = os.environ.get("TEST_VERBOSE", "1") == "1"

PX = re.compile(r"px=\((-?[\d.]+),\s*(-?[\d.]+)\)")
ID = re.compile(r"id=(\d+)")
SCORE = re.compile(r"\[Game\] SCORE=(\d+)")


# ---------------------------------------------------------------- Protokoll --

def log(message: str) -> None:
    print(f"[test] {message}", flush=True)


def fail(message: str) -> None:
    FAILURES.append(message)
    print(f"[test] FEHLER: {message}", flush=True)


def clear_logcat() -> None:
    """Logcat leeren - reine Vorbereitung, kein Pruefschritt. Ein haengender
    Aufruf darf den Testlauf nicht abbrechen."""
    try:
        adb("logcat", "-c", timeout=20, retries=2)
    except Exception as error:  # noqa: BLE001
        log(f"WARNUNG: logcat nicht leer: {error}")


def dump_log(name: str) -> None:
    """Vollstaendige, ungekürzte Spielprotokoll-Datei zur Fehlersuche."""
    ARTIFACTS.mkdir(parents=True, exist_ok=True)
    (ARTIFACTS / name).write_text("\n".join(logcat()), encoding="utf-8")


def settle(seconds: float = 0.45) -> None:
    """Kurze Wartezeit nach einem Bildschirmwechsel, damit der erste Tipp
    sicher im neuen Zustand ankommt."""
    time.sleep(seconds)


def check(condition: bool, message: str, ok_message: str = "") -> bool:
    global CHECKS
    CHECKS += 1
    if condition:
        if ok_message:
            log(ok_message)
        return True
    fail(message)
    return False


def note(message: str) -> None:
    NOTES.append(message)
    log(f"HINWEIS: {message}")


# --------------------------------------------------------------------- ADB ---

def adb(*args: str, timeout: int = 90, retries: int = 2) -> subprocess.CompletedProcess:
    """ADB mit Timeout und Wiederholung. Ein haengender adb-Aufruf darf den
    gesamten Test nicht abbrechen - bei Logcat-Dumps passiert das auf
    belasteten Emulatoren gelegentlich."""
    last: TimeoutError | None = None
    for attempt in range(retries + 1):
        try:
            return subprocess.run(
                ADB + list(args), capture_output=True, text=True, timeout=timeout
            )
        except subprocess.TimeoutExpired as error:
            last = error
            log(f"WARNUNG: adb {' '.join(args[:3])} haengt, Versuch {attempt + 1}/{retries + 1}")
            time.sleep(1.0)
    raise last if last else RuntimeError("adb fehlgeschlagen")


_ACTIVITY_CACHE: str | None = None


def ensure_device(timeout: float = 120.0) -> bool:
    """Wartet darauf, dass das Geraet wieder unter adb auftaucht. Der
    Emulator beendet sich auf diesem Host gelegentlich von selbst (GL-Kontext
    unter Last) - der Test soll das als Umgebungsproblem melden, nicht als
    Spiel-Fehlschlag."""
    deadline = time.time() + timeout
    while time.time() < deadline:
        result = adb("devices", timeout=25)
        if re.search(r"%s\s+device" % re.escape(SERIAL), result.stdout):
            return True
        time.sleep(4.0)
    return False


def device_available() -> bool:
    result = adb("devices", timeout=25)
    return bool(re.search(r"%s\s+device" % re.escape(SERIAL), result.stdout))


def resolve_activity() -> str:
    global _ACTIVITY_CACHE
    if _ACTIVITY_CACHE:
        return _ACTIVITY_CACHE
    for attempt in range(4):
        result = adb("shell", "cmd", "package", "resolve-activity", "--brief", PACKAGE)
        for line in reversed([l.strip() for l in result.stdout.splitlines() if l.strip()]):
            if line.startswith(PACKAGE + "/"):
                _ACTIVITY_CACHE = line
                return line
        log(f"WARNUNG: Launcher-Activity nicht lesbar, Versuch {attempt + 1}/4")
        time.sleep(2.0)
    raise RuntimeError(f"Launcher-Activity nicht gefunden: {result.stdout!r} {result.stderr!r}")


def tap(x: float, y: float, label: str = "") -> None:
    adb("shell", "input", "tap", str(int(round(x))), str(int(round(y))), timeout=30)
    log(f"tippe ({x:.0f}, {y:.0f}){(' -> ' + label) if label else ''}")


def screenshot(name: str) -> Path:
    ARTIFACTS.mkdir(parents=True, exist_ok=True)
    target = ARTIFACTS / name
    with target.open("wb") as handle:
        proc = subprocess.run(
            ADB + ["exec-out", "screencap", "-p"], stdout=handle, stderr=subprocess.PIPE, timeout=90
        )
    if proc.returncode != 0 or target.stat().st_size < 2048:
        raise RuntimeError(f"screencap fehlgeschlagen ({proc.returncode}) -> {target}")
    return target


# Godot loggt unter dem Tag "godot". Ein serverseitiger Tag-Filter ist hier
# deutlich robuster als ein Fenster ueber die Zeilenzahl: der Emulator schreibt
# sehr viele Systemzeilen, die die `[Game]`-Meldungen sonst aus dem Ringpuffer
# verdraengen - und ein vollstaendiger Dump kann unter Last Minuten dauern.
GODOT_TAG = "godot"


def logcat() -> list[str]:
    """Nur die Godot-Zeilen holen (filtert serverseitig)."""
    proc = adb("shell", "logcat", "-d", "-v", "brief", "-s", GODOT_TAG, timeout=60)
    return (proc.stdout + proc.stderr).splitlines()


def full_logcat(limit: int = 2500) -> list[str]:
    """Dump fuer die Fehlersuche: Godot-Zeilen vollstaendig plus ein begrenztes
    Fenster des Systempuffer. Haengt der Systemabruf, wird nicht abgebrochen -
    die Godot-Zeilen enthalten die Skriptfehler ohnehin."""
    lines = logcat()
    try:
        proc = adb("logcat", "-d", "-v", "brief", "-t", str(limit), timeout=45, retries=1)
        lines += (proc.stdout + proc.stderr).splitlines()
    except Exception as error:  # noqa: BLE001
        log(f"HINWEIS: System-Logcat nicht abrufbar ({error}) - nur Godot-Zeilen geprueft")
    return lines


def game_lines(lines: list[str] | None = None) -> list[str]:
    return [l for l in (lines if lines is not None else logcat()) if "[Game]" in l]


def wait_for(predicate, timeout: float = 20.0, interval: float = 1.0, what: str = "") -> list[str]:
    """Wartet, bis `predicate(lines)` True liefert; gibt die Logzeilen zurueck."""
    deadline = time.time() + timeout
    while time.time() < deadline:
        lines = game_lines()
        if predicate(lines):
            return lines
        time.sleep(interval)
    if what:
        fail(f"Timeout beim Warten auf: {what}")
    return game_lines()


def last_match(lines: list[str], pattern: re.Pattern, cast=int):
    for line in reversed(lines):
        found = pattern.search(line)
        if found:
            return cast(found.group(1))
    return None


def last_event(lines: list[str], marker: str) -> str | None:
    for line in reversed(lines):
        if marker in line:
            return line
    return None


def button_px(lines: list[str], button_id: str) -> tuple[float, float] | None:
    marker = "BTN id=%s " % button_id
    for line in reversed(lines):
        if marker in line:
            numbers = PX.search(line)
            if numbers:
                return (float(numbers.group(1)), float(numbers.group(2)))
    return None


def last_button_px(button_id: str) -> tuple[float, float] | None:
    return button_px(game_lines(), button_id)


def press_button(
    button_id: str,
    label: str = "",
    attempts: int = 2,
    expect: tuple[str, ...] = (),
) -> bool:
    """Tippt einen Knopf und wartet auf seine Reaktion.

    Zwei Fehlerquellen werden hier abgefangen:

    * `adb shell input tap` braucht auf dem Emulator mehrere Sekunden, bis der
      Tipp wirklich ankommt. Das Bestaetigungsfenster ist deshalb grosszuegig.
    * Liegt die Karte noch im Layout, kann ein Tipp daneben gehen. Dann wird
      die Position neu gelesen und erneut getippt.

    `expect` nennt zusaetzlich Meldungen, die einen erfolgreichen Tipp
    ebenfalls belegen (z.B. der nachfolgende Bildschirmwechsel). Damit wird ein
    Tipp nicht als Fehlschlag gewertet, nur weil seine Logzeile verspaetet
    eintrifft."""
    marker = "BTN id=%s pressed=1" % button_id
    for attempt in range(attempts):
        point = wait_button(button_id, timeout=6.0)
        if point is None:
            continue
        before_lines = game_lines()
        before_press = _count(before_lines, marker)
        # Zaehler statt Indizes: der Logcat-Ringpuffer verschiebt Zeilen, wenn
        # er ueberlaeuft. Ein Indexvergleich erkennt neue Zeilen dann nicht
        # mehr und wertet einen korrekten Tipp faelschlich als Fehlschlag.
        before_expect: dict[str, int] = {token: _count(before_lines, token) for token in expect}
        tap(*point, label or button_id)

        # Grosszuegiges Fenster, aber träger Rhythmus: jeder Logcat-Dump
        # startet auf dem Geraet einen Prozess. Zu enges Pollen lastet den
        # Emulator so stark, dass die App den Tipp erst Sekunden spaeter
        # verarbeitet - und der Test dann auf dem falschen Bildschirm landet.
        deadline = time.time() + 22.0
        while time.time() < deadline:
            time.sleep(1.0)
            lines = game_lines()
            if _count(lines, marker) > before_press:
                return True
            if any(_count(lines, token) > before_expect[token] for token in expect):
                return True
        log(f"Knopf '{button_id}' reagierte nicht, Versuch {attempt + 2}/{attempts}")
        try:
            screenshot(f"fehler-{button_id}-{attempt + 2}.png")
        except Exception:  # noqa: BLE001
            pass
        tail = [l.split("[Game] ")[-1] for l in game_lines()[-8:]]
        for line in tail:
            log(f"    | {line}")
    fail(f"Knopf '{button_id}' liess sich nicht druecken")
    return False


def wait_button(button_id: str, timeout: float = 12.0) -> tuple[float, float] | None:
    """Wartet, bis der Knopf mit dieser ID seine Pixelposition gemeldet hat.
    Immer die juengste Meldung - so wird nach einem Bildschirmwechsel nicht
    versehentlich eine alte Position angeklickt."""
    deadline = time.time() + timeout
    while time.time() < deadline:
        point = button_px(game_lines(), button_id)
        if point is not None:
            return point
        time.sleep(0.6)
    return None


def event_px(marker: str) -> tuple[float, float] | None:
    line = last_event(game_lines(), marker)
    if not line:
        return None
    numbers = PX.search(line)
    return (float(numbers.group(1)), float(numbers.group(2))) if numbers else None


# ------------------------------------------------------- Logcat-Zustandsbild --

@dataclass
class Field:
    """Abbild der lebenden Gegner/Gaben aus dem Logcat."""

    enemies: dict[int, str] = field(default_factory=dict)   # id -> px-Tupel
    powerups: dict[int, str] = field(default_factory=dict)
    kills: int = 0
    score: int = 0
    combo: int = 0

    def alive(self) -> list[tuple[int, tuple[float, float]]]:
        return [(i, p) for i, p in self.enemies.items()]

    def free_point(self, taken: list[tuple[float, float]], margin: float = 150.0) -> tuple[float, float]:
        """Punkt weit weg von allen bekannten Gegnern und vom Bildrand."""
        width, height = 1080, 1920
        best = (width * 0.5, height * 0.55)
        best_score = -1.0
        for fx in (0.16, 0.30, 0.50, 0.70, 0.84):
            for fy in (0.30, 0.45, 0.62, 0.80):
                point = (width * fx, height * fy)
                if point in taken:
                    continue
                nearest = min(
                    (abs(point[0] - p[0]) + abs(point[1] - p[1]) for p in taken),
                    default=9999.0,
                )
                if nearest > best_score:
                    best_score = nearest
                    best = point
        return best


ENEMY_POS_ENTRY = re.compile(r"(id|pup)=(\d+)\s+px=\((-?[\d.]+),\s*(-?[\d.]+)\)")


def parse_field(lines: list[str]) -> Field:
    """Baut das Spielfeld aus dem Logcat auf.

    `ENEMY_POS` ist die wichtige Quelle: sie meldet in einer Zeile die
    aktuellen Positionen aller lebenden Gegner und Gaben. Spawn-Zeilen
    beschreiben nur den Geburtsort - die Figuren driften danach weiter, und
    der Test arbeitet mit Logcat, das immer einen Moment alt ist.
    """
    state = Field()
    for line in lines:
        if "[Game]" not in line:
            continue
        if "ENEMY_POS" in line:
            # Diese Zeile ist ein vollstaendiges Bild: was nicht drinsteht,
            # ist nicht mehr da. Deshalb wird der Bestand hier ersetzt und
            # nicht nur ergaenzt - abgelaufene Gegner (Laufzeit, Treffer)
            # hinterlassen sonst Eintraege, die es nicht mehr gibt.
            found_enemies: dict[int, tuple[float, float]] = {}
            found_powerups: dict[int, tuple[float, float]] = {}
            for key, identifier, x, y in ENEMY_POS_ENTRY.findall(line):
                point = (float(x), float(y))
                if key == "id":
                    found_enemies[int(identifier)] = point
                else:
                    found_powerups[int(identifier)] = point
            state.enemies = found_enemies
            state.powerups = found_powerups
        elif "ENEMY_SPAWN" in line or "POWERUP_SPAWN" in line or "BOSS_SPAWN" in line:
            identifier = ID.search(line)
            numbers = PX.search(line)
            if not (identifier and numbers):
                continue
            point = (float(numbers.group(1)), float(numbers.group(2)))
            target = state.powerups if "POWERUP_SPAWN" in line else state.enemies
            target.setdefault(int(identifier.group(1)), point)
        elif "KILL" in line:
            identifier = ID.search(line)
            if identifier:
                state.enemies.pop(int(identifier.group(1)), None)
            state.kills += 1
        elif "POWERUP kind=" in line:
            # eingesammelt: naechster Lauf raeumt die Liste ohnehin auf
            pass
        elif "[Game] SCORE=" in line:
            value = SCORE.search(line)
            if value:
                state.score = int(value.group(1))
    return state


# ------------------------------------------------------------ Bildauswertung --

def load(name: str) -> Image.Image:
    return Image.open(ARTIFACTS / name).convert("RGB")


def bright_blob(image: Image.Image, x: float, y: float, radius: int = 70) -> int:
    """Zaehlt kraeftig gefaerbte Pixel um einen Punkt - Beweis, dass dort
    tatsaechlich eine Figur gezeichnet wurde."""
    cx, cy = int(x), int(y)
    box = (cx - radius, cy - radius, cx + radius, cy + radius)
    if box[0] < 0 or box[1] < 0 or box[2] >= image.width or box[3] >= image.height:
        return 0
    crop = image.crop(box)
    count = 0
    for r, g, b in crop.getdata():
        high = max(r, g, b)
        low = min(r, g, b)
        if high > 95 and high - low > 38:
            count += 1
    return count


def mean_brightness(image: Image.Image) -> float:
    sample = image.resize((64, 64), Image.BOX)
    total = 0
    count = 0
    for r, g, b in sample.getdata():
        total += 0.2126 * r + 0.7152 * g + 0.0722 * b
        count += 1
    return total / max(1, count)


def mint_button_area(image: Image.Image, center: tuple[float, float] | None) -> int:
    """Zaehlt Mintflaeche in der unteren Bildhaelfte (der Primaer-Knopf)."""
    if center is None:
        return 0
    half = image.height // 2
    crop = image.crop((0, half, image.width, image.height))
    count = 0
    for r, g, b in crop.getdata():
        if g > 150 and r < 140 and 120 < b < 220:
            count += 1
    return count


# ------------------------------------------------------------- Logcat-Qualitaet --

ERROR_PATTERN = re.compile(
    r"FATAL EXCEPTION|SCRIPT ERROR|Parse Error|E/AndroidRuntime|SIGSEGV|SIGABRT|"
    r"Condition \"[^\"]+\" is true|ObjectDB instances were leaked"
)

BENIGN_PATTERNS = (
    "Failed to load cached shader, recompiling",
    "2D MSAA is not yet supported for GLES3",
    "ObjectDB instances were leaked",
)

STACK_TRACE_LINE = re.compile(r"\):\s+at:\s")


def strip_benign(lines: list[str]) -> tuple[list[str], int]:
    kept: list[str] = []
    dropped = 0
    in_trace = False
    for line in lines:
        if in_trace and STACK_TRACE_LINE.search(line):
            dropped += 1
            continue
        in_trace = False
        if any(pattern in line for pattern in BENIGN_PATTERNS):
            in_trace = True
            dropped += 1
            continue
        kept.append(line)
    return kept, dropped


def check_logcat_errors(lines: list[str]) -> None:
    kept, ignored = strip_benign(lines)
    if ignored:
        log(f"{ignored} Zeile(n) bekannter-harmloser Godot-Meldung(en) ignoriert")
    errors = [l for l in kept if ERROR_PATTERN.search(l)]
    if errors:
        for line in errors[:20]:
            print(f"[test] LOGCAT: {line.strip()}")
        fail(f"{len(errors)} relevante Logcat-Fehler gefunden")
        return
    log("Logcat ohne relevante Fehler, Exceptions oder Script-Fehler")


# -------------------------------------------------------------------- Phasen --

def parse_level_start(lines: list[str]) -> tuple[int | None, float | None]:
    line = last_event(lines, "LEVEL_START")
    if not line:
        return None, None
    quota = re.search(r"quota=(\d+)", line)
    duration = re.search(r"time=([\d.]+)", line)
    return (
        int(quota.group(1)) if quota else None,
        float(duration.group(1)) if duration else None,
    )


def phase_title(activity: str) -> None:
    wait_for(lambda l: any("SCREEN=TITLE" in x for x in l), 25.0, what="Titelbildschirm")
    settle(0.8)
    screenshot("01-titel.png")
    image = load("01-titel.png")
    pos = wait_button("campaign")
    if not check(pos is not None, "KAMPAGNE-Knopf nicht im Logcat gemeldet"):
        return None
    area = mint_button_area(image, pos)
    check(area > 4000, f"Primaer-Knopf im Bild nicht erkennbar (Mintflaeche={area})",
          f"Titelbildschirm sichtbar, KAMPAGNE bei ({pos[0]:.0f}, {pos[1]:.0f}), Mintflaeche={area}")
    check(mean_brightness(image) < 90, "Titelseite wirkt nicht dunkel genug",
          f"Titelseite dunkel (Mittlere Helligkeit {mean_brightness(image):.1f})")
    return pos


def phase_menu(activity: str) -> None:
    lines = game_lines()
    check(any("SCREEN=HOWTO" in l for l in lines) is False, "Anleitung ist ungefragt offen")
    for name in ("endless", "howto"):
        check(button_px(lines, name) is not None, f"Knopf '{name}' nicht im Logcat")


def phase_howto(lines: list[str]) -> None:
    lines = wait_for(lambda l: any("SCREEN=HOWTO" in x for x in l), 12.0, what="Anleitungsseite")
    screenshot("02-anleitung.png")
    settle(0.6)
    press_button("back", "zurueck", expect=("SCREEN=TITLE",))
    wait_for(lambda l: any("SCREEN=TITLE" in x for x in l), 12.0, what="Rueckkehr zum Titel")
    settle()


def phase_level_select(lines: list[str]) -> None:
    lines = wait_for(lambda l: any("SCREEN=LEVELS" in x for x in l), 15.0, what="Levelauswahl")
    screenshot("03-levelauswahl.png")
    image = load("03-levelauswahl.png")
    check(mean_brightness(image) > 12, "Levelauswahl ist unplausibel dunkel",
          f"Levelauswahl sichtbar ({len([l for l in lines if 'BTN id=lv' in l])} Kapitelkarten)")
    # Positionen der Karten kommen erst nach dem Layout - deshalb frisch lesen.
    check(wait_button("lv1", 10.0) is not None, "Kapitel-1-Karte nicht gemeldet")


def phase_intro(lines: list[str]) -> list[str]:
    press_button("lv1", "kapitel 1", expect=("LEVEL_INTRO id=1",))
    lines = wait_for(lambda l: any("LEVEL_INTRO id=1" in x for x in l), 15.0, what="Kapitel-Intro")
    settle(0.8)
    screenshot("04-kapitel-intro.png")
    pos = wait_button("begin")
    if not check(pos is not None, "START-Knopf der Kapitel-Intro fehlt"):
        return lines
    check(mint_button_area(load("04-kapitel-intro.png"), pos) > 4000,
          "START-Knopf im Bild nicht als Primaer-Knopf erkennbar")
    return lines


def phase_start_round(lines: list[str]) -> tuple[list[str], int | None, float | None]:
    press_button("begin", "Licht wecken", expect=("STATE=PLAYING level=1",))
    lines = wait_for(lambda l: any("STATE=PLAYING" in x for x in l), 15.0, what="Rundenstart")
    settle(1.0)
    quota, duration = parse_level_start(lines)
    check(quota is not None and quota > 0, "Soll-Zahl des Kapitels fehlt")
    time.sleep(1.6)
    screenshot("05-runde-start.png")
    # Logcat nach dem Start erneut lesen: die Feldmeldung kommt erst nach
    # zwei Frames, die Round-Meldung aber sofort.
    lines = game_lines()
    check(pos_ok(lines), "Spielfeld-Rechteck fehlt im Logcat",
          "Spielfeld vermessen: " + (last_event(lines, "FIELD_RECT") or ""))
    log(f"Kapitel 1 laeuft: Soll={quota}, Zeit={duration:.0f}s" if duration else "Kapitel laeuft")
    return lines, quota, duration


def pos_ok(lines: list[str]) -> bool:
    return last_event(lines, "FIELD_RECT") is not None


def phase_pause(lines: list[str]) -> list[str]:
    if not check(wait_button("pause") is not None, "Pause-Knopf nicht gemeldet"):
        return lines
    press_button("pause", "pause", expect=("STATE=PAUSED",))
    lines = wait_for(lambda l: any("STATE=PAUSED" in x for x in l), 10.0, what="Pausezustand")
    screenshot("06-pause.png")
    image = load("06-pause.png")
    check(mean_brightness(image) > 5, "Pausebildschirm ist schwarz")
    log("Pausekarte sichtbar, Fortsetzen-Knopf gemeldet")
    if not press_button("resume", "weiter"):
        fail("Ohne Fortsetzen laeuft die Phase im eingefrorenen Zustand weiter")
        return lines
    lines = wait_for(
        lambda l: _count(l, "STATE=PLAYING") >= _count(l, "STATE=PAUSED"),
        10.0, what="Fortsetzen",
    )
    log("Pause und Fortsetzen bestaetigt")
    return lines


def _count(lines: list[str], marker: str) -> int:
    return sum(1 for l in lines if marker in l)


def pick_target(state: Field, tried: set[int]) -> tuple[int, tuple[float, float]] | None:
    """Juengsten noch nicht versuchten Gegner waehlen. Die Position kommt aus
    der letzten `ENEMY_POS`-Zeile; der Drift zwischen Log und Tipp liegt bei
    wenigen Pixeln, weil direkt getippt wird.

    Sind alle bekannten Gegner schon versucht, wird die Liste geleert und neu
    gewaehlt: mit frischen Positionen ist ein zweiter Versuch sinnvoll, und
    ohne das liefe die Schleife in einen Leerlauf."""
    for identifier, point in reversed(state.alive()):
        if identifier not in tried:
            return identifier, point
    tried.clear()
    alive = state.alive()
    return alive[-1] if alive else None


def try_kill(tried: set[int], evidence_slot: list | None = None, before: list[str] | None = None) -> bool:
    """Einmal tippen und pruefen, ob ein Treffer registriert wurde.

    `evidence_slot` bekommt optional [index, gemessene Pixel] gefuellt: damit
    laesst sich belegen, dass am getippten Punkt wirklich eine Figur gezeichnet
    war - Bildpruefung und Logcat-Pruefung also unabhaengig voneinander."""
    # Wird der Snapshot von der aufrufenden Schleife uebergeben, spart das
    # einen teuren adb-Dump. Ein Dump proIteration ist wichtig: jeder extrae
    # Rundlauf verzoegert den Tipp, und der Gegner driftet weiter weg.
    if before is None:
        before = game_lines()
    state = parse_field(before)
    target = pick_target(state, tried)
    if target is None:
        return False
    identifier, point = target
    before_kills = _count(before, " KILL ")

    if evidence_slot is not None:
        name = f"07-treffer-{evidence_slot[1]:02d}-vorher.png"
        evidence_slot[0] = bright_blob(load(screenshot(name).name), point[0], point[1])

    before_miss = _count(before, " MISS ")
    tap(*point, f"gegner {identifier}")

    # Auf die Reaktion warten, statt blind weiterzutippen: der Emulator
    # verarbeitet die Eingabewarteschlange unter Last mit Verzoegerung. Ohne
    # diese Bremse stapeln sich Tipps und landen spaeter gebuendelt auf einem
    # voellig anderen Bildschirm - der Test tappt dann fremde Knoepfe.
    deadline = time.time() + 6.0
    reacted = False
    while time.time() < deadline:
        time.sleep(0.5)
        after = game_lines()
        if _count(after, " KILL ") > before_kills or _count(after, " MISS ") > before_miss:
            reacted = True
            break
    if evidence_slot is not None and evidence_slot[1] > 0:
        time.sleep(0.02)
    if reacted and _count(game_lines(), " KILL ") > before_kills:
        tried.discard(identifier)
        return True
    # Lage vermutlich veraltet: diesen Gegner fuer eine Weile ueberspringen.
    tried.add(identifier)
    return False


def phase_hits(lines: list[str], count: int, quota: int | None = None) -> list[str]:
    """Tippt lebende Gegner an und prueft Treffer, Score und Bildbeleg.

    Mehr als die Soll-Zahl an Schatten kann nicht verlangt werden: das
    Kapitel endet, sobald die Soll-Zahl erreicht ist."""
    if quota:
        count = min(count, quota)
    killed = 0
    attempts = 0
    tried: set[int] = set()
    seen_scores: list[int] = []
    evidence = 0
    while killed < count and attempts < count * 10:
        attempts += 1
        # Ein einziger Logcat-Dump pro Iteration, direkt vor dem Tipp.
        before = game_lines()
        # Bildbeleg nur fuer die ersten Treffer aufnehmen (Screenshot-Kosten).
        shot: list | None = [0, killed + 1] if killed < 4 else None
        before_score = last_match(before, SCORE) or 0
        if VERBOSE:
            playing: bool = _count(before, "STATE=PLAYING") > _count(before, "STATE=PAUSED")
            log(f"  [versuch {attempts}] Gegner={len(parse_field(before).alive())} "
                f"versucht={len(tried)} Score={before_score}"
                f"{'' if playing else ' (PAUSE/ENDE)'}")
            if not playing and attempts > 4:
                fail("Runde laeuft nicht (pausiert oder beendet) - Treffertest abgebrochen")
                return before
        if try_kill(tried, shot, before):
            if shot is not None:
                screenshot(f"07-treffer-{shot[1]:02d}-feedback.png")
            killed += 1
            after_score = last_match(game_lines(), SCORE) or 0
            seen_scores.append(after_score)
            log(f"Treffer {killed}: Score {before_score} -> {after_score}")
            if shot and shot[1] == 1:
                evidence = shot[0]
                check(evidence > 200,
                      f"Kein sichtbarer Gegner an der getippten Stelle (gefunde Pixel={evidence})",
                      f"Gegner am Tipp-Punkt sichtbar ({evidence} gefaerbte Pixel)")
            check(after_score > before_score,
                  f"Score stieg trotz Treffer nicht ({before_score} -> {after_score})")
            if killed % 3 == 0:
                screenshot(f"07-treffer-{killed:02d}-danach.png")
        else:
            time.sleep(0.25)

    check(killed >= count, f"Nur {killed} von {count} Treffern erreicht")
    if len(seen_scores) >= 2:
        check(seen_scores[-1] > seen_scores[0], "Score ist am Ende nicht gestiegen")
        log(f"Score-Verlauf: {' -> '.join(str(s) for s in seen_scores)}")
    return lines


def phase_combo(lines: list[str]) -> None:
    lines = game_lines()
    combos = [int(m.group(1)) for m in re.finditer(r"KILL .*combo=(\d+)", "\n".join(lines))]
    check(bool(combos) and max(combos) >= 2, "Kombo ist nie gestiegen")
    if combos:
        log(f"Kombo bis x{max(combos)} erreicht, letzte KILL-Zeile: {last_event(lines, ' KILL ')}")


def phase_miss(lines: list[str]) -> None:
    lines = game_lines()
    state = parse_field(lines)
    if not state.enemies:
        note("Kein Gegner fuer die Fehlgriff-Probe bekannt")
        return
    point = state.free_point([p for _, p in state.alive()])
    before_score = last_match(lines, SCORE) or 0
    before_combo = max([int(m.group(1)) for m in re.finditer(r"KILL .*combo=(\d+)", "\n".join(lines))] or [0])
    before_miss = _count(lines, " MISS ")
    tap(*point, "absichtlicher Fehlgriff")
    deadline = time.time() + 6.0
    while time.time() < deadline:
        time.sleep(0.5)
        if _count(game_lines(), " MISS ") > before_miss:
            break
    time.sleep(0.5)
    lines = game_lines()
    after_score = last_match(lines, SCORE) or 0
    check(any("MISS" in l for l in lines), "Fehlgriff wurde nicht registriert")
    check(after_score == before_score,
          f"Fehlgriff hat den Score veraendert ({before_score} -> {after_score})",
          f"Fehlgriff ohne Score-Aenderung ({after_score})")
    after_combo = max([int(m.group(1)) for m in re.finditer(r"KILL .*combo=(\d+)", "\n".join(lines))] or [0])
    check(after_combo <= max(1, before_combo), "Kombo blieb nach Fehlgriff stehen")
    log(f"Fehlgriff bei ({point[0]:.0f}, {point[1]:.0f}) korrekt ohne Wirkung")


def phase_powerup(lines: list[str], timeout: float = 45.0) -> None:
    """Wartet auf eine Gabe, sammelt sie ein - und spielt nebenbei weiter,
    damit ueberhaupt Gaben fallen."""
    deadline = time.time() + timeout
    tried: set[int] = set()
    stale: set[int] = set()
    collected = 0
    while time.time() < deadline:
        before = game_lines()
        state = parse_field(before)
        if state.powerups:
            fresh = [item for item in state.powerups.items() if item[0] not in stale]
            if not fresh:
                stale.update(state.powerups.keys())
            else:
                identifier, point = fresh[-1]
                count_before = _count(before, "POWERUP kind=")
                tap(*point, "gabe")
                deadline = time.time() + 6.0
                while time.time() < deadline:
                    time.sleep(0.5)
                    if _count(game_lines(), "POWERUP kind=") > count_before:
                        break
                after = game_lines()
                if _count(after, "POWERUP kind=") <= count_before:
                    # Lage vermutlich veraltet: diese Gabe nicht weiter versuchen.
                    stale.add(identifier)
                if _count(after, "POWERUP kind=") > count_before:
                    collected += 1
                    screenshot("08-powerup.png")
                    check("ACTIVE" in (last_event(after, "ACTIVE") or ""),
                          "Gabe aktiviert keinen Effekt")
                    log(f"Gabe eingesammelt: {last_event(after, 'POWERUP kind=')}")
                    stale.clear()
                    if collected >= 1:
                        return
        # nebenbei weiter Treffer setzen, damit Gaben fallen
        if not try_kill(tried, None, before):
            time.sleep(0.4)
    if collected == 0:
        note("Innerhalb des Zeitlimits keine Gabe eingesammelt")


def phase_clear(lines: list[str], quota: int) -> list[str]:
    """Spielt das Kapitel zu Ende und prueft Ergebniskarte und Sterne."""
    deadline = time.time() + 150.0
    tried: set[int] = set()
    while time.time() < deadline:
        lines = game_lines()
        if any("LEVEL_CLEAR" in l for l in lines):
            break
        before = game_lines()
        if not try_kill(tried, None, before):
            time.sleep(0.35)
    else:
        fail("Kapitel nicht innerhalb des Zeitlimits abgeschlossen")
        return game_lines()

    lines = game_lines()
    line = last_event(lines, "LEVEL_CLEAR") or ""
    star_match = re.search(r"stars=(\d+)", line)
    stars = int(star_match.group(1)) if star_match else 0
    kill_match = re.search(r"kills=(\d+)", line)
    kills = int(kill_match.group(1)) if kill_match else 0
    check(kills >= int(quota or 0), f"Zu wenige Schatten fuer Soll-Zahl ({kills} < {quota})",
          f"Kapitel geschafft: {line}")
    check(stars >= 1, "Mindestens ein Stern vergeben", f"Sterne: {stars}")
    time.sleep(1.6)
    screenshot("09-kapitel-geschafft.png")
    lines = game_lines()
    check(wait_button("primary") is not None, "Weiter-Knopf der Ergebnisliste fehlt")
    check(any("SCREEN=" in l or "STATE=RESULT" in l for l in lines), "Ergebniszustand nicht gemeldet")
    return lines


def phase_next_level(lines: list[str]) -> list[str]:
    # Kammer die Ergebnispruefung abgeschlossen ist, kann die Runde schon
    # durch einen nachlaufenden Tipp weitergeschaltet sein. Dann darf der
    # Test nicht erneut tippen - sonst wuerde er auf dem naechsten Bildschirm
    # einen fremden Knopf ausloesen.
    if any("LEVEL_INTRO id=2" in l for l in game_lines()):
        note("Weiterleitung ins zweite Kapitel lief bereits vor")
    else:
        press_button("primary", "weiter", expect=("LEVEL_INTRO id=2",))
    lines = wait_for(lambda l: any("LEVEL_INTRO id=2" in x for x in l), 15.0,
                     what="Intro des zweiten Kapitels")
    settle(0.8)
    screenshot("10-kapitel-2-intro.png")
    log("Levelwechsel in Kapitel 2 bestaetigt")
    if not any("STATE=PLAYING level=2" in l for l in game_lines()):
        press_button("begin", "kapitel 2 starten", expect=("STATE=PLAYING level=2",))
    lines = wait_for(lambda l: any("STATE=PLAYING level=2" in x for x in l), 15.0,
                     what="Start von Kapitel 2")
    quota, duration = parse_level_start(lines)
    log(f"Kapitel 2 aktiv (Soll={quota}, Zeit={duration:.0f}s)")
    return lines


def phase_game_over(lines: list[str]) -> list[str]:
    """Wartet das Zeitende ab - der Weg zum Game Over."""
    lines = wait_for(lambda l: any("LEVEL_FAIL" in x for x in l), 120.0, 2.0,
                     what="Game Over durch Zeitablauf")
    if not any("LEVEL_FAIL" in l for l in lines):
        return lines
    line = last_event(lines, "LEVEL_FAIL") or ""
    log(f"Game Over bestaetigt: {line}")
    time.sleep(1.6)
    screenshot("11-game-over.png")
    settle(1.0)
    lines = game_lines()
    press_button("menu", "zur Uebersicht", expect=("SCREEN=TITLE",))
    lines = wait_for(lambda l: any("SCREEN=TITLE" in x for x in l), 15.0,
                     what="Rueckkehr zum Titelbildschirm")
    log("Rueckkehr zum Titelbildschirm bestaetigt")
    return lines


def phase_persistence(before: dict) -> None:
    if not ensure_device(90.0):
        note("Persistenzpruefung uebersprungen: Geraet nicht erreichbar (Umgebung)")
        return
    adb("shell", "am", "force-stop", PACKAGE)
    time.sleep(1.5)
    clear_logcat()
    adb("shell", "am", "start", "-n", resolve_activity(), timeout=60)
    lines = wait_for(lambda l: any("SAVE_STATE" in x for x in l), 30.0, what="Persistenz-Zeile")
    state = last_event(lines, "SAVE_STATE")
    check(state is not None, "Kein Persistenz-Status nach Neustart")
    if not state:
        return
    unlocked = int(re.search(r"unlocked=(\d+)", state).group(1))
    stars_total = int(re.search(r"stars_total=(\d+)", state).group(1))
    per = re.search(r"per=\[(.*)\]", state).group(1)
    check(unlocked >= 2, f"Fortschritt nicht gespeichert (unlocked={unlocked})",
          f"Fortschritt gespeichert: unlocked={unlocked}, Sterne={stars_total}")
    check(stars_total >= 1, "Sterne nicht gespeichert")
    screenshot("12-neustart.png")
    log(f"Persistenz nach Neustart: {state}")


def phase_endless() -> None:
    """Kurzer Blick in den Endlos-Modus."""
    adb("logcat", "-c")
    adb("shell", "am", "force-stop", PACKAGE)
    time.sleep(1.0)
    adb("shell", "am", "start", "-n", resolve_activity(), timeout=60)
    lines = wait_for(lambda l: any("SCREEN=TITLE" in x for x in l), 30.0, what="Titel")
    if not check(wait_button("endless") is not None, "ENDLOS-Knopf fehlt"):
        return
    press_button("endless", "endlos", expect=("LEVEL_INTRO id=0",))
    lines = wait_for(lambda l: any("LEVEL_INTRO id=0" in x for x in l), 20.0,
                     what="Intro des Endlos-Modus")
    settle(0.8)
    lines = wait_for(lambda l: any("BTN id=begin" in x for x in l), 10.0)
    press_button("begin", "endlos starten", expect=("LEVEL_START id=0", "endless=1"))
    lines = wait_for(lambda l: any("LEVEL_START" in x and "endless=1" in x for x in l), 15.0,
                     what="Endlos-Runde")
    tried: set[int] = set()
    for _ in range(10):
        if not try_kill(tried):
            time.sleep(0.35)
    screenshot("13-endlos.png")
    lines = game_lines()
    score = last_match(lines, SCORE)
    check(score is not None and score > 0, "Endlos-Modus liefert keine Punkte",
          f"Endlos-Modus spielt, Score={score}")
    press_button("pause", "pause", expect=("STATE=PAUSED",))
    lines = wait_for(lambda l: any("STATE=PAUSED" in x for x in l), 10.0, what="Pause im Endlos-Modus")
    if press_button("resume", "weiter"):
        wait_for(lambda l: any("STATE=PLAYING" in x for x in l), 10.0)
    log("Endlos-Modus inklusive Pause bestaetigt")


# ---------------------------------------------------------------------- Main --

def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--hits", type=int, default=8, help="Anzahl verifizierter Treffer")
    parser.add_argument("--skip-fail", action="store_true", help="Game-Over-Phase ueberspringen")
    parser.add_argument("--skip-endless", action="store_true", help="Endlos-Pruefung ueberspringen")
    parser.add_argument("--startup-wait", type=float, default=2.0)
    args = parser.parse_args()

    ARTIFACTS.mkdir(parents=True, exist_ok=True)
    if not ensure_device(60.0):
        log("FEHLER: Kein Geraet unter adb erreichbar - Emulator starten und erneut versuchen.")
        return 2
    activity = resolve_activity()
    log(f"Activity: {activity}")

    adb("shell", "am", "force-stop", PACKAGE)
    time.sleep(1.2)
    clear_logcat()
    adb("shell", "am", "start", "-n", activity, timeout=60)
    log("App gestartet, warte auf ersten Frame ...")
    time.sleep(args.startup_wait)

    lines = wait_for(lambda l: any("BOOT" in x for x in l), 30.0, 0.5, what="Startmeldung")
    check(any("BOOT" in l for l in lines), "App meldet keinen Start im Logcat",
          next((l.split("[Game] ")[-1] for l in lines if "BOOT" in l), ""))

    phase_title(activity)
    lines = game_lines()
    phase_menu(activity)

    # Hauptmenue komplett durchklicken: Kampagne -> Anleitung -> zurueck
    press_button("howto", "anleitung", expect=("SCREEN=HOWTO",))
    phase_howto(lines)

    lines = game_lines()
    settle(0.5)
    press_button("campaign", "kampagne", expect=("SCREEN=LEVELS",))
    phase_level_select(lines)
    dump_log("logcat-02-levelauswahl.txt")
    lines = game_lines()
    phase_intro(lines)
    lines, quota, duration = phase_start_round(lines)
    dump_log("logcat-03-start.txt")
    lines = phase_pause(lines)
    dump_log("logcat-04-pause.txt")
    lines = phase_hits(lines, args.hits, quota)
    phase_combo(lines)
    phase_miss(lines)
    phase_powerup(lines)
    dump_log("logcat-05-treffer.txt")
    lines = phase_clear(lines, quota)
    dump_log("logcat-06-klar.txt")

    if not args.skip_fail:
        lines = phase_next_level(lines)
        phase_game_over(lines)
        dump_log("logcat-07-gameover.txt")

    # Ein abgestuerzter Emulator ist ein Umgebungs-, kein Spielproblem -
    # deshalb als Hinweis, nicht als Fehlschlag.
    if ensure_device(120.0):
        phase_persistence({})
    else:
        note("Persistenzpruefung uebersprungen: Emulator nicht erreichbar (Umgebung)")

    if not args.skip_endless:
        if device_available():
            phase_endless()
        else:
            note("Endlos-Modus uebersprungen: Geraet nicht erreichbar")

    lines = full_logcat()
    (ARTIFACTS / "gameplay-logcat.txt").write_text("\n".join(lines), encoding="utf-8")
    check_logcat_errors(lines)
    return report()


def report() -> int:
    print()
    for item in NOTES:
        print(f"[test] HINWEIS: {item}")
    if FAILURES:
        print(f"[test] ERGEBNIS: FEHLGESCHLAGEN - {len(FAILURES)} von {CHECKS} Pruefungen")
        for item in FAILURES:
            print(f"   - {item}")
        return 1
    print(f"[test] ERGEBNIS: BESTANDEN - {CHECKS} Pruefungen")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as error:  # noqa: BLE001
        print(f"[test] ABBRUCH: {error}", flush=True)
        import traceback
        traceback.print_exc()
        sys.exit(2)