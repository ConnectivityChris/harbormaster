# harbormaster

[![Version](https://img.shields.io/github/v/tag/ConnectivityChris/harbormaster?label=version&sort=semver)](https://github.com/ConnectivityChris/harbormaster/releases)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](./LICENSE)
[![Built for Claude Code](https://img.shields.io/badge/built%20for-Claude%20Code-7C3AED)](https://claude.com/claude-code)
[![Powered by Maestro](https://img.shields.io/badge/powered%20by-Maestro-00C853)](https://maestro.mobile.dev)

**Smoke-test your mobile app from a single Claude Code prompt — before every TestFlight, App Store, or Play Store push.**

Manual click-through testing is the tax you keep paying on every release. harbormaster is a Claude Code plugin that drives [Maestro](https://maestro.mobile.dev) flows against iOS simulators and Android emulators, so the loop *"I made a change → did I break anything obvious?"* takes one prompt instead of fifteen minutes of taps.

## Quickstart

In Claude Code:

```
/plugin marketplace add ConnectivityChris/harbormaster
/plugin install harbormaster@connectivity
```

Then, inside a mobile project (React Native, Expo, or native):

```
/initflow            # one-time: scaffolds .maestro/ with starter flows
/authorflow login    # add a flow with a guided interview + screen capture
```

That's it. The skill preflights your env, boots a sim, installs your build, runs the flows, and reports pass/fail with screenshots, video, and JUnit XML.

## What you get

- **One-prompt regression runs.** "Smoke test the build" → preflight → boot sim → install → run flows → diagnosis. No bespoke CI, no scripted glue code on your side.
- **Guided flow authoring.** Slash commands walk you through composing flows with screen captures, accessibility-tree inspection, and selector picking — so flows actually run hands-off the first time.
- **iOS + Android, dev build or Expo Go.** Per-platform device picker, dev-build install, or Expo Go deep-link. Defaults to dev build for hands-off reliability.
- **Credentials never persisted.** Reads from your shell env or prompts per-run. No `.env` writes, no Keychain integration, no surprises.
- **Token-aware failure diagnosis.** When a flow fails, the skill reads logs first, then the live UI hierarchy, and only loads screenshots if the failure is visual — keeping context windows lean.

## The four commands

| Command | When to use |
|---|---|
| `/initflow` | First time on a project — scaffolds `.maestro/` with starter flows tuned to your project |
| `/buildsuite` | Build a core suite of flows in one session via a guided tour + per-flow checkpoints |
| `/authorflow [flow-name]` | Add a single flow — guided interview, screen capture, selector picking, run |
| `/stabiliseflow <flow> [N]` | Harden a flow before relying on it as a release gate — runs N times, reports flake rate |

The skill also triggers on natural-language prompts (e.g. *"smoke test the iOS build before I push"*) — slash commands are the explicit entry points.

## Why harbormaster vs the alternatives

| | harbormaster | Bare Maestro CLI | Detox | Manual QA |
|---|---|---|---|---|
| Authoring help | Guided, AI-assisted | DIY YAML | JS test code | n/a |
| Sim/emulator orchestration | Built-in | DIY shell | Built-in | n/a |
| Failure diagnosis | Tiered, token-aware | Raw logs | Stack traces | Memory |
| Setup time | One install | Hours | Days | Zero |
| Best for | Pre-release smoke | Custom CI | Deep RN-internal asserts | One-off checks |

Use Detox or unit tests where you need them. harbormaster owns the **"is this build OK to ship?"** loop.

## Prerequisites

- **macOS** (iOS simulator requires Xcode)
- **[Xcode](https://apps.apple.com/app/xcode/id497799835)** + CLI tools (for iOS) — full setup help in [`references/ios-setup.md`](./references/ios-setup.md)
- **[Maestro CLI](https://docs.maestro.dev/getting-started/installing-maestro)** (preflight will offer to install if missing). Manual install:
  ```bash
  curl -fsSL "https://get.maestro.mobile.dev" | bash    # or
  brew tap mobile-dev-inc/tap && brew install mobile-dev-inc/tap/maestro
  ```
- **[Android SDK](https://developer.android.com/studio) + AVD** (optional — skill runs iOS-only otherwise) — full setup help in [`references/android-setup.md`](./references/android-setup.md)

## Install

```bash
# Inside Claude Code (recommended — pin to a release tag)
/plugin marketplace add ConnectivityChris/harbormaster@v0.5.1
/plugin install harbormaster@connectivity
```

Drop the `@v0.5.1` to track HEAD instead. Pinning is recommended for stable workflows; HEAD is fine if you want unreleased changes.

## Project setup

Run `/initflow` from inside your mobile project. It discovers your `bundleId` / `package`, detects auth, and scaffolds `.maestro/` with starter flows, an onboarding README, and a `config.json` of skill defaults.

Manual setup, configuration schema, and the full Maestro YAML reference live in [`references/`](./references). Starter flows are in [`references/flow-examples/`](./references/flow-examples/) — copy and adapt.

> **React Native gotcha:** Maestro talks to your app via the accessibility tree, and RN on iOS sometimes drops `testID` on inputs. The fix is one prop on a parent container — see [`references/writing-flows.md`](./references/writing-flows.md) for the full pattern.

## Expo Go vs dev build

- **Dev build** (`bunx expo run:ios|:android`) — recommended for regression runs. No overlays, no popovers, no cold-reload tax.
- **Expo Go** — fine for quick "did I break the launch?" checks; not for hands-off automation. Dev menus and permission prompts can interrupt flows.

## Status & limitations

Current version: **v0.5.1**. End-to-end validated against an Expo SDK 55 React Native app on:
- **iOS** — iPhone 17 Pro / iOS 26.2 with Maestro 2.5.0 (dev build)
- **Android** — emulator with Maestro 2.5.0 (dev build)

- **Android + Expo Go** — dev-build path is exercised; the Expo Go deep-link path on Android has not been run end-to-end. Use a dev build for Android until that path is validated.
- **Expo Go popovers** — first-launch prompts can require manual taps. Dev build avoids this.
- **macOS only** — iOS simulator is macOS-exclusive. Linux/Windows Android-only setups would work in principle but are not tested.

## Documentation

- [`skills/harbormaster/SKILL.md`](./skills/harbormaster/SKILL.md) — runtime orchestration logic
- [`references/writing-flows.md`](./references/writing-flows.md) — Maestro YAML cheat sheet + RN patterns
- [`references/authoring-flows.md`](./references/authoring-flows.md) — phased authoring loop
- [`references/building-suites.md`](./references/building-suites.md) — `/buildsuite` depth doc
- [`references/troubleshooting.md`](./references/troubleshooting.md) — common failures and fixes
- [`CHANGELOG.md`](./CHANGELOG.md) — release history

## Support

- **Issues & feature requests:** [github.com/ConnectivityChris/harbormaster/issues](https://github.com/ConnectivityChris/harbormaster/issues)
- **Source:** [github.com/ConnectivityChris/harbormaster](https://github.com/ConnectivityChris/harbormaster)

## License

MIT — see [LICENSE](./LICENSE).
