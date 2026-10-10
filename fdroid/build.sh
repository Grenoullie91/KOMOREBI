#!/usr/bin/env bash
#
# F-Droid build script for KOMOREBI.
#
# Called from fdroiddata metadata as:
#
#   build:
#     - ./fdroid/build.sh $$Godot$$ $$NDK$$ $$SDK$$
#
# F-Droid expands $$Godot$$ / $$NDK$$ / $$SDK$$ in the command line only -
# they are string substitutions, not environment variables - so the paths
# arrive as positional arguments.
#
# Why the engine is compiled instead of used from the system:
# the F-Droid build server is a throwaway VM built by makebuildserver from a
# Debian base. It ships androguard, apksigner, default-jdk-headless,
# default-jre-headless, curl, dexdump, git-svn, gnupg, patch, python3-magic,
# python3-packaging, rsync, sdkmanager, sudo, unzip plus the Android SDK/NDK
# and gradlew-fdroid. There is no flatpak, no Godot, and wget is deliberately
# purged, so the editor cannot be installed at build time either. The only
# reproducible option is to build it from the Godot srclib.
#
# This is the same recipe nodomain.playmaker and
# org99managers.futsal_edition use for Godot 4 games.

set -euo pipefail

GODOT_SRC="${1:?usage: build.sh <godot-srclib-dir> <ndk-dir> <sdk-dir>}"
NDK_DIR="${2:?usage: build.sh <godot-srclib-dir> <ndk-dir> <sdk-dir>}"
SDK_DIR="${3:?usage: build.sh <godot-srclib-dir> <ndk-dir> <sdk-dir>}"

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

PRESET="Android F-Droid"
OUTPUT="build/android/komorebi-fdroid.apk"

export ANDROID_NDK_ROOT="$NDK_DIR"
export ANDROID_SDK_ROOT="$SDK_DIR"
export ANDROID_HOME="$SDK_DIR"
export JAVA_HOME="${JAVA_HOME:-/usr/lib/jvm/java-21-openjdk-amd64}"
export PATH="$JAVA_HOME/bin:$PATH"

# Godot looks for the Android export template in
#   <data dir>/export_templates/<GODOT_VERSION_FULL_CONFIG>/android_release.apk
# The version string is read from the srclib itself instead of being hardcoded,
# so bumping the srclib in the metadata cannot silently desync this script.
GODOT_VERSION="$(
    awk -F'[ ="]+' '
        /^major[[:space:]]*=/ { major  = $2 }
        /^minor[[:space:]]*=/ { minor  = $2 }
        /^patch[[:space:]]*=/ { patch  = $2 }
        /^status[[:space:]]*=/ { status = $2 }
        END {
            if (major == "" || minor == "" || patch == "" || status == "") {
                exit 1
            }
            printf "%s.%s.%s.%s", major, minor, patch, status
        }
    ' "$GODOT_SRC/version.py"
)" || {
    log "ERROR: cannot derive the Godot version from $GODOT_SRC/version.py"
    exit 1
}

TEMPLATE_DIR="$HOME/.local/share/godot/export_templates/$GODOT_VERSION"
TEMPLATE_APK="$TEMPLATE_DIR/android_release.apk"

log() { printf '==> %s\n' "$*" >&2; }

log "Godot $GODOT_VERSION (srclib: $GODOT_SRC)"
log "NDK:     $NDK_DIR"
log "SDK:     $SDK_DIR"
log "Java:    $JAVA_HOME"

# ---------------------------------------------------------------------------
# 1. Build the editor (linuxbsd) and the arm64 Android release template.
# ---------------------------------------------------------------------------
pushd "$GODOT_SRC" >/dev/null
log "Compiling the Godot editor (platform=linuxbsd, target=editor)"
scons -j "$(nproc)" platform=linuxbsd target=editor

log "Compiling the Godot Android template (target=template_release, arch=arm64)"
scons -j "$(nproc)" platform=android target=template_release arch=arm64

log "Assembling the export template (gradle generateGodotTemplates)"
pushd platform/android/java >/dev/null
gradle generateGodotTemplates
popd >/dev/null
popd >/dev/null

BUILT_TEMPLATE="$GODOT_SRC/bin/android_release.apk"
[ -f "$BUILT_TEMPLATE" ] || {
    log "ERROR: gradle did not produce $BUILT_TEMPLATE"
    exit 1
}

# ---------------------------------------------------------------------------
# 2. Install it where the editor expects to find it.
# ---------------------------------------------------------------------------
mkdir -p "$TEMPLATE_DIR"
cp "$BUILT_TEMPLATE" "$TEMPLATE_APK"
log "Installed export template: $TEMPLATE_APK"

# ---------------------------------------------------------------------------
# 3. Export the project.
#
# Deterministic by construction: every node in scenes/main.tscn carries a
# pinned unique_id. Without it Godot assigns one from a cryptographic RNG
# (SceneState::_parse_node -> ResourceUID::create_id) each time the scene is
# packed, which changes the exported .scn, its checksums in the .pck and
# therefore the APK on every single build.
# ---------------------------------------------------------------------------
mkdir -p "$(dirname "$OUTPUT")"
log "Exporting preset '$PRESET' -> $OUTPUT"
"$GODOT_SRC/bin/godot.linuxbsd.editor.x86_64" \
    --headless \
    --path . \
    --export-release "$PRESET" \
    "$OUTPUT"

[ -f "$OUTPUT" ] || {
    log "ERROR: Godot did not produce $OUTPUT"
    exit 1
}

log "Built $OUTPUT ($(stat -c %s "$OUTPUT") bytes)"