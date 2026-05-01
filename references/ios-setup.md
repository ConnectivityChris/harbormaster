# iOS setup

What you need to drive the iOS simulator with Maestro.

## Required

1. **macOS** — iOS simulator only runs on macOS.
2. **Full Xcode.app** — install from the [Mac App Store](https://apps.apple.com/app/xcode/id497799835). Xcode CLI tools alone (the thing `xcode-select --install` gives you) are not enough; the iOS simulator runtime ships inside Xcode.app.
3. **Point xcode-select at Xcode.app**:
   ```bash
   sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
   ```
   Verify with `xcode-select -p` — should print `/Applications/Xcode.app/Contents/Developer`.
4. **An iOS simulator runtime** — Xcode → Settings → Platforms → download an iOS runtime if `xcrun simctl list devices available` shows none.

## Verifying

```bash
xcrun simctl list devices available | grep iPhone
```

Should list at least one iPhone simulator.

```bash
xcrun simctl boot "iPhone 15"      # or whichever device name shows up
open -a Simulator
```

The simulator window should appear and finish booting.

## Building an app for the simulator

When you build a React Native or Expo dev client locally for testing, the build output is platform-specific:

| Build target | Path (typical) | Architecture |
|---|---|---|
| iOS simulator | `ios/build/Build/Products/Debug-iphonesimulator/<App>.app` | x86_64 / arm64 (sim) |
| iOS device | `ios/build/Build/Products/Debug-iphoneos/<App>.app` | arm64 (device) |

You can only install the **simulator** build on the simulator. If `xcrun simctl install booted ...` fails with "incompatible architecture," you've got the device build by accident.

For Expo:

```bash
# build a dev client for the simulator
bunx expo run:ios
```

This produces a simulator-compatible `.app` and installs it automatically.

## Common iOS issues

**"No simulators available"**
Open Xcode → Settings → Platforms → download an iOS runtime.

**Simulator hangs at boot**
Reset state:
```bash
xcrun simctl shutdown all
xcrun simctl erase all
```

**Maestro reports "No iOS device connected"**
Make sure the simulator is fully booted before running flows:
```bash
xcrun simctl bootstatus booted -b
```

**App installs but Maestro can't drive it**
Maestro injects via XCUITest. Newer Xcode versions sometimes need:
```bash
maestro start-device --platform ios
```
to set up the test runner.
