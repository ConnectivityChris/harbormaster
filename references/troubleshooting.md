# Troubleshooting

Common failure modes and their fixes when running mobile-flow-runner.

## Preflight

**"Only Xcode CLI tools found, not full Xcode"**
You need full Xcode.app. CLI tools don't ship the iOS simulator runtime.
Fix: install Xcode from the App Store, then `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`.

**"Maestro CLI not installed"**
```bash
curl -fsSL "https://get.maestro.mobile.dev" | bash
# or
brew tap mobile-dev-inc/tap && brew install mobile-dev-inc/tap/maestro
```

**"No AVDs configured"**
Open Android Studio → Device Manager → Create Virtual Device. Optional — skill runs iOS-only if you skip Android.

## Booting

**"Simulator hangs at the Apple logo"**
```bash
xcrun simctl shutdown all
xcrun simctl erase all
```
Then re-run `boot-sims.sh ios`.

**"Android emulator starts but adb says no device"**
```bash
adb kill-server && adb start-server
adb devices       # should now show emulator-5554
```

## Installing

**"Could not install app: incompatible architecture"** (iOS)
The `.app` you're trying to install was built for a real device, not the simulator. Look for a path with `Debug-iphonesimulator` rather than `Debug-iphoneos`.

For Expo: `bunx expo run:ios` builds and installs a simulator build automatically.

**"Failure [INSTALL_FAILED_OLDER_SDK]"** (Android)
The APK targets a newer Android API than the AVD. Recreate the AVD with a newer system image (API 33+ for current Expo SDKs).

**"Expo Go opens but my project doesn't load"**
The dev server URL is stale or the LAN IP has changed. Restart `bunx expo start` and use the fresh URL printed in the terminal (`exp://192.168.x.x:8081`).

## Efficient debugging (token-aware tiering)

When diagnosing a failure, work cheapest-to-costliest. Screenshots are the most token-expensive tool you have — reach for them last, not first.

| Tier | Tool | Use for | Cost |
|---|---|---|---|
| 0 | `run.log` + JUnit `report.xml` | Failed step name, selector that didn't match, stack of preceding steps | ~tens to hundreds of tokens |
| 1 | `maestro hierarchy` (filter with `jq`) | "Does the selector exist?" "Is it disabled?" "What id is the element actually under?" | ~hundreds to low-thousands |
| 2 | Screenshot at failure point | Visual issues only — layout overlap, unexpected dialog, dark/empty render | ~1.5k tokens per image |
| 3 | Video | Timing / non-determinism — hand to the user, don't try to consume yourself | n/a |

The booted sim/emulator is still running after a flow fails — `maestro hierarchy` inspects current screen state without re-running. Filter the output to keep just the fields you need:

```bash
maestro --device <udid-or-serial> hierarchy \
  | jq '.. | objects | {text, "resource-id", enabled} | select(.text or ."resource-id")'
```

Raw hierarchy on a busy RN screen can be 5k+ tokens; the filter above typically cuts it under 1k.

This tiering applies to **debugging**. When **authoring** new flows, use whatever you need (including screenshots) to get the flow correct — efficiency matters less than correctness during authoring.

## Flow execution

**"Element not found"**
The selector doesn't match anything on screen. Run `maestro hierarchy` (see [Efficient debugging](#efficient-debugging-token-aware-tiering) above) to confirm what's actually on screen — cheaper than a screenshot, often enough to find the right selector. Prefer text and accessibility-label selectors over coordinates.

**"Element found but tap had no effect"**
The element is rendered but disabled, off-screen, or covered by something. Check `enabled: true` selector qualifier, or scroll to it first.

**"Flow times out waiting for screen"**
Network is slow or the app is doing more work than expected. Increase the timeout for the specific wait:
```yaml
- extendedWaitUntil:
    visible: "Inbox"
    timeout: 30000
```

**"Flow passes locally but fails on a different machine"**
Almost always one of: different simulator size (coordinate-based selectors break), different system locale (text selectors break), unauthorised state (notifications, location, camera permissions). Bias toward `accessibilityLabel` selectors and explicit permission handling at the start of flows.

## Credentials

The skill never stores credentials. If a flow needs login, the skill either reads the variable from your shell environment (if already set) or prompts at the start of the run — values are used for that invocation only and discarded after.

**"I get prompted every run, can I avoid it?"**
Yes — pre-export the variable in your shell before invoking:
```bash
export MAESTRO_USERNAME="..."
export MAESTRO_PASSWORD="..."
```
Or use a tool like `direnv` with a gitignored `.envrc` per project. The skill will use what's already set and skip the prompt. Storage is your responsibility, not the skill's — by design.

## Artifacts

Artifacts default to `<project>/.maestro/artifacts/<run-id>/`. If you want them somewhere else, pass `--output <dir>` to `run-flows.sh`.

Maestro saves screenshots, video, and a JUnit XML report. The video is useful for understanding non-deterministic failures — open it to see exactly what the app was doing at the failure point.
