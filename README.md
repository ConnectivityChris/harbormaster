# mobile-flow-runner

A Claude Code skill (packaged as a plugin) that runs scripted regression UI flows against iOS simulators and Android emulators, using [Maestro](https://maestro.mobile.dev) under the hood.

Built for the loop **"I made a change → did I break anything obvious?"** — before pushing a build to TestFlight, App Store, or Play Store.

**Status:** v0.1.0 — end-to-end validated against an Expo SDK 55 React Native app on iPhone 17 Pro / iOS 26.2 with Maestro 2.5.0, running both `app-launch` and `login` smoke flows. Android path implemented but not yet exercised end-to-end.

## What it does

When invoked, the skill:

1. **Preflights** your machine (Xcode, Maestro, Android SDK)
2. **Boots** an iOS simulator and/or Android emulator
3. **Installs** your app — dev build, Expo Go deep-link, or already-installed
4. **Reads any required credentials** from your shell environment, or prompts for them at the start of the run (the skill never stores credentials anywhere)
5. **Runs** the Maestro flows in your project's `.maestro/` directory
6. **Reports** pass/fail with screenshots, video, and JUnit XML for any failures

## Prerequisites

- **macOS** (iOS simulator requires Xcode)
- **Xcode** + CLI tools (for iOS)
- **Maestro CLI** (skill will offer to install if missing)
- **Android SDK + AVD** (optional, for Android — skill runs iOS-only otherwise)

## Expo Go vs dev build

- **Dev build** (`bunx expo run:ios` / `:android`) is the **recommended target for regression runs**. No Expo Go overlays, no dev tools popovers, no cold-reload tax — flows run hands-off.
- **Expo Go** is fine for inner-loop "did I break the launch?" checks but not for hands-off automation: dev menus, "What's new" sheets, and permission prompts can interrupt flows and require manual taps. Treat it as a fast feedback loop, not a CI target.

## Install

This repo doubles as a Claude Code plugin marketplace. Inside Claude Code:

```
/plugin marketplace add ConnectivityChris/mobile-flow-runner
/plugin install mobile-flow-runner@connectivity-chris
```

Or via the CLI:

```bash
claude plugin marketplace add ConnectivityChris/mobile-flow-runner
claude plugin install mobile-flow-runner@connectivity-chris
```

### Versioning

The plugin declares its version in `.claude-plugin/plugin.json`. Users installed from the marketplace stay on whatever version is declared at HEAD of `main` and only receive an update when that field is bumped. There's no need to pin to a tag in the install command — the `version` field is itself the pin. Tags exist for release tracking (`mobile-flow-runner--v0.1.0`) but aren't required to use the plugin.

### Local development

To work on the plugin itself rather than consume it:

```bash
git clone git@github.com:ConnectivityChris/mobile-flow-runner.git ~/dev/mobile-flow-runner
claude --plugin-dir ~/dev/mobile-flow-runner
```

## Use

Once installed, the skill triggers on prompts like:

- "Run the regression flows on iOS"
- "Test the app on the simulator before I push"
- "Smoke test the mobile build"
- "Click through the login flow on Android"

Or invoke directly:

```
> Use mobile-flow-runner to verify the iOS build still launches and reaches the home screen
```

## Project setup

Add a `.maestro/` directory to your mobile project containing your flow files (YAML). Optionally add `.maestro/config.json` for project-level defaults:

```json
{
  "ios": {
    "bundleId": "com.example.app",
    "devBuildPath": "ios/build/Build/Products/Debug-iphonesimulator/Example.app",
    "preferredDevice": "iPhone 17 Pro"
  },
  "android": {
    "package": "com.example.app",
    "devBuildPath": "android/app/build/outputs/apk/debug/app-debug.apk",
    "preferredAvd": "Pixel_8_Pro"
  },
  "expoGo": {
    "devServerUrl": "exp://192.168.1.10:8081"
  }
}
```

Starter flows are in `references/flow-examples/` — copy and adapt.

### One-time app changes for hands-off flows

Maestro talks to your app via the iOS / Android accessibility tree. React Native on iOS bundles all sibling `<Text>` content into a single parent `accessibilityText` element, which means individual `TextInput`s aren't directly addressable by Maestro selectors **unless you wrap them**. For flows that interact with form inputs (login, search, profile edit, etc.):

```tsx
// In your login screen / form components
import { View } from "react-native";

<View accessible testID="email_input">
  <TextInput ... />
</View>

<View accessible testID="password_input">
  <TextInput secureTextEntry ... />
</View>

<Button testID="login_submit" onPress={...}>...</Button>
```

`<Pressable>` and `<Button>` don't need a wrapper — they expose `testID` natively. Only `<TextInput>` (and components built around it) needs the `<View accessible>` wrapper. See `references/writing-flows.md` for the full RN-specific patterns.

## Known limitations / not yet exercised

- **Android end-to-end** — scripts and docs are in place but no real Android run has been completed. Expect rough edges around AVD bootstrap and `adb` deep-link URL formats.
- **Expo Go popovers** — Expo Go's dev menu, "What's new" sheets, and first-launch permission prompts can block flows mid-run and require manual taps. Use a dev build for hands-off automation.
- **macOS only** — iOS simulator is macOS-exclusive. Android-only setups on Linux / Windows would work in principle but the skill currently assumes a Mac.

## Layout

```
mobile-flow-runner/
├── .claude-plugin/
│   ├── plugin.json            # plugin manifest
│   └── marketplace.json       # marketplace catalog (this repo doubles as its own marketplace)
├── SKILL.md                   # the skill (loaded into Claude's context when triggered)
├── CHANGELOG.md               # release history
├── scripts/
│   ├── preflight.sh           # validate env
│   ├── list-devices.sh        # enumerate iOS sims and Android AVDs for picker
│   ├── boot-sims.sh           # boot chosen iOS sim + Android emulator
│   ├── install-app.sh         # install dev build or open Expo Go
│   └── run-flows.sh           # run Maestro and capture artifacts
└── references/
    ├── writing-flows.md       # Maestro YAML cheat sheet + RN-specific patterns
    ├── ios-setup.md           # Xcode + sim setup help
    ├── android-setup.md       # Android SDK + AVD setup help
    ├── troubleshooting.md     # common failures + fixes
    └── flow-examples/         # generic starter flows
        ├── app-launch.yaml
        ├── login.yaml
        └── view-list.yaml
```

## License

MIT — see [LICENSE](./LICENSE).
