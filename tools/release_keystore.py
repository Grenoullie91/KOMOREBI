#!/usr/bin/env python3
"""Release-Keystore in `export_presets.cfg` einhängen und wieder entfernen.

Godot liest Keystore-Pfad, Alias und Passwort aus dem Export-Preset. Damit
das Passwort nicht dauerhaft in einer versionierten Datei steht, wird es nur
für die Dauer des Exports eingetragen und danach wieder entfernt. Die Quelle
der Wahrheit ist `signing/.pass` (nicht versioniert).

    python3 tools/release_keystore.py apply     # vor dem Export
    python3 tools/release_keystore.py clear     # nach dem Export
    python3 tools/release_keystore.py status    # nur prüfen
"""

from __future__ import annotations

import sys
from pathlib import Path

PROJECT_DIR = Path(__file__).resolve().parent.parent
PRESETS = PROJECT_DIR / "export_presets.cfg"
KEYSTORE = PROJECT_DIR / "signing" / "komorebi-upload.jks"
PASSWORD_FILE = PROJECT_DIR / "signing" / ".pass"
ALIAS = "komorebi"

MARKER_START = "; --- release-keystore (temporaer, von tools/release_keystore.py) ---"
MARKER_END = "; --- ende release-keystore ---"

ABSENT = (
    "Keystore fehlt: %s\n"
    "Projektspezifischen Release-Key anlegen mit:\n"
    "  ./tools/make_release_keystore.sh" % KEYSTORE
)
NO_PASSWORD = (
    "Kein Passwort hinterlegt: %s fehlt.\n"
    "Siehe README, Abschnitt 'Signing'." % PASSWORD_FILE
)


def _read_password() -> str:
    if not KEYSTORE.exists():
        sys.exit(ABSENT)
    if not PASSWORD_FILE.exists():
        sys.exit(NO_PASSWORD)
    return PASSWORD_FILE.read_text(encoding="utf-8").strip()


def _strip(lines: list[str]) -> list[str]:
    out: list[str] = []
    inside = False
    for line in lines:
        if line.startswith(MARKER_START):
            inside = True
            continue
        if line.startswith(MARKER_END):
            inside = False
            continue
        if inside:
            continue
        out.append(line)
    return out


def _write(lines: list[str]) -> None:
    # Der Zeilenabschluss am Dateiende bleibt, wie er war - sonst erzeugt jedes
    # apply/clear-Paar ein Diff, das die Bereinigung unnoetig macht.
    text = "\n".join(lines)
    if text and not text.endswith("\n"):
        text += "\n"
    PRESETS.write_text(text, encoding="utf-8")


def apply() -> int:
    password = _read_password()
    lines = _strip(PRESETS.read_text(encoding="utf-8").splitlines())
    block = (
        f"{MARKER_START}\n"
        f'keystore/release="{KEYSTORE}"\n'
        f'keystore/release_user="{ALIAS}"\n'
        f'keystore/release_password="{password}"\n'
        f"{MARKER_END}\n"
    )
    # Die Zugaben müssen in jedem [preset.N.options]-Block stehen, sonst
    # greift der Export nur für einen Teil der Presets. Direkt hinter der
    # Abschnittsmarke einfügen - dann bleibt der Rest der Datei byteweise
    # unverändert und `clear` stellt exakt den Ausgangszustand wieder her.
    result: list[str] = []
    blocks = 0
    for line in lines:
        result.append(line)
        if line.startswith("[preset.") and line.endswith(".options]"):
            result.extend(block.rstrip("\n").splitlines())
            blocks += 1
    _write(result)
    print(f"[keystore] eingetragen: {KEYSTORE.name} (Alias {ALIAS}) in {blocks} Preset(s)")
    return 0


def clear() -> int:
    _write(_strip(PRESETS.read_text(encoding="utf-8").splitlines()))
    print("[keystore] aus export_presets.cfg entfernt")
    return 0


def status() -> int:
    text = PRESETS.read_text(encoding="utf-8")
    print(f"Keystore-Datei:   {'vorhanden' if KEYSTORE.exists() else 'FEHLT'} ({KEYSTORE})")
    print(f"Passwortdatei:    {'vorhanden' if PASSWORD_FILE.exists() else 'FEHLT'}")
    print(f"In Preset aktiv:  {'ja' if MARKER_START in text else 'nein'}")
    return 0


def main(argv: list[str]) -> int:
    command = argv[1] if len(argv) > 1 else "status"
    if command == "apply":
        return apply()
    if command == "clear":
        return clear()
    if command == "status":
        return status()
    sys.exit(__doc__ or "")


if __name__ == "__main__":
    sys.exit(main(sys.argv))