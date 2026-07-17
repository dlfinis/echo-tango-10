#!/usr/bin/env bash
# Patch usb_serial's legacy android/build.gradle so it builds against
# AGP 9 + Gradle 9. The plugin's runtime API uses Android UsbManager,
# which is required for USB-OTG permission handling.
#
# This script runs in CI right after `flutter pub get` so the
# Android release APK can compile. It's a no-op if the patch has
# already been applied (idempotent).
#
# Triggered by: .github/workflows/build.yml (build-apk job).
set -euo pipefail

PLUGIN_BUILD="$HOME/.pub-cache/hosted/pub.dev/usb_serial-0.5.2/android/build.gradle"

if [ ! -f "$PLUGIN_BUILD" ]; then
  echo "usb_serial plugin build.gradle not found at $PLUGIN_BUILD — skipping patch."
  exit 0
fi

# Idempotency guard: only patch once.
if grep -q '# PATCHED BY CI' "$PLUGIN_BUILD"; then
  echo "usb_serial android/build.gradle already patched — skipping."
  exit 0
fi

# The plugin still declares AGP 4.1 and old Android Gradle DSL. The host
# project already supplies AGP 9, so the legacy buildscript must be removed
# rather than letting it resolve a conflicting Android Gradle Plugin.
python3 <<'PY'
import pathlib

p = pathlib.Path.home() / ".pub-cache/hosted/pub.dev/usb_serial-0.5.2/android/build.gradle"
src = p.read_text()

def remove_block(text, prefix):
    start = text.find(prefix)
    if start == -1:
        return text
    brace = text.find("{", start)
    if brace == -1:
        return text
    depth = 0
    for index in range(brace, len(text)):
        if text[index] == "{":
            depth += 1
        elif text[index] == "}":
            depth -= 1
            if depth == 0:
                return text[:start] + text[index + 1:]
    raise RuntimeError(f"Unclosed Gradle block: {prefix}")

src = remove_block(src, "buildscript")
src = remove_block(src, "rootProject.allprojects")
src = src.replace("compileSdkVersion 33", "compileSdk 35")
src = src.replace("minSdkVersion 16", "minSdk 16")
src = src.replace("lintOptions {", "lint {")
src = src.replace("jcenter()", "mavenCentral()")
if "apply plugin: 'com.android.library'" not in src:
    src = "apply plugin: 'com.android.library'\n" + src
src = "// PATCHED BY CI — see scripts/patch_usb_serial.sh\n" + src
p.write_text(src)
print("patched", p)
PY

echo "OK — usb_serial android/build.gradle patched."
