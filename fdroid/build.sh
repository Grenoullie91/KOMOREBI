#!/bin/bash
set -e

mkdir -p build/android

flatpak run org.godotengine.Godot \
  --headless \
  --path . \
  --export-release "Android F-Droid" \
  build/android/komorebi-fdroid.apk
