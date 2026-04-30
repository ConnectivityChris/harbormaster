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
  - `dev-build` — a built `.app` (iOS sim) or `.apk` (Android). **Recommended default for regression suites.** No Expo Go overlays, no dev menu interruptions, no extra cold-reload tax. Slower first build, but cleaner steady-state.
  - `expo-go` — Expo Go installed, dev server running, deep-link to project. **Inner-loop only.** Expo Go can pop up dev tools / "What's new" / network-permission dialogs that block flows and require manual user input — fine for quick "did I break the launch?" checks, **not** suitable for a hands-off pre-release smoke run.
  - `installed` — app already installed; skip the install step.
- **Bundle ID / Android package**: from project config or ask once.

If the user is testing **before pushing a build to TestFlight / App Store / Play Store** (the primary use case for this skill), default to **dev build**. Only fall back to Expo Go when the user explicitly chooses speed over reliability or asks for it.

If the project has `<project>/.maestro/config.json`, read it for these defaults rather than asking. See [Project configuration](#project-configuration) below.

### 3. Choose the target device

Don't assume a default device — let the user pick. Run `${CLAUDE_PLUGIN_ROOT}/scripts/list-devices.sh <ios|android|both>` to enumerate available iOS simulators and Android AVDs, then present them to the user via `AskUserQuestion`.

Selection rules:
- If the project config has `ios.preferredDevice` (matched by simulator name) or `android.preferredAvd`, use that and skip the prompt — but still mention which device was picked so the user can override.
- If a single sim is already booted (or a single emulator is already running), use that and skip the prompt — switching mid-session adds friction for no benefit.
- Otherwise prompt with the list. iOS options show `<name> — <runtime>` (e.g. `iPhone 17 Pro — iOS 26.2`); Android options show the AVD name. Pre-select the most recent runtime / first AVD as the recommended default.

Capture the chosen `<udid>` (iOS) or `<avd-name>` (Android) and pass it to the next step. Optionally offer to write the choice into `<project>/.maestro/config.json` as `preferredDevice` / `preferredAvd` so the prompt is skipped on future runs.

### 4. Boot the chosen device(s)

Run `${CLAUDE_PLUGIN_ROOT}/scripts/boot-sims.sh <ios|android|both> [--ios-udid <udid>] [--avd <name>]`. This:

- Boots the specified iPhone simulator (or skips if already booted)
- Starts the specified Android emulator (or skips if already running)
- Waits for `boot_completed` before returning

### 5. Install the app

Run `${CLAUDE_PLUGIN_ROOT}/scripts/install-app.sh --platform <p> --source <s> [--path <p>] [--url <u>]`.

For Expo Go, the script uses `xcrun simctl openurl` (iOS) or `adb shell am start` (Android) to deep-link into the running dev server.

### 6. Handle credentials (if flows need login)

**This skill never stores credentials.** Anything sensitive lives only in the user's environment for the duration of the run.

If a flow file references `${USERNAME}`, `${PASSWORD}`, or any other secret env var:

1. **First, check the shell environment** — if the variable is already set (e.g. the user pre-exported it or uses `direnv`), use it as-is and don't prompt. Read with `printenv NAME`; do not log the value.
2. **If not set, prompt the user** via `AskUserQuestion` for each missing value. State explicitly: "I won't store this — it's used only for this run."
3. **Pass the values through to Maestro via `--env KEY=VALUE`** for this invocation. Do not write them to disk, do not echo them in logs, do not include them in error reports.
4. **Do not offer to "remember"** the values. Do not write a `.env` file. Do not call any keychain command.

If a user wants persistent creds, they manage that themselves outside the skill — for example by exporting in their shell rc file or using `direnv` with a gitignored `.envrc`. The skill stays out of that boundary entirely.

### 7. Run flows

Run `${CLAUDE_PLUGIN_ROOT}/scripts/run-flows.sh --flows <path> --platform <p> [--env KEY=VAL ...]`.

The flows path is typically `<project>/.maestro/` — a directory of `.yaml` files Maestro will run in alphabetical order. The script:

- Targets the booted iOS sim and/or Android emulator (uses `--device` when both are running)
- Captures screenshots, video, and a JUnit XML report under `<project>/.maestro/artifacts/<run-id>/`
- Returns non-zero if any flow fails

### 8. Report

Summarise pass/fail per flow per platform. **On failure, diagnose in tiers — cheapest first. Do not jump straight to screenshots; they are the most token-expensive tool and rarely needed first.**

**Tier 0 — Maestro's own output (read every time):**
- Last ~30 lines of `artifacts/<run-id>/<platform>/run.log` — Maestro names the failed step and the selector it couldn't match
- The matching JUnit entry in `report.xml`

Most failures (selector typos, missing waits, behaviour changes) resolve here. Stop if Tier 0 is enough.

**Tier 1 — live UI hierarchy (on demand, only if Tier 0 isn't enough):**
- The booted device is still running after a flow fails. Invoke `maestro hierarchy` inline to inspect the current screen state — text, ids, resource-ids, enabled state — without re-running the flow.
- For iOS: `maestro --device <udid> hierarchy`. For Android: `maestro --device <serial> hierarchy`. Pipe through `jq` to keep only the fields you need (e.g. `jq '.. | objects | {text, "resource-id", "accessibility-label", enabled} | select(.text or ."resource-id" or ."accessibility-label")'`) — raw hierarchy on a busy RN screen can exceed 5k tokens.
- Use this to answer: does the selector exist at all? Is it disabled? Is it under a different id than the flow assumes? Did the screen even render?

**Tier 2 — screenshot at failure point (only if Tier 0 + Tier 1 don't explain it):**
- Read `artifacts/<run-id>/<platform>/screenshot-*.png` only when the question is visual: layout overlap, unexpected dialog, dark/empty render, animation state. Each image costs ~1.5k tokens — load deliberately.

**Tier 3 — video (suggest to the user, do not load yourself):**
- For non-deterministic / timing failures, point the user at `artifacts/<run-id>/<platform>/*.mp4`. Don't try to consume it.

After diagnosis, suggest the likely cause (element not found → selector wrong or screen not loaded; timeout → app slow / wrong screen; assertion failed → behaviour changed) and the specific fix.

Do NOT just say "tests failed, here's the log." Diagnose.

This tiering applies to **debugging failures**. When **authoring** a new flow, use whatever you need (including screenshots) to get the flow correct first — optimise later.

## Authoring flows

The skill ships four slash commands that cover the flow lifecycle. Use these as the entry points; do not reinvent the loop ad-hoc.

| Command | When to use | What it does |
|---|---|---|
| `/initflow` | Project has no `.maestro/` directory yet | One-time bootstrap — discovers the project, detects auth, scaffolds `.maestro/{config.json, README.md, app-launch.yaml, login.yaml?}` with the project's actual `appId` substituted in |
| `/buildsuite` | After `/initflow`, when you want a real suite of flows fast | Guided tour — walks the running app once with the user, builds a shared selector + screen plan in `.tour-plan.json`, then loops over each planned flow with a per-flow checkpoint to compose, run, and commit. Reuses Phase D-F of `/authorflow` and the Tier 0/1/2 debug ladder for failed runs |
| `/authorflow [flow-name]` | After init, adding a new flow | Phased loop — Discover → Interview → Walk-the-screens (one screenshot + `maestro hierarchy` per step) → Compose → Run once → Commit + update `.maestro/README.md` |
| `/stabiliseflow <flow> [N]` | Before relying on a flow as a release-gate smoke | Runs the flow N times consecutively (default 3), reports flake rate, diagnoses non-deterministic failures |

The full process — phase definitions, auth-detection grep patterns, selector-priority order, screenshot/hierarchy capture commands, README template — lives in `references/authoring-flows.md`. **Read it before authoring**, do not improvise.

For `/buildsuite` specifically, the depth doc is `references/building-suites.md` — five phases (Discover & confirm → Guided tour → Plan materialisation → Authoring loop → Index & report), the `.tour-plan.json` schema, the coverage-checklist UX, and the edge cases. Read it before invoking the command. `/buildsuite` shares project-discovery logic with `/initflow` (extracted under "Project discovery (shared)" in `authoring-flows.md`) and reuses Phase D-F conventions from `/authorflow` for the per-flow deep dives.

### Stability bar

`/authorflow` ships with a **one-run stability bar** — if a freshly-authored flow passes once, it ships. Multi-run stability is a separate explicit step (`/stabiliseflow`). Rationale: one-run is fast for the inner-loop case; users who want release-gate confidence opt into the bar by running stabilise. Don't impose multi-run requirements during authoring.

### Authoring evidence

Phase C of `/authorflow` captures one screenshot per step into `<project>/.maestro/authoring-evidence/<flow>/`. These are gitignored but persisted on disk — useful when a flow breaks months later and someone wonders what the screen used to look like. Don't delete them at the end of authoring.

### Tour plan

`/buildsuite` writes its working plan to `<project>/.maestro/.tour-plan.json` between Phase 3 and Phase 5. The file is the persistence boundary for tour-derived data — once written, the user can quit and resume in a new session via `/buildsuite` (which detects an unfinished plan and offers to resume). On successful Phase 5 completion the plan is moved to `.tour-plan.archive.json` so a future invocation starts clean. Both files are gitignored. Schema in `references/building-suites.md` → "Plan schema".

### Selector priority (recap)

Across all four commands, when picking selectors:

1. `testID` (RN: see `references/writing-flows.md` for the `accessible={false}` container pattern when testIDs are missing from `maestro hierarchy`)
2. `accessibilityLabel`
3. text (regex if the app uses RN's bundled `accessibilityText`)
4. **Never coordinates.** If the only selector you can get is a coordinate, the screen is missing accessibility support and the *app* needs a fix, not the flow.

For Maestro YAML syntax (commands, env vars, `runFlow`, retry, conditional logic), see `references/writing-flows.md`.

## Project configuration

Two config files live under `<project>/.maestro/`, with overlapping names but different owners:

- **`config.json`** — read by **this skill**. Holds skill-level defaults (bundleId, dev-build paths, preferred device, Expo Go URL). Schema below.
- **`config.yaml`** — read by **Maestro itself** when you invoke `maestro test`. Workspace-level controls: flow discovery, `executionOrder`, tag filters, `onFlowStart`/`onFlowComplete` hooks. Template at `references/flow-examples/config.yaml`. `/initflow` scaffolds it; the skill does not otherwise touch it at runtime.

If the project has `<project>/.maestro/config.json`, read it for defaults:

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
  },
  "flowsDir": ".maestro"
}
```

If the file is missing, prompt for the values you need and offer to write the config so the user doesn't have to re-answer next time.

## Troubleshooting

Common failure modes and fixes:

- **"Simulator won't boot"** → check Xcode is installed (not just CLI tools); try `xcrun simctl shutdown all && xcrun simctl erase all` to reset state
- **"Maestro can't find element"** → run `maestro --device <udid-or-serial> hierarchy` to inspect the live accessibility tree, prefer text or accessibility-label selectors
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
- `references/flow-examples/login.yaml` — log in using env-supplied creds (never stored)
- `references/flow-examples/view-list.yaml` — navigate into a list and verify items render
