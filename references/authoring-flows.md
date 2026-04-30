# Authoring Maestro flows

How to take a project from "no `.maestro/`" to a stable, committed flow that the next contributor can read, extend, and trust. This is the **process guide**. For Maestro YAML syntax, see `writing-flows.md`. For debugging failures, see `troubleshooting.md`.

The skill exposes four slash commands for the lifecycle:

| Command | When | Phase |
|---|---|---|
| `/initflow` | Once per project, no `.maestro/` exists yet | Init (scaffold) |
| `/buildsuite` | After init, when you want a working suite of flows fast | One guided tour → N flows authored sequentially with per-flow checkpoints |
| `/authorflow` | Per new flow, after init | Phases A–F (the loop below) |
| `/stabiliseflow` | After authoring, before committing as a release-gate smoke | Repeated execution |

For `/buildsuite` — the multi-flow tour-then-author lifecycle — see `building-suites.md`. It reuses the project-discovery logic below (Phase 1 of `/buildsuite`) and the per-flow Compose/Run/Commit conventions from `/authorflow` (Phase 4 of `/buildsuite`).

## Project discovery (shared)

Used by `/initflow` for one-time scaffolding and `/buildsuite` for tour-time candidate enumeration. Project-wide; for per-flow discovery during `/authorflow` see "Phase A — Discover" below.

### Reading the project

Read these files (in order, stop early if you have enough signal):

- `app.json` / `app.config.js|ts` — bundleId / package, app name
- `package.json` — dependencies (auth detection, RN/Expo version)
- Route directory — `app/` (Expo Router) or `screens/` (classic) — top-level routes hint at flow candidates

Build a candidate list. Common ones:
- `app-launch` — always
- `login` — only if auth detected
- Per top-level route (home, settings, etc.) — usually `view-list` or similar

### Auth detection

Conservative grep — only these signals count, no whole-codebase regex:

| Signal | Match in |
|---|---|
| `expo-secure-store`, `expo-auth-session`, `@react-native-async-storage/async-storage` | `package.json` deps |
| `useAuth`, `AuthContext`, `AuthProvider` | route/screen file *names* (not contents) |
| Files named `login`, `signin`, `signup`, `auth`, `(auth)` (route group) | route/screen directory |

Two or more signals = scaffold `login.yaml`. One signal = ask the user. Zero = skip.

## Init phase (`/initflow`)

One-time bootstrap. Refuse to re-run if `.maestro/` already exists.

### 1. Discover and detect auth

