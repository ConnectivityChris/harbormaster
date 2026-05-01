# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A **Claude Code skill packaged as a plugin** that orchestrates [Maestro](https://maestro.mobile.dev) regression flows against iOS simulators and Android emulators. The "product" is the skill spec + bash orchestration scripts + reference docs — there is no compiled application, no test suite, no package manager.

Future agents working here are usually editing one of:
- the skill orchestration logic (`SKILL.md`)
- a slash command file in `commands/` (`initflow.md`, `buildsuite.md`, `authorflow.md`, `stabiliseflow.md`)
- one of the five bash scripts in `scripts/`
- a reference doc in `references/`
- a starter flow in `references/flow-examples/`
- plugin packaging metadata in `.claude-plugin/`

## Architecture (load order matters)

Claude executes this skill in roughly the order encoded in `SKILL.md`. Four layers, each with a different load model:

1. **`commands/*.md`** — slash command entry points (`/initflow`, `/buildsuite`, `/authorflow`, `/stabiliseflow`). Loaded only when the user types the slash command. Each is a thin routing layer: YAML frontmatter (description, argument-hint, allowed-tools) plus a markdown prompt that delegates to the relevant phase in `SKILL.md` + `references/authoring-flows.md`. **Do not duplicate skill logic into the command file** — keep it pointing at the references.
2. **`skills/harbormaster/SKILL.md`** — loaded into Claude's context when the skill triggers (either by natural-language prompt or via a slash command). Holds the **decision-making and orchestration logic**: when to ask the user something, what defaults to use, how to react to script failures. Section ordering reflects runtime order (preflight → target → device → boot → install → creds → run → report). The skill **must** live under `skills/<skill-name>/` — the Claude Code plugin loader rejects `SKILL.md` at plugin root with `Path escapes plugin directory: ./ (skills)` (introduced in 0.2.1, see CHANGELOG).
3. **`scripts/*.sh`** — invoked by Claude per `SKILL.md`. Each is single-purpose and side-effecting. Scripts only handle mechanics (boot the sim, install the app, run Maestro); they do not make user-facing decisions.
4. **`references/*.md`** — loaded on-demand by Claude when it needs deeper detail (Maestro YAML cheat sheet, RN-specific gotchas, platform setup, the phased authoring loop, the multi-flow suite-building loop). Treat as encyclopedic — `SKILL.md` and `commands/*.md` should *point at* references, not inline their content.

Scripts are addressed from `SKILL.md` as `${CLAUDE_PLUGIN_ROOT}/scripts/<name>.sh` — that env var is set by Claude Code when the plugin is loaded, so do not hard-code paths.

### Why four slash commands

The flow lifecycle has four distinct phases that need different behaviour: one-time project bootstrap, multi-flow suite building from a guided tour, per-flow authoring, and stability hardening. Each maps to one slash command. They are intentionally narrow — `/initflow` refuses to run if `.maestro/` exists; `/buildsuite` requires `.maestro/` and offers to resume an unfinished `.tour-plan.json` if one exists; `/authorflow` requires `.maestro/`; `/stabiliseflow` requires the named flow file to exist. Don't merge them. `/buildsuite` is the bulk-author path; `/authorflow` is the single-flow-at-a-time path — keep both, they cover different needs.

### Data flow at runtime

```
preflight.sh           → confirms env (Xcode, Maestro, Android SDK)
list-devices.sh        → enumerates sims/AVDs for picker UX
boot-sims.sh           → boots chosen device(s), waits for boot_completed
install-app.sh         → installs .app/.apk OR deep-links Expo Go
run-flows.sh           → runs Maestro, writes artifacts/<run-id>/{ios,android}/
```

Artifacts (screenshots, video, JUnit XML) land in `<project>/.maestro/artifacts/<run-id>/` by default — the user's project, not this repo. This repo's `.gitignore` excludes `.maestro/artifacts/` only because validation runs may produce them locally.

## Non-obvious constraints (read before editing)

These are the traps. Each was learned the hard way and is baked into the current code.

### Bash scripts must produce ASCII-only output

All scripts run with `set -u` (or `set -eu`). Bash with `set -u` **misparses unicode glyphs adjacent to variable expansions** in some terminal locales — flows have failed because a `✓` next to `${var}` was read as part of the expansion. Use ASCII status prefixes (`[ok]`, `[warn]`, `[err]`, `[*]`) and stick to them. `CHANGELOG.md` records this as a deliberate design decision, not a stylistic preference. **Do not add emoji or unicode glyphs to script output, even if it would look nicer.**

