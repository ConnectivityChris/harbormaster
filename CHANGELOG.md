# Changelog

All notable changes to harbormaster (formerly `mobile-flow-runner`) will be documented in this file. The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project follows [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [0.5.1] — 2026-05-01

### Documentation
- **`scripts/preflight.sh` failure-path guidance hardened.** Every Android warning (`adb` missing, `ANDROID_HOME` unset, `emulator` missing, no AVDs configured) now prints a concrete `Fix:` command plus a `See: references/android-setup.md` pointer; `ANDROID_HOME` previously had no `Fix:` line at all. iOS warnings gained `See: references/ios-setup.md`. Xcode warning now includes the App Store URL inline. Maestro install branch now references the official install docs URL alongside the existing curl + brew commands. No behaviour change to exit codes or success path — purely additive guidance on the failure paths.
- **`README.md` Prerequisites section now links its own setup docs and inlines the Maestro install commands** (curl + brew), so users hitting an install gap don't have to run preflight first to discover the fix. Each prerequisite now links to its source (Xcode App Store, Maestro docs, Android Studio download) and to the relevant `references/*-setup.md`.
- **`references/ios-setup.md` and `references/android-setup.md`** — linked "Mac App Store" and "Android Studio" inline to their official download pages.

## [0.5.0] — 2026-05-01

### Added
- **Android-only setups now supported.** `scripts/preflight.sh` previously hard-required iOS (Xcode + simulator); it now succeeds if at least one of iOS or Android is fully usable. The script's final line reads `Platforms usable: iOS + Android`, `iOS only`, or `Android only` so downstream steps can constrain themselves. Maestro is the only universally required tool.
- **Cross-platform-safe state reset in flow templates.** `references/flow-examples/login.yaml`, `references/writing-flows.md`, and `references/authoring-flows.md` now gate `clearKeychain` behind `runFlow: when: platform: iOS` so Android runs are warning-free; `launchApp clearState: true` handles Android session reset (clears SharedPreferences / Room / SQLite / EncryptedSharedPreferences — where RN credential libraries land tokens on Android). Documents the rare edge case (raw Android Keystore aliases that survive `clearState`).

### Changed
- **`scripts/boot-sims.sh` aligned with `scripts/run-flows.sh` for `--platform both`.** Previously `boot_ios && boot_android` short-circuited the Android boot if iOS failed; now both attempt independently and the script exits with the union of failures, matching `run-flows.sh`'s design. Switched `set -eu` → `set -u` so failures surface via explicit return-code checks.
- **`scripts/boot-sims.sh` Android boot loop now bounded.** A 180-second timeout plus emulator-process liveness check replaces the previous unbounded `while sys.boot_completed != 1` loop — a crashed AVD can no longer hang the script indefinitely.
- **`skills/harbormaster/SKILL.md` preflight contract + platform defaults updated.** Step 1 documents the `Platforms usable: …` line and the new exit-0-on-either-platform contract. Step 2 platform default rules now key off the preflight verdict (`iOS + Android` → `both`, `iOS only` → `ios`, `Android only` → `android`) so the skill doesn't silently default to a platform that will fail at boot.
- **`skills/harbormaster/SKILL.md` `--platform both` orchestration tightened.** Step 3 (device picker) now explicitly handles "one of each" selection when both platforms are requested. Step 5 (install) documents the per-platform invocation loop required for `--platform both` and warns that Expo Go's per-platform bundle ID divergence (`host.exp.Exponent` vs `host.exp.exponent`) makes it incompatible with a single `--env APP_ID=…` value — recommends dev builds for `both` runs.

### Fixed
- **`scripts/run-flows.sh` no longer crashes with `TAG_ARGS[@]: unbound variable`** when invoked without `--include-tags` or `--env` flags. The `${arr[@]}` syntax errors under `/bin/bash` 3.2 (macOS system bash) + `set -u` for empty arrays; replaced with the `${arr[@]+"${arr[@]}"}` idiom at all four call sites in the `maestro test` invocation. Bug surfaced during dogfooding.

### Repository hygiene
- `.gitignore` now excludes `/*.png` at repo root — guards against Maestro's `takeScreenshot:` step accidentally depositing screenshots in the repo when bench-running flows from this directory.
- `SPIKES.md` parallel-sharding entry replaced with a parked summary preserving the bench numbers (176 s sequential → 104 s sharded, 40 % improvement) and Q1/Q2/Q4 findings. Sequential implementation remains; the spike documents why parking is justified at current usage and what would need to change if it's revived.

## [0.4.0] — 2026-04-30

### Changed
- **Plugin renamed from `mobile-flow-runner` to `harbormaster`.** New install handle: `/plugin install harbormaster@connectivity`. The plugin's responsibilities, slash commands (`/initflow`, `/buildsuite`, `/authorflow`, `/stabiliseflow`), scripts, and references are unchanged — this is purely a name migration.
- **Marketplace renamed from `connectivity-chris` to `connectivity`** in the same release; the `-chris` suffix was redundant once the `owner` field already credits the maintainer. Both renames land together so users only have to migrate once.
- GitHub repository moved to `ConnectivityChris/harbormaster`. The old `mobile-flow-runner` URL redirects via GitHub for cloned-repo discovery, but pinned marketplace installs against `ConnectivityChris/mobile-flow-runner@vX.Y.Z` should be updated.
- `skills/mobile-flow-runner/` → `skills/harbormaster/` (with `git mv` so history follows).
- `plugin.json` `name`, `repository`, and `skills` paths updated to reflect the new identity.
- `marketplace.json` plugin entry renamed.
- README, CLAUDE.md, command files, scripts, and the project README template updated to use the new name. Historical CHANGELOG entries (v0.3.0 and earlier) intentionally retain the old name — they describe what shipped at the time.
- JUnit `--test-suite-name` prefix in `scripts/run-flows.sh` updated from `mobile-flow-runner-…` to `harbormaster-…`.

### Migration notes
For existing users with the plugin pinned to a `mobile-flow-runner` version: remove the old install (`/plugin uninstall mobile-flow-runner@connectivity-chris`) and re-add via the new handle (`/plugin marketplace add ConnectivityChris/harbormaster && /plugin install harbormaster@connectivity`). Project-level `.maestro/` directories created by `/initflow` are unaffected — they don't reference the plugin name.

## [0.3.0] — 2026-04-30

### Added
- `/buildsuite` slash command — fourth lifecycle command for building a core suite of flows in a single session. Walks the running app once with the user (a guided tour), builds a shared selector + screen plan persisted to `<project>/.maestro/.tour-plan.json`, then loops over each planned flow with a per-flow `[yes / skip / stop]` checkpoint to compose, run, and commit. Reuses `/initflow`'s project-discovery logic and `/authorflow`'s Phase D-F conventions. Depth doc in `references/building-suites.md`.
- `references/building-suites.md` — depth doc for `/buildsuite` (five phases, plan schema, coverage-checklist UX, edge cases).

### Changed
- `references/authoring-flows.md` — extracted a shared "Project discovery (shared)" section, now reused by both `/initflow` and `/buildsuite` (refactor; meaning preserved).
- `/initflow` now writes `.maestro/.tour-plan.json` and `.maestro/.tour-plan.archive.json` to the project's `.gitignore` alongside the existing `artifacts/` and `authoring-evidence/` entries.
- `references/maestro-readme-template.md` — project READMEs scaffolded by `/initflow` now reference `/buildsuite` and the `.tour-plan.json` artefact.
- `README.md` and `skills/mobile-flow-runner/SKILL.md` — refreshed lifecycle docs to describe four slash commands instead of three.

## [0.2.2] — 2026-04-30

### Fixed
- `scripts/run-flows.sh` now passes `--debug-output` and `--flatten-debug-output` so screenshots, video, and the `run.log` actually land in `<project>/.maestro/artifacts/<run-id>/<platform>/` — previously only `report.xml` was written there while screenshots/recordings went to Maestro's default location, contradicting the docs.
- `--format junit` upgraded to canonical `--format JUNIT` (uppercase) per Maestro CLI help.
- Selector priority in `references/writing-flows.md` corrected to `testID > accessibilityLabel > text > coords`. Previous wording inverted the order, contradicting `SKILL.md` and Maestro's own guidance.
- `references/flow-examples/app-launch.yaml` defaults to `launchApp: { clearState: true }` (the regression-suite path) rather than `openLink: ${PROJECT_URL}` (the Expo Go path). Users on native dev builds no longer need to mutate the starter flow.
- `references/flow-examples/view-list.yaml` now starts with `launchApp` so it can run standalone, and tags `navigation` in addition to `smoke`.
- `scripts/install-app.sh` accepts `--source installed` as a documented no-op, matching the SKILL.md decision tree.
- `scripts/boot-sims.sh` emits a `[warn]` line when falling back to a default UDID/AVD because no `--ios-udid` / `--avd` was passed.
- `jq` filter for `maestro hierarchy` now includes `accessibility-label`. Previous filter dropped iOS-only labels, hiding selector-priority #2 elements.
- README status bumped from v0.1.0 to v0.2.1; versioning section now documents both HEAD and tag-pinned install paths to match `CLAUDE.md`.

### Added
- `scripts/run-flows.sh` accepts `--include-tags` and `--exclude-tags`, surfacing Maestro's tag-filtering through the skill (flows already tag `smoke`/`auth`/`navigation`).
- `scripts/run-flows.sh` passes `--test-suite-name` so JUnit consumers see a meaningful suite identifier per platform per run.
- `references/flow-examples/config.yaml` — Maestro **workspace** config template. `/initflow` scaffolds it alongside the existing `config.json` (the **skill's** config). Two files with overlapping names but different owners; both belong under `<project>/.maestro/`.
- `SPIKES.md` — parked future-work that needs a real bench test (currently: parallel iOS+Android execution via `maestro --device a,b --shard-split 2`).

### Removed
- Stray references to CI / Maestro Cloud as recommended fallbacks. The plugin is local-only and shouldn't pretend otherwise.

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

[Unreleased]: https://github.com/ConnectivityChris/harbormaster/compare/v0.5.1...HEAD
[0.5.1]: https://github.com/ConnectivityChris/harbormaster/compare/v0.5.0...v0.5.1
[0.5.0]: https://github.com/ConnectivityChris/harbormaster/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/ConnectivityChris/harbormaster/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/ConnectivityChris/harbormaster/compare/v0.2.2...v0.3.0
[0.2.2]: https://github.com/ConnectivityChris/harbormaster/compare/v0.2.1...v0.2.2
[0.2.1]: https://github.com/ConnectivityChris/harbormaster/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/ConnectivityChris/harbormaster/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/ConnectivityChris/harbormaster/releases/tag/v0.1.0