See [Project discovery (shared)](#project-discovery-shared) above. After running discovery, build a candidate flow list. Common ones:

- `app-launch` — always
- `login` — only if auth detected
- Per top-level route (home, settings, etc.) — usually `view-list` or similar

### 2. Confirm and scaffold

Use `AskUserQuestion` to confirm:
- Detected `bundleId` / `package` (let user correct)
- Which starter flows to scaffold (default: all that apply)
- iOS preferred device, if a sim is currently booted

Write to `<project>/.maestro/`:
- `config.json` — **skill's** config (bundleId, devBuildPath, preferredDevice). Populated from discovered values.
- `config.yaml` — **Maestro workspace** config. Copy from `references/flow-examples/config.yaml`. Maestro reads this when running `maestro test .maestro/`; it controls flow discovery, ordering, and tag filters. Note: `config.json` (skill) and `config.yaml` (Maestro) are two different files with overlapping names — both belong here.
- `README.md` — copy from `references/maestro-readme-template.md`, substitute project values
- `app-launch.yaml` — copy from `references/flow-examples/app-launch.yaml`, substitute `appId`
- `login.yaml` — only if auth confirmed

Append to `<project>/.gitignore` (or create if absent):
```
.maestro/artifacts/
.maestro/authoring-evidence/
.maestro/.tour-plan.json
.maestro/.tour-plan.archive.json
```

### 3. Hand off

Tell the user the scaffolded flows are stubs — selectors point at common labels but probably don't match their app's actual UI yet. Recommend invoking `/authorflow app-launch` to walk through customising the first one.

## Phased authoring loop (`/authorflow`)

Six phases. Each builds on the previous; don't skip.

### Phase A — Discover

The skill has prior context from init, but a per-flow refresh is useful. Read:
- existing flows in `<project>/.maestro/` — the new flow may need to chain via `runFlow`
- the project's screen file relevant to the requested flow (e.g. for `/authorflow login`, read the login screen component)
- `<project>/.maestro/README.md` — see what's already covered, avoid duplication

If `.maestro/` doesn't exist, stop and tell the user to run `/initflow` first.

### Phase B — Interview

Use `AskUserQuestion` to elicit:

1. **The journey, in plain English.** "User opens app → taps Login → enters creds → lands on home → taps a conversation → sees messages."
2. **Start state.** Logged out? Specific data needed? `clearState`?
3. **Success criterion.** What proves the flow worked? A screen visible? A specific text? An item count?

Don't accept handwaves. If the user says "the login flow," push back: which login? Email/password? OAuth? Magic link? The interview's purpose is to make implicit assumptions explicit *before* writing YAML.

Question budget is intentionally open for now — favour clarity over brevity. We'll cap based on user feedback.

### Phase C — Walk the screens

The most important phase. The booted sim/emulator must be ready — if not, run `${CLAUDE_PLUGIN_ROOT}/scripts/preflight.sh` and `${CLAUDE_PLUGIN_ROOT}/scripts/boot-sims.sh` first.

For each step in the user's journey:

1. **Drive the app to the relevant screen.** Either ask the user to tap manually (initial steps), or extend the flow YAML you're building so far and run it (later steps, once you have a stable starting point).

2. **Take ONE screenshot** for visual confirmation:
   ```bash
   # iOS
   xcrun simctl io booted screenshot <project>/.maestro/authoring-evidence/<flow>/<step>.png
   # Android
   adb exec-out screencap -p > <project>/.maestro/authoring-evidence/<flow>/<step>.png
   ```
   Naming: `<step-number>-<screen-name>.png`, e.g. `01-login-screen.png`, `02-home-after-login.png`. These persist as evidence for future debugging — gitignored by default but kept on disk.

3. **Dump the hierarchy** for selector picking — text, cheap, grep-able:
   ```bash
   maestro --device <udid-or-serial> hierarchy \
     | jq '.. | objects | {text, "resource-id", "accessibility-label", enabled} | select(.text or ."resource-id" or ."accessibility-label")'
   ```

4. **Pick the most stable selector.** Priority order:
   - `testID` (RN — see `writing-flows.md` for the `accessible={false}` container fix when testIDs are missing)
   - `accessibilityLabel` / `accessibility-label`
   - text (regex if the app uses RN's combined `accessibilityText` — see `writing-flows.md`)
   - coordinates — never. If you reach for them, the flow is broken by design.

5. **Record the choice.** Annotate the eventual YAML step with a short comment: `# email_input testID — wrapped in <View accessible> to escape parent's accessibility container`.

### Phase D — Compose

Write `<project>/.maestro/<flow-name>.yaml`. Conventions:

- `appId: ${APP_ID}` parameterised — same flow runs against dev build, Expo Go, store builds with different env values.
- Header comment block: 3-5 lines naming the journey, the start state, and any env vars the flow needs.
- Per-step comment: name the screen + user's intent + selector reasoning if non-obvious.
- Use the patterns from `references/flow-examples/` (state reset, button-vanish handling, regex text matching) when relevant.

Example header block:
```yaml
appId: ${APP_ID}
tags:
  - smoke
---
# Journey: user opens app, logs in with email+password, lands on home, taps a conversation
# Start state: logged out, clean install
# Env vars: MAESTRO_USERNAME, MAESTRO_PASSWORD, PROJECT_URL (Expo Go only), HOME_SCREEN_TEXT

- runFlow:
    when:
      platform: iOS
    commands:
      - clearKeychain
- launchApp:
    clearState: true
# clearKeychain is iOS-only; gating it keeps Android runs warning-free.
# launchApp clearState: true wipes the app data dir on both platforms,
# which on Android also clears SharedPreferences / EncryptedSharedPreferences
# (where most RN credential libraries land tokens).
# ...
```

### Phase E — Run once

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/run-flows.sh \
  --flows <project>/.maestro/<flow-name>.yaml \
  --platform <ios|android|both> \
  --env MAESTRO_USERNAME=... \
  --env MAESTRO_PASSWORD=...
```

**One-run stability bar.** If it passes, the flow ships. If it fails, drop into the Tier 0/1/2 debug protocol from `troubleshooting.md`:

- Tier 0 — read `run.log` and `report.xml`. Most failures resolve here.
- Tier 1 — `maestro hierarchy` to inspect live state.
- Tier 2 — open the screenshot at the failure point.

Iterate the YAML, re-run, repeat until green. Do **not** require multiple consecutive passes here — if the user wants stability verification, they'll invoke `/stabiliseflow` separately.

### Phase F — Commit + index

Two writes:

1. **The flow file** — already written in Phase D, run-verified in Phase E.
2. **`<project>/.maestro/README.md` update** — append an entry under "Covered flows":
   ```markdown
   ### login.yaml
   - **Journey**: opens app → email+password login → lands on home → taps first conversation
   - **Tags**: `smoke`, `auth`
   - **Env**: `MAESTRO_USERNAME`, `MAESTRO_PASSWORD`, `HOME_SCREEN_TEXT`
   - **Gotchas**: this app's submit button transitions to a spinner mid-submit; tap is wrapped in `runFlow: when: visible:` to handle the race
   ```

Then tell the user:
- The flow is in `.maestro/` and passed once. Commit when ready.
- Recommend `/stabiliseflow <flow>` before relying on it as a release gate.
- The README is the onboarding doc for the next contributor — keep it current as flows change.

## Stabilisation (`/stabiliseflow`)

Default 3 consecutive runs, configurable. See `commands/stabiliseflow.md` for the full procedure. Two outcomes:

- **All N passed**: flow is stable across the bar. Report duration spread. Safe to use as a release-gate smoke flow.
- **Some failed**: diagnose the flakiness — common causes are timing races, missing waits, shared device state. Don't just rerun until it passes — that hides flakiness, doesn't fix it. Apply the Tier 0/1 protocol and propose YAML fixes.

## Editing existing flows

Editing is closer to debugging than authoring. The phased loop is overkill — instead:

1. Identify what changed in the app (screen rename, new dialog, removed step, etc.).
2. Run the flow as-is to capture the failure (Tier 0).
3. Inspect with `maestro hierarchy` (Tier 1).
4. Patch the YAML.
5. Run once to verify.

If the change is structural (e.g. a whole new screen inserted into the journey), it may be cleaner to re-author with `/authorflow` rather than patch in place.
