---
name: mobile-flow-runner
description: Run scripted regression UI flows against iOS simulator and Android emulator for React Native, Expo, or native mobile apps using Maestro. Use this skill whenever the user wants to test mobile builds locally, smoke test before pushing to the App Store or Play Store, run click-through tests on a simulator, validate Expo dev build changes, exercise an iOS sim or Android emulator programmatically, or do regression testing on mobile. Trigger even if the user does not mention "Maestro" — any request to drive an iOS simulator or Android emulator, run mobile UI tests locally, or validate mobile app behaviour before release should activate this skill.
---

# Mobile Flow Runner

Drive iOS simulators and Android emulators with scripted [Maestro](https://maestro.mobile.dev) flows. Built for the loop: "I made a change → did I break anything obvious?" — before pushing to the stores.

## When to use this skill

- Before merging a branch that touches mobile UI
- Before pushing a build to TestFlight, App Store, or Play Store internal track
- Validating an Expo SDK upgrade, dependency bump, or native module change
- Smoke-testing a dev build after a refactor
- Reproducing a UI bug deterministically

## When NOT to use

- Unit / component tests — use Jest, Bun test, Vitest, or the project's existing test runner
- Tests requiring deep RN-internal hooks (e.g. asserting on Redux state) — use Detox
- Pure visual-regression diffing — use Percy / Chromatic / similar
- End-to-end against real backends from CI — use Maestro Cloud or a device farm

## Prerequisites

This skill targets **macOS** (iOS simulator requires Xcode, which is macOS-only). Android automation works on Linux/Windows too, but this skill currently assumes macOS.

Required:
- macOS with Xcode + CLI tools (for iOS)
- Maestro CLI (the preflight script will offer to install it)

Optional:
- Android SDK + at least one AVD (for Android — the skill degrades gracefully to iOS-only if absent)

For deeper setup help, see `references/ios-setup.md` and `references/android-setup.md`.

## The workflow

Always step through these in order. Do not skip preflight even if the environment "looks fine."

### 1. Preflight

Run `${CLAUDE_PLUGIN_ROOT}/scripts/preflight.sh`. It verifies:

- Xcode CLI tools and full Xcode.app
- `maestro` on PATH (offers install command if missing)
- At least one bootable iOS simulator
- Android SDK and AVDs (optional — warns if missing rather than failing)

If a required tool is missing, walk the user through fixing it interactively. Don't dump the raw error output and stop — explain what's missing, why it matters, and the exact command to fix it. The preflight script's output is already structured this way; relay it cleanly to the user.

### 2. Determine target

Ask the user — or infer from project context (look for `app.json`, `app.config.ts`, `ios/`, `android/`):

- **Platform**: `ios`, `android`, or `both`. Default: `both` if Android is available, otherwise `ios`.
- **App source**:
  - `dev-build` — a built `.app` (iOS sim) or `.apk` (Android). Recommended default.
  - `expo-go` — Expo Go installed, dev server running, deep-link to project.
  - `installed` — app already installed; skip the install step.
- **Bundle ID / Android package**: from project config or ask once.

If the project has `<project>/.maestro/config.json`, read it for these defaults rather than asking. See [Project configuration](#project-configuration) below.

### 3. Boot the simulator(s)

Run `${CLAUDE_PLUGIN_ROOT}/scripts/boot-sims.sh <ios|android|both>`. This:

- Boots the first available iPhone simulator (or skips if already booted)
- Starts an Android emulator from the first AVD (or skips if already running)
- Waits for `boot_completed` before returning

### 4. Install the app

Run `${CLAUDE_PLUGIN_ROOT}/scripts/install-app.sh --platform <p> --source <s> [--path <p>] [--url <u>]`.

For Expo Go, the script uses `xcrun simctl openurl` (iOS) or `adb shell am start` (Android) to deep-link into the running dev server.

### 5. Handle credentials (if flows need login)

If a flow file references `${USERNAME}` or `${PASSWORD}`:

1. Try `${CLAUDE_PLUGIN_ROOT}/scripts/keychain-creds.sh get <account>` — `<account>` is the project name or value from `credsAccount` in the project config.
2. If creds aren't found (script exits non-zero), ask the user via `AskUserQuestion` for username and password.
3. Offer to store them: "Store these in your macOS Keychain so I don't have to ask again? (yes / no / never for this project)"
4. If yes, run `keychain-creds.sh set <account> <username> <password>`.
5. Pass the creds to Maestro via `--env USERNAME=... --env PASSWORD=...`.

If the user passes `--no-store` or selects "never", skip the offer and prompt every run.

### 6. Run flows

Run `${CLAUDE_PLUGIN_ROOT}/scripts/run-flows.sh --flows <path> --platform <p> [--env KEY=VAL ...]`.

The flows path is typically `<project>/.maestro/` — a directory of `.yaml` files Maestro will run in alphabetical order. The script:

- Targets the booted iOS sim and/or Android emulator (uses `--device` when both are running)
- Captures screenshots, video, and a JUnit XML report under `<project>/.maestro/artifacts/<run-id>/`
- Returns non-zero if any flow fails

### 7. Report

Summarise pass/fail per flow per platform. On failure:

- Read the screenshot at the failure point (`artifacts/<run-id>/<platform>/screenshot-*.png`)
- Surface the most relevant log lines (last ~30 lines of `run.log`)
- Suggest the likely cause (element not found → selector probably wrong; timeout → app slow to load; assertion failed → behaviour changed)

Do NOT just say "tests failed, here's the log." Diagnose.

## Authoring flows

If the project has no `.maestro/` directory yet, scaffold one. Copy the relevant starters from `references/flow-examples/` into `<project>/.maestro/` and adapt them to the app's actual screen content.

For Maestro syntax (commands, selectors, env vars, `runFlow`, retry, conditional logic), see `references/writing-flows.md`.

The general pattern for a new flow:

1. **Identify the user journey** in plain English ("user opens app, taps Login, enters email and password, lands on home screen, taps a conversation, sees messages")
2. **Write the YAML** using `tapOn`, `inputText`, `assertVisible`, etc.
3. **Run it once** to see what fails — Maestro's error output points at the offending step
4. **Adjust selectors** until it's stable across runs

Bias toward **text selectors** (`tapOn: "Login"`) and `accessibilityLabel`-based selectors over coordinate-based taps. Coordinates are brittle.

## Project configuration

If the project has `<project>/.maestro/config.json`, read it for defaults:

```json
{
  "ios": {
    "bundleId": "com.example.app",
    "devBuildPath": "ios/build/Build/Products/Debug-iphonesimulator/Example.app"
  },
  "android": {
    "package": "com.example.app",
    "devBuildPath": "android/app/build/outputs/apk/debug/app-debug.apk"
  },
  "expoGo": {
    "devServerUrl": "exp://192.168.1.10:8081"
  },
  "flowsDir": ".maestro",
  "credsAccount": "example-app"
}
```

If the file is missing, prompt for the values you need and offer to write the config so the user doesn't have to re-answer next time.

## Troubleshooting

Common failure modes and fixes:

- **"Simulator won't boot"** → check Xcode is installed (not just CLI tools); try `xcrun simctl shutdown all && xcrun simctl erase all` to reset state
- **"Maestro can't find element"** → screenshot the screen, inspect via `maestro studio`, prefer text or accessibility-label selectors
- **"App won't install on iOS sim"** → the `.app` was built for a real device, not the simulator. Look for a `Debug-iphonesimulator` build directory.
- **"Expo Go opens but my project doesn't load"** → the dev server URL is stale or the IP has changed. Restart `bunx expo start` and use the fresh URL.
- **"Android emulator boots but adb says 'unauthorized'"** → run `adb kill-server && adb start-server`

For a fuller list see `references/troubleshooting.md`.

## Reference index

- `references/writing-flows.md` — Maestro YAML syntax cheat sheet
- `references/ios-setup.md` — Xcode + sim setup, troubleshooting
- `references/android-setup.md` — Android SDK + AVD setup, troubleshooting
- `references/troubleshooting.md` — common errors and fixes
- `references/flow-examples/app-launch.yaml` — verify app launches and reaches home
- `references/flow-examples/login.yaml` — log in with stored creds
- `references/flow-examples/view-list.yaml` — navigate into a list and verify items render
