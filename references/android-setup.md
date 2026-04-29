# Android setup

What you need to drive the Android emulator with Maestro.

## Required

1. **Android SDK** — easiest path is install Android Studio, then Tools → SDK Manager.
2. **`ANDROID_HOME`** environment variable — point it at the SDK root:
   ```bash
   export ANDROID_HOME="$HOME/Library/Android/sdk"
   ```
3. **`platform-tools` and `emulator` on PATH**:
   ```bash
   export PATH="$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH"
   ```
4. **At least one AVD** (Android Virtual Device) — Android Studio → Device Manager → Create Virtual Device. Pick a Pixel device and a recent system image (API 33+ recommended for current Expo SDKs).

## Verifying

```bash
adb --version
emulator -list-avds
```

Both should print useful output. If `emulator -list-avds` is empty, create an AVD via Android Studio.

## Boot an emulator manually

```bash
emulator @<AVD_NAME> &
adb wait-for-device
adb shell getprop sys.boot_completed   # should print "1" once ready
```

## Building an app for the emulator

For React Native / Expo:

```bash
bunx expo run:android
```

This produces an APK at:
```
android/app/build/outputs/apk/debug/app-debug.apk
```

Install onto a running emulator with:
```bash
adb install -r android/app/build/outputs/apk/debug/app-debug.apk
```

## Common Android issues

**`adb` says "unauthorized"**
```bash
adb kill-server
adb start-server
```

**Emulator boots but Maestro can't connect**
```bash
adb devices       # should list emulator-5554 or similar
```
If empty, the emulator isn't fully booted. Wait for `sys.boot_completed`.

**Emulator very slow on Apple Silicon**
Use an arm64-v8a system image, not x86_64. Pick one with the "(Google APIs)" suffix.

**`HAXM` warnings on Apple Silicon**
HAXM is x86-only and irrelevant on arm64 Macs. Use Hypervisor.framework via the AVD setting "Use Detected ADB Location" with the correct system image.

**App installs but `am start` opens the wrong activity**
For Expo Go, the deep-link goes to `host.exp.exponent` (Expo Go's package). For dev-build APKs, your project's package handles the URL.
