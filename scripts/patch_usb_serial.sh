#!/usr/bin/env bash
# Patch flutter_libserialport's android/build.gradle so it
# builds against AGP 9 + Gradle 9.
#
# The plugin (0.6.0) ships a build.gradle that:
#   1. Calls jcenter() — removed in Gradle 8, breaks the build.
#   2. Does NOT declare the com.android.library plugin that AGP
#      9 requires for subproject evaluation.
#
# This script runs in CI right after `flutter pub get` so the
# Android release APK can compile. It's a no-op if the patch has
# already been applied (idempotent).
#
# Triggered by: .github/workflows/build.yml (build-apk job).
set -euo pipefail

PLUGIN_BUILD="$HOME/.pub-cache/hosted/pub.dev/flutter_libserialport-0.6.0/android/build.gradle"

if [ ! -f "$PLUGIN_BUILD" ]; then
  echo "flutter_libserialport plugin build.gradle not found at $PLUGIN_BUILD — skipping patch."
  exit 0
fi

# Idempotency guard: only patch once.
if grep -q '# PATCHED BY CI' "$PLUGIN_BUILD"; then
  echo "flutter_libserialport android/build.gradle already patched — skipping."
  exit 0
fi

# Apply the patch:
#   * replace jcenter() with mavenCentral()
#   * append `apply plugin: 'com.android.library'` if missing
python3 <<'PY'
import re, pathlib
p = pathlib.Path.home() / ".pub-cache/hosted/pub.dev/flutter_libserialport-0.6.0/android/build.gradle"
src = p.read_text()
# 1. jcenter() -> mavenCentral()
src = src.replace("jcenter()", "mavenCentral()")
# 2. Ensure com.android.library plugin is applied
if "com.android.library" not in src:
    src = "apply plugin: 'com.android.library'\n" + src
# 3. Mark the patch
src = "// PATCHED BY CI — see scripts/patch_usb_serial.sh\n" + src
p.write_text(src)
print("patched", p)
PY

echo "OK — flutter_libserialport android/build.gradle patched."
