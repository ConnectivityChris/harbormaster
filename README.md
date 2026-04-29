# mobile-flow-runner

A Claude Code skill (packaged as a plugin) that runs scripted regression UI flows against iOS simulators and Android emulators, using [Maestro](https://maestro.mobile.dev) under the hood.

Built for the loop **"I made a change → did I break anything obvious?"** — before pushing a build to TestFlight, App Store, or Play Store.

## What it does

When invoked, the skill:

1. **Preflights** your machine (Xcode, Maestro, Android SDK)
2. **Boots** an iOS simulator and/or Android emulator
3. **Installs** your app — dev build, Expo Go deep-link, or already-installed
4. **Pulls credentials** from macOS Keychain (or prompts and offers to store)
5. **Runs** the Maestro flows in your project's `.maestro/` directory
6. **Reports** pass/fail with screenshots, video, and JUnit XML for any failures

## Prerequisites

- **macOS** (iOS simulator requires Xcode)
- **Xcode** + CLI tools (for iOS)
- **Maestro CLI** (skill will offer to install if missing)
- **Android SDK + AVD** (optional, for Android — skill runs iOS-only otherwise)

## Install

> Until this is published to a marketplace, install as a local plugin directory.

```bash
# Clone this repo somewhere
git clone https://github.com/USERNAME/mobile-flow-runner ~/dev/mobile-flow-runner

# Run Claude Code with this plugin mounted for the session
claude --plugin-dir ~/dev/mobile-flow-runner
```

Alternatively, symlink it into your user plugins directory.

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
    "devBuildPath": "ios/build/Build/Products/Debug-iphonesimulator/Example.app"
  },
  "android": {
    "package": "com.example.app",
    "devBuildPath": "android/app/build/outputs/apk/debug/app-debug.apk"
  },
  "expoGo": {
    "devServerUrl": "exp://192.168.1.10:8081"
  },
  "credsAccount": "example-app"
}
```

Starter flows are in `references/flow-examples/` — copy and adapt.

## Layout

```
mobile-flow-runner/
├── .claude-plugin/
│   └── plugin.json            # plugin manifest
├── SKILL.md                   # the skill (loaded into Claude's context when triggered)
├── scripts/
│   ├── preflight.sh           # validate env
│   ├── boot-sims.sh           # boot iOS sim + Android emulator
│   ├── install-app.sh         # install dev build or open Expo Go
│   ├── run-flows.sh           # run Maestro and capture artifacts
│   └── keychain-creds.sh      # store/retrieve login creds in macOS Keychain
└── references/
    ├── writing-flows.md       # Maestro YAML cheat sheet
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
