#!/usr/bin/env bash
# Builds a debug-signed Android APK with Godot (headless).
# Used by .github/workflows/android.yml; also works locally.
#
# Env:
#   GODOT_BIN         path to the Godot editor binary          (default: godot)
#   GODOT_VERSION     e.g. 4.6.2 (must match installed templates) (default: 4.6.2)
#   ANDROID_SDK_ROOT  Android SDK with build-tools + platform-tools
#   JAVA_HOME         JDK 17+
#   OUT               output apk path                            (default: build/night-ride.apk)
set -euo pipefail

GODOT_BIN="${GODOT_BIN:-godot}"
GODOT_VERSION="${GODOT_VERSION:-4.6.2}"
OUT="${OUT:-build/night-ride.apk}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
KEYSTORE="${DEBUG_KEYSTORE:-$HOME/.android/debug.keystore}"

: "${ANDROID_SDK_ROOT:?set ANDROID_SDK_ROOT}"
: "${JAVA_HOME:?set JAVA_HOME}"

# 1. Debug keystore (same one every build on a machine, so updates install over each other).
if [ ! -f "$KEYSTORE" ]; then
  mkdir -p "$(dirname "$KEYSTORE")"
  keytool -keyalg RSA -genkeypair -alias androiddebugkey -keypass android \
    -keystore "$KEYSTORE" -storepass android -dname "CN=Android Debug,O=Android,C=US" \
    -validity 9999 -deststoretype pkcs12
fi

# 2. Editor settings Godot needs for Android export.
MAJOR_MINOR="$(echo "$GODOT_VERSION" | cut -d. -f1,2)"
CONF="${XDG_CONFIG_HOME:-$HOME/.config}/godot"
mkdir -p "$CONF"
for f in "editor_settings-${MAJOR_MINOR}.tres" "editor_settings-4.tres"; do
  cat > "$CONF/$f" <<EOF
[gd_resource type="EditorSettings" format=3]

[resource]
export/android/android_sdk_path = "$ANDROID_SDK_ROOT"
export/android/java_sdk_path = "$JAVA_HOME"
export/android/debug_keystore = "$KEYSTORE"
export/android/debug_keystore_user = "androiddebugkey"
export/android/debug_keystore_pass = "android"
EOF
done
export GODOT_ANDROID_KEYSTORE_DEBUG_PATH="$KEYSTORE"
export GODOT_ANDROID_KEYSTORE_DEBUG_USER="androiddebugkey"
export GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD="android"

# 3. Import + export.
cd "$ROOT"
mkdir -p "$(dirname "$OUT")"
"$GODOT_BIN" --headless --import || true
"$GODOT_BIN" --headless --export-debug "Android" "$OUT"
test -f "$OUT"
ls -la "$OUT"
