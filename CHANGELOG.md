# Changelog

All notable changes to mobile-flow-runner will be documented in this file. The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project follows [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [0.2.1] — 2026-04-29

### Fixed
- Plugin install error `Path escapes plugin directory: ./ (skills)` — `SKILL.md` moved from plugin root to `skills/mobile-flow-runner/SKILL.md`, matching the current Claude Code plugin loader's expected layout. `plugin.json` `skills` field now points at the subdirectory rather than `./`.

## [0.2.0] — 2026-04-29

### Added
- Three slash commands wrapping the flow lifecycle:
  - `/initflow` — one-time project bootstrap; discovers screens, grep-detects auth, scaffolds `.maestro/{config.json, README.md, app-launch.yaml, login.yaml?}` with project values substituted
  - `/authorflow [flow-name]` — phased loop (Discover → Interview → Walk-the-screens → Compose → Run once → Commit + index README); captures one screenshot + `maestro hierarchy` per step; **one-run stability bar**
  - `/stabiliseflow <flow> [N]` — runs an existing flow N times consecutively (default 3) to detect flakiness; diagnoses non-deterministic failures rather than blindly rerunning
- `references/authoring-flows.md` — process guide for the phased authoring loop (separate from `writing-flows.md` which remains the syntax reference)
- `references/maestro-readme-template.md` — fixed onboarding-doc template for `<project>/.maestro/README.md`
- `<project>/.maestro/authoring-evidence/<flow>/` — gitignored directory for Phase C screenshots, persisted as future debugging evidence

### Changed
- `SKILL.md` "Authoring flows" section rewritten to point at the three slash commands and the new authoring reference; the four-step ad-hoc pattern is removed in favour of the phased loop
- Token-efficient debug tiering documented in `SKILL.md` step 8 and `references/troubleshooting.md`: Tier 0 logs → Tier 1 `maestro hierarchy` → Tier 2 screenshot → Tier 3 video, in that order
- `maestro studio` repositioned as user-only (interactive browser inspector); Claude defaults to `maestro hierarchy` for selector inspection

## [0.1.0] — 2026-04-29

Initial release. End-to-end validated against an Expo SDK 55 project on iOS 26.2 simulator with Maestro 2.5.0, running both `app-launch` and `login` smoke flows.

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

[Unreleased]: https://github.com/ConnectivityChris/mobile-flow-runner/compare/v0.2.1...HEAD
[0.2.1]: https://github.com/ConnectivityChris/mobile-flow-runner/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/ConnectivityChris/mobile-flow-runner/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/ConnectivityChris/mobile-flow-runner/releases/tag/v0.1.0