### Credentials are never persisted by the skill

This is a hard rule, not a default. The skill:
- reads from the shell environment if a needed var is already set (no prompt)
- prompts via `AskUserQuestion` only for missing values, with explicit "I won't store this"
- forwards values to Maestro via `--env KEY=VALUE` for the single invocation
- **never** writes `.env` files, calls keychain commands, or offers to "remember" anything

Persistent creds are the user's responsibility (shell rc, `direnv`, etc.). Do not add a "save credentials" feature even if it seems convenient — it's an explicit boundary the skill stays out of.

### Dev build is the regression default; Expo Go is inner-loop only

When deciding what to install, default to a native dev build (`bunx expo run:ios|:android`). Expo Go's dev menus, "What's new" popovers, network-permission prompts, and project-load dialogs **block flows mid-run** and require manual taps. They are not suppressible programmatically. `references/writing-flows.md` documents this and the workarounds for users who insist on Expo Go anyway. Do not change the default.

### React Native testID gotchas live in `references/writing-flows.md`

Two specific RN/iOS quirks that flow examples and selectors must respect:

1. **`testID` on `<TextInput>` is silently dropped** — RN bundles sibling `Text` into the parent's combined `accessibilityText`. Wrap inputs in `<View accessible testID="...">` to expose the testID as a discrete `resource-id`. The `login.yaml` example assumes this pattern.
2. **Buttons that swap children to a spinner mid-submit** can briefly drop their testID from the accessibility tree. Make the tap optional via `runFlow: when: visible: id: ...`, and assert on the *outcome* (post-login screen) rather than the *interaction*. Again, baked into `login.yaml`.

If you change the login flow or add new flows that touch buttons under transition, preserve these patterns.

### `install-app.sh` does not install Expo Go

Expo Go is distributed via the App Store and Expo's CLI, not as a standalone `.app`. If the script detects Expo Go is missing on the booted sim/emulator, it surfaces a recovery instruction telling the user to press `i`/`a` in their running `expo start` terminal. **Do not add a "download Expo Go" path** — there isn't a clean one.

## Validation workflow

There are no unit tests. Validation is end-to-end against a real mobile project.

### Local install for development

```bash
git clone git@github.com:ConnectivityChris/harbormaster.git ~/dev/harbormaster
claude --plugin-dir ~/dev/harbormaster
```

Then in Claude Code, prompt something like *"smoke test the iOS build"* and step through the skill end-to-end against a project with a `.maestro/` directory.

### Reference benchmark

Before tagging a release, re-run the `app-launch` and `login` smoke flows against an Expo project with a populated `.maestro/` directory. `CHANGELOG.md` records the env (Expo SDK, iOS runtime, Maestro version) used to validate each release — update it on the next release with whatever you tested against.

### Spot-checking individual scripts

Each script is invokable directly, useful when iterating on bash logic without bouncing through the full skill loop:

```bash
./scripts/preflight.sh
./scripts/list-devices.sh ios
./scripts/boot-sims.sh ios --ios-udid <UDID>
./scripts/install-app.sh --platform ios --source dev-build --path /path/to/Example.app
./scripts/run-flows.sh --flows /path/to/.maestro --platform ios --env MAESTRO_USERNAME=... --env MAESTRO_PASSWORD=...
```

`run-flows.sh` writes artifacts to `.maestro/artifacts/<run-id>/` relative to the **current working directory** unless `--output` is passed. Run it from inside the target project, not from this repo.

## Release process

This repo doubles as the marketplace for the plugin (`.claude-plugin/marketplace.json`).

**Every release MUST tag and push.** Untagged commits on `main` are not consumable by users who pin via `/plugin marketplace add ...@vX.Y.Z`, and an unpushed tag is invisible to the marketplace. Skipping either step ships a release that nobody can install at the version you claimed.

When cutting a new version, do all of the following — no shortcuts:

