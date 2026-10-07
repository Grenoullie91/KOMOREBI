#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

# Erzeugt den projektspezifischen Release-Upload-Key.
#
# Bewusst kein Key aus einem anderen Projekt und keine Play-Credentials: der
# Key wird hier einmalig neu erzeugt. Passwort und Keystore liegen unter
# signing/ und sind von .gitignore ausgenommen. Wer einen bestehenden Key
# verwenden will, legt ihn einfach unter signing/komorebi-upload.jks ab und
# schreibt das Passwort nach signing/.pass - dieses Skript ist dann unnötig.

SIGNING_DIR="$PROJECT_DIR/signing"
KEYSTORE="$SIGNING_DIR/komorebi-upload.jks"
PASSWORD_FILE="$SIGNING_DIR/.pass"
KEYTOOL="${KEYTOOL:-$HOME/tools/jdk21/bin/keytool}"
ALIAS="komorebi"
DAYS=10950   # 30 Jahre - Play-Console-Keys sind praktisch dauerhaft

if [[ ! -x "$KEYTOOL" ]]; then
    KEYTOOL="$(command -v keytool || true)"
fi
[[ -n "$KEYTOOL" ]] || { echo "[ERROR] keytool nicht gefunden (JDK)" >&2; exit 1; }

if [[ -f "$KEYSTORE" ]]; then
    echo "[ERROR] Keystore existiert bereits: $KEYSTORE" >&2
    echo "        Vorhandene Keys werden nie überschrieben." >&2
    exit 1
fi

mkdir -p "$SIGNING_DIR"
chmod 700 "$SIGNING_DIR"

password="$(python3 -c 'import secrets; print(secrets.token_urlsafe(32))')"

echo "==> Erzeuge Release-Upload-Key (Alias '$ALIAS', $DAYS Tage)"
"$KEYTOOL" -genkeypair -v \
    -keystore "$KEYSTORE" \
    -alias "$ALIAS" \
    -keyalg RSA -keysize 4096 -validity "$DAYS" \
    -storetype PKCS12 \
    -storepass "$password" -keypass "$password" \
    -dname "CN=KOMOREBI, OU=Games, O=KOMOREBI, C=DE"

printf '%s\n' "$password" > "$PASSWORD_FILE"
chmod 600 "$KEYSTORE" "$PASSWORD_FILE"

echo
echo "==> Zertifikat"
"$KEYTOOL" -list -v -keystore "$KEYSTORE" -storepass "$password" -alias "$ALIAS" \
    | grep -E "Alias|Eintrag|Owner|Inhaber|Gültigkeit|Valid|Signature algorithm|Signatur" || true

echo
echo "Fertig: $KEYSTORE"
echo "Passwort: $PASSWORD_FILE (nicht versioniert)"
echo
echo "WICHTIG: Key und Passwort getrennt sichern. Ohne sie sind spätere"
echo "Updates der App nicht mehr signierbar, solange Play App Signing den"
echo "App-Key nicht selbst verwaltet."