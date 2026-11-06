# Build & release

## CI (GitHub Actions) — `.github/workflows/android.yml`
Trigger: every push to `main`, or manually (**Actions → Build Android APK → Run workflow**).

Steps: checkout → JDK 17 → download Godot 4.6.2 + export templates (cached; only Android templates kept) →
`tools/build_android.sh` (generates a debug keystore if none, writes Godot editor settings with the runner's
Android SDK path, imports, `--export-debug "Android"`) → uploads the APK as an artifact → replaces the **`latest`**
GitHub pre-release with the new `night-ride.apk` (easy to download on a phone).

### Signature
CI signs with the committed **debug** keystore `tools/debug.keystore` (alias `androiddebugkey`, password `android` —
the standard, non-secret Android debug credentials). Same signature every build, so new APKs install over old ones.
Never use it for a Play Store release.

## Local APK build
Needs: Godot 4.6.2 editor binary, the 4.6.2 export templates (Android files in
`~/.local/share/godot/export_templates/4.6.2.stable/`), an Android SDK with `build-tools` + `platform-tools`, JDK 17+.

```bash
GODOT_BIN=godot ANDROID_SDK_ROOT=$HOME/Android/Sdk JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64 \
  bash tools/build_android.sh
# -> build/night-ride.apk
```

## Export preset
`export_presets.cfg` → preset **"Android"**: no Gradle build, arm64-v8a + armeabi-v7a, package
`com.kditlabs.nightride`, immersive mode, vibrate permission, landscape (`window/handheld/orientation=4` sensor landscape).

## Play Store release (later)
- Switch to a **release** keystore (never commit it), `--export-release`, and export an **AAB**
  (requires `gradle_build/use_gradle_build=true` + `gradle_build/export_format=1` and the Android build template).
- Bump `version/code` and `version/name` in `export_presets.cfg` each upload.
- Target SDK must meet Play's current requirement — Godot 4.6 templates target a recent SDK; verify at release time.