1. Bump `version` in `.claude-plugin/plugin.json`.
2. Move `[Unreleased]` items in `CHANGELOG.md` under a new `[X.Y.Z] — YYYY-MM-DD` header (Keep a Changelog format).
3. Update the comparison link footers at the bottom of `CHANGELOG.md`.
4. Commit the version bump (alongside the feature commits being released).
5. **Push `main`**: `git push origin main`.
6. **Tag and push the tag**: `git tag vX.Y.Z && git push origin vX.Y.Z`.
7. **Create the GitHub Release** so the changelog is discoverable in the GitHub UI and `release.published` webhooks fire. The body MUST be the matching CHANGELOG section verbatim — no hand-edits, no drift:
   ```bash
   body=$(awk -v ver="X.Y.Z" '
     $0 ~ "^## \\[" ver "\\]" { flag=1; next }
     flag && /^## \[/ { exit }
     flag && /^\[Unreleased\]:/ { exit }
     flag { print }
   ' CHANGELOG.md)
   gh release create vX.Y.Z --title "vX.Y.Z — YYYY-MM-DD" --notes "$body"
   ```
8. Verify with `gh release view vX.Y.Z`.

Keep `plugin.json` `version`, the `CHANGELOG.md` release header, the git tag, and the GitHub Release in lockstep — drift between them breaks `/plugin marketplace add ...@vX.Y.Z` pinning or misleads users browsing the repo. The CHANGELOG is the single source of truth for release notes; the GitHub Release body is sourced from it, never written independently.

**No version edit to `marketplace.json` is needed.** The marketplace catalog uses `source: "./"` which resolves to whatever ref the user pins; the tag IS the version. Editing `marketplace.json` per release is a sign you're misunderstanding the model — stop and re-check.

### Why this matters

Users install via `/plugin marketplace add ConnectivityChris/harbormaster@vX.Y.Z`. That resolution chain reads `marketplace.json` from the tag, then loads `plugin.json` and the rest of the plugin contents from that tag. If the tag doesn't exist, install fails. If `plugin.json` and the tag disagree on version, the user gets confusing diagnostics. If `main` is pushed but the tag isn't, the install command falls back to HEAD silently — users get unreleased code thinking they pinned a version.

## Conventions

- **Commit messages**: short conventional-commit form (`fix(plugin): ...`, `feat(commands): ...`). **Subject line only** — do not write a body unless the user explicitly asks. **Do not add `Co-Authored-By:` trailers** — user removes them.
- **UK English** in all committed text — `stabilise`, `behaviour`, `colour`, `prioritise`, etc. Slash command names follow this (`/stabiliseflow`, not `/stabilizeflow`).
- **Project-agnostic docs** — no references to specific external projects (e.g. real app names) in `SKILL.md`, `README.md`, `references/`, or `commands/`. CHANGELOG entries describing past validation environments may use generic descriptions ("Expo SDK 55 project on iOS 26.2") but never name the project.
- **Internal AI-dev artifacts stay local.** `docs/` and `SPIKES.md` are gitignored. Specs, plans, design notes, and spike write-ups belong on disk only — do not commit them. The canonical user-facing docs are `references/`. If a skill (e.g. superpowers `writing-plans`) wants to write a plan or spec file, write it under `docs/` so gitignore catches it.

## Editing guidance

- **Adding a new flow example**: keep it generic (no project-specific bundle IDs, no real user data). Use `${APP_ID}` for cross-platform parameterisation. Reference it from `SKILL.md`'s "Reference index" section so future Claude knows it exists.
- **Adding a new script**: maintain the `[ok]/[warn]/[err]/[*]` prefix convention. Take args via `--flag value` (long-form), not positional. Set `set -u` minimum, `set -eu` if any failure should halt — but `preflight.sh` deliberately uses `-u` only because it counts and reports multiple failures.
- **Modifying `SKILL.md`**: it controls what Claude does at runtime. Behaviour changes here propagate to every user. Do not inline content that already lives in `references/` — point at the reference instead, since references load on-demand and `SKILL.md` is loaded every invocation.
- **Editing references**: these are read on-demand by Claude during a skill run. The frontmatter on `SKILL.md` is what triggers the skill — references have no frontmatter and are not auto-loaded.
- **Editing `README.md`**: it's commercial-facing — keep contributor and maintainer content out (release process, source tree, local dev setup). Those live here in `CLAUDE.md`. The README answers "what is this, why should I use it, how do I install it, how stable is it" and nothing else.
- **Status / maturity claims** in `README.md` (validation env, "exercised on X", limitations) are easy to ship stale. Before editing or copy-forwarding any such claim, check the latest CHANGELOG entries or ask the user what's actually been run.
