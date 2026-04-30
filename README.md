# mobile-flow-runner

A Claude Code skill (packaged as a plugin) that runs scripted regression UI flows against iOS simulators and Android emulators, using [Maestro](https://maestro.mobile.dev) under the hood.

Built for the loop **"I made a change → did I break anything obvious?"** — before pushing a build to TestFlight, App Store, or Play Store.

**Status:** v0.2.2 — end-to-end validated against an Expo SDK 55 React Native app on iPhone 17 Pro / iOS 26.2 with Maestro 2.5.0, running both `app-launch` and `login` smoke flows. Android path implemented but not yet exercised end-to-end.

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
- **Expo Go** is fine for inner-loop "did I break the launch?" checks but not for hands-off automation: dev menus, "What's new" sheets, and permission prompts can interrupt flows and require manual taps. Treat it as a fast feedback loop, not a release-gate.

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

The plugin declares its version in `.claude-plugin/plugin.json`. Two install modes:

- **Track HEAD**: `/plugin marketplace add ConnectivityChris/mobile-flow-runner` — you get whatever version is at HEAD of `main`. Updates land when you next sync.
- **Pin to a release**: `/plugin marketplace add ConnectivityChris/mobile-flow-runner@vX.Y.Z` — pinned to a specific tag. Recommended for stable workflows.

Pinning to a tag is the canonical path for users who want predictable behaviour. HEAD is fine if you're following along with development.

### Local development

To work on the plugin itself rather than consume it:

```bash
git clone git@github.com:ConnectivityChris/mobile-flow-runner.git ~/dev/mobile-flow-runner
claude --plugin-dir ~/dev/mobile-flow-runner
```

## Use

Once installed, four slash commands cover the flow lifecycle:

| Command | When |
|---|---|
| `/initflow` | First time using the skill on a project — scaffolds `.maestro/` with starter flows tuned to your project |
| `/buildsuite` | After `/initflow` — build a core suite of flows in one session via a guided tour of the app + per-flow authoring checkpoints. See `commands/buildsuite.md` |
| `/authorflow [flow-name]` | Adding a new flow — guided interview, screen capture, selector picking, compose, run |
| `/stabiliseflow <flow> [N]` | Hardening a flow before relying on it as a release gate — runs N times, reports flake rate |

The skill also triggers on natural-language prompts like:

- "Run the regression flows on iOS"
- "Test the app on the simulator before I push"
- "Smoke test the mobile build"
- "Click through the login flow on Android"

For new projects, start with `/initflow` then `/authorflow app-launch`.

## Project setup

Use `/initflow` from Claude Code to scaffold the `.maestro/` directory automatically. It discovers your project's `bundleId` / `package`, detects whether you have auth, and writes starter flows + an onboarding README.

If you'd rather set up by hand, add a `.maestro/` directory with your flow files (YAML) and optionally `.maestro/config.json` for project-level defaults:

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

Maestro talks to your app via the iOS / Android accessibility tree. React Native on iOS sometimes flattens descendants of an accessibility-container parent into one bundled label, which silently drops `testID` on every child. The fix is **one prop on the container**, not a wrapper per input:

```tsx
// In your layout component (KeyboardAvoidingView, SafeAreaView, AuthLayout, etc.)
<KeyboardAvoidingView accessible={false} ...>
  {children}
</KeyboardAvoidingView>
```

After that, bare `testID` on `TextInput` works directly:

```tsx
<FormTextInput name="email" testID="email_input" ... />
<FormTextInput name="password" testID="password_input" secureTextEntry ... />
<Button testID="login_submit" onPress={...}>...</Button>
```

`<Pressable>` and `<Button>` already expose `testID` natively without container help. The `accessible={false}` fix is needed only when an ancestor View is acting as an accessibility container that swallows descendants. See `references/writing-flows.md` for the full RN-specific patterns and the per-input wrapper fallback for cases where you can't reach the container.

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
├── CHANGELOG.md               # release history
├── skills/
│   └── mobile-flow-runner/
│       └── SKILL.md           # the skill (loaded into Claude's context when triggered)
├── commands/                  # slash commands wrapping the flow lifecycle
│   ├── initflow.md            # /initflow — one-time project bootstrap
│   ├── buildsuite.md          # /buildsuite — guided tour + multi-flow authoring
│   ├── authorflow.md          # /authorflow — phased authoring loop for a single flow
│   └── stabiliseflow.md       # /stabiliseflow — multi-run flake detection
├── scripts/
│   ├── preflight.sh           # validate env
│   ├── list-devices.sh        # enumerate iOS sims and Android AVDs for picker
│   ├── boot-sims.sh           # boot chosen iOS sim + Android emulator
│   ├── install-app.sh         # install dev build or open Expo Go
│   └── run-flows.sh           # run Maestro and capture artifacts
└── references/
    ├── authoring-flows.md     # phased loop process guide (init / author / stabilise)
    ├── building-suites.md     # /buildsuite depth doc (tour-then-author lifecycle)
    ├── writing-flows.md       # Maestro YAML cheat sheet + RN-specific patterns
    ├── maestro-readme-template.md # onboarding-doc template for <project>/.maestro/README.md
    ├── ios-setup.md           # Xcode + sim setup help
    ├── android-setup.md       # Android SDK + AVD setup help
    ├── troubleshooting.md     # common failures + fixes (incl. token-aware debug tiering)
    └── flow-examples/         # generic starter flows
        ├── app-launch.yaml
        ├── login.yaml
        ├── view-list.yaml
        └── config.yaml        # Maestro workspace config template
```

## Releases

This repo is its own Claude Code marketplace (`.claude-plugin/marketplace.json`). Users install via `/plugin marketplace add ConnectivityChris/mobile-flow-runner` (HEAD) or `@vX.Y.Z` (pinned).

For maintainers cutting a release, **always**:

1. Bump `version` in `.claude-plugin/plugin.json`.
2. Move `[Unreleased]` items in `CHANGELOG.md` under a new `[X.Y.Z] — YYYY-MM-DD` header.
3. Update comparison link footers in `CHANGELOG.md`.
4. Commit and `git push origin main`.
5. `git tag vX.Y.Z && git push origin vX.Y.Z`.

The git tag IS the marketplace release. An unpushed tag means version-pinned installs fall back silently to HEAD — users get unreleased code thinking they pinned. Push the tag every time. See `CLAUDE.md` → "Release process" for the full reasoning.

## License

MIT — see [LICENSE](./LICENSE).
