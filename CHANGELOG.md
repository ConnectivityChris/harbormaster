# Changelog

All notable changes to mobile-flow-runner will be documented in this file. The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project follows [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [0.1.0] — 2026-04-29

Initial release. End-to-end validated against happi (Expo SDK 55, iOS 26.2 simulator, Maestro 2.5.0) running both `app-launch` and `login` smoke flows.

### Added
- `mobile-flow-runner` skill (`SKILL.md`) — orchestrates preflight, device picker, sim/emulator boot, app install, flow execution, and result reporting
- Orchestration scripts:
  - `preflight.sh` — verify Xcode, Maestro, Android SDK
  - `list-devices.sh` — enumerate iOS sims and Android AVDs for picker UX
  - `boot-sims.sh` — boot the chosen device(s) and wait for ready
  - `install-app.sh` — install dev build (`.app` / `.apk`) or deep-link Expo Go; detects missing Expo Go and surfaces recovery instructions
  - `run-flows.sh` — run Maestro against booted devices, capture artifacts (screenshots, video, JUnit XML)
- Reference documentation:
  - `references/writing-flows.md` — Maestro YAML cheat sheet plus RN-specific guidance (testID forwarding via `<View accessible>`, `accessibilityText` bundling, button-disappears-on-spinner race, Expo Go state-leak workarounds)
  - `references/ios-setup.md` — Xcode + simulator runtime setup
  - `references/android-setup.md` — Android SDK + AVD setup
  - `references/troubleshooting.md` — common errors and fixes
- Starter flow examples in `references/flow-examples/`:
  - `app-launch.yaml`
  - `login.yaml` (with full state reset and optional submit-tap pattern)
  - `view-list.yaml`
- Marketplace catalog (`.claude-plugin/marketplace.json`) so the plugin is installable via `/plugin marketplace add ConnectivityChris/mobile-flow-runner`

### Design decisions baked in
- **Credentials never persisted by the skill** — env-only, prompt-per-run; no Keychain integration, no `.env` writes
- **Dev build over Expo Go** for regression suites — Expo Go's dev menus and popovers are documented as inner-loop only
- **ASCII-only script output** — bash `set -u` misparses unicode glyphs adjacent to variable expansions

[Unreleased]: https://github.com/ConnectivityChris/mobile-flow-runner/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/ConnectivityChris/mobile-flow-runner/releases/tag/v0.1.0
