# Building a flow suite

How to take a project from "scaffolded stubs from `/initflow`" to a committed core suite of working flows in a single guided session. This is the **process guide** for `/buildsuite`. For per-flow authoring (`/authorflow`) see `authoring-flows.md`. For Maestro YAML syntax see `writing-flows.md`. For debugging see `troubleshooting.md`.

## Lifecycle position

`/buildsuite` is the fourth lifecycle command, sitting between `/initflow` (one-time scaffold) and `/authorflow` (per-flow authoring):

| Command | When | Output |
|---|---|---|
| `/initflow` | Once per project, no `.maestro/` exists | Scaffolded stubs |
| **`/buildsuite`** | **After `/initflow`, when you want a real suite fast** | **A core set of working flows authored from a guided tour** |
| `/authorflow <name>` | Per new individual flow, post-suite | One additional flow |
| `/stabiliseflow <flow>` | Before relying on a flow as a release gate | Flakiness verdict |

The thesis: most per-flow re-work in `/authorflow` (re-discovering the project, re-walking shared screens, re-picking selectors) is avoidable by walking the whole app *once*, building a shared selector + screen cache, then composing N flows mechanically from that cache. `/buildsuite` is that single walk.

## Refusal rules

1. If `<project>/.maestro/` doesn't exist → stop, tell the user to run `/initflow` first.
2. If `<project>/.maestro/.tour-plan.json` exists with unfinished entries → ask: resume the in-progress suite, or discard and start over? Default: resume.
3. If the device isn't booted → run `${CLAUDE_PLUGIN_ROOT}/scripts/preflight.sh` then `${CLAUDE_PLUGIN_ROOT}/scripts/boot-sims.sh` first, same as `/authorflow`.
4. **Does not refuse** if some flows already exist in `.maestro/`. Flows listed in the project's `<project>/.maestro/README.md` "Covered flows" section are treated as committed and excluded from the candidate list. Stub `.yaml` files from `/initflow` (present on disk but not yet listed in README) are included in the tour as candidates and rebuilt — the tour overwrites the stub once selectors are cached. Tell the user this once at the start of Phase 1.

## Argument shape and platform resolution

`/buildsuite [--platform ios|android]`

No flow-name argument — that's what the tour produces. Platform resolution order:

1. If `--platform` is passed, use that.
2. Else if exactly one sim/emulator is booted, use its platform.
3. Else if both platforms have a booted device, ask the user once via `AskUserQuestion`.
4. Else (no device booted), ask which platform to use, then run `${CLAUDE_PLUGIN_ROOT}/scripts/preflight.sh` and `${CLAUDE_PLUGIN_ROOT}/scripts/boot-sims.sh` to bring one up before Phase 1.

## The five phases

Five phases, executed in order. Phase 3 is the persistence boundary — anything before it is in-memory only and lost on interruption; anything after it survives across sessions via `.tour-plan.json`.

### Phase 1 — Discover and confirm

Re-use the project-discovery logic from `authoring-flows.md` → "Project discovery (shared)". Read `app.json` / `app.config.{js,ts}`, `package.json`, the route directory; run auth detection. Subtract any flows already listed in `<project>/.maestro/README.md` "Covered flows" — `/buildsuite` does not touch committed flows. Stub `.yaml` files from `/initflow` (present on disk but not listed in README) **are** included in the candidate list — the tour will rebuild them.

Present the resulting candidate list to the user with a one-line journey guess each, via `AskUserQuestion` (multi-select). The user prunes / edits / confirms. The locked candidate list becomes the tour's starting checklist.

If the user is rebuilding stub flows from `/initflow`, tell them once: "These stub `.yaml` files will be overwritten by the tour with real selectors."

**Driver:** Claude proposes; user confirms.

### Phase 2 — Guided tour

Claude announces the next screen to visit ("next: tap into Login for the `login` flow"). The user taps to that screen on the device. Claude:

1. Takes a screenshot to `<project>/.maestro/authoring-evidence/_tour/<NN>-<screen-name>.png` using:
   - iOS: `xcrun simctl io booted screenshot <path>`
   - Android: `adb exec-out screencap -p > <path>`
2. Dumps `maestro --device <udid-or-serial> hierarchy | jq '.. | objects | {text, "resource-id", "accessibility-label", enabled} | select(.text or ."resource-id" or ."accessibility-label")'`.
3. Picks selectors automatically using the priority order from `writing-flows.md` (`testID` > `accessibilityLabel` > text; never coordinates).
4. Records the screen + selectors into the in-memory plan, keyed by screen name (the user supplies a short name when a new screen is encountered, or Claude proposes one and asks for confirmation in the same prompt).
5. Re-renders the coverage checklist (see "Coverage checklist UX" below).

The user is asked questions only on **genuine ambiguity**: two elements share the only available selector, or no stable selector exists at all. Everything else is automatic.

The user can issue these directives at any time:

- `done` — current flow is finished
- `skip` — jump to the next pending flow
- `add <name>` — insert a newly-discovered flow into the checklist
- `stop` — end the tour with whatever's been captured (jumps to Phase 3 with a partial plan)

**Driver:** user taps device; Claude navigates and observes.

**Exit:** when the checklist is exhausted, or user issues `stop`.

**Mid-tour flow boundaries.** A flow ends when the user reaches the success screen they declared during Phase 1, or when Claude prompts "is this the end of `<flow>`?" after a screen that looks like a terminal state. User has final say.

### Phase 3 — Plan materialisation

Write `<project>/.maestro/.tour-plan.json` containing the screens cache, the flow list with statuses, the device + platform context, and the schema version (see "Plan schema" below). Tell the user "tour complete — N flows planned. Authoring next, with a checkpoint per flow."

This is the persistence boundary. After this phase the user can quit and resume in a new session; before this phase, an interrupted tour is lost.

**Driver:** Claude writes; user passive.

### Phase 4 — Authoring loop with per-flow checkpoint

For each flow with `status: pending` (in tour-add order, with dependency hoisting — see "Ordering rule" below):

1. Render a one-screen summary: name, journey, screens touched, cached selector count, env vars needed.
2. Ask `[yes / skip / stop]` via `AskUserQuestion`.
   - `yes` → enter deep-dive sequence below.
   - `skip` → mark `status: skipped`, move to next flow. Skipped flows stay in the plan.
   - `stop` → leave the loop, plan persists with current statuses, jump to Phase 5 partial report.

**Deep-dive sequence (per `yes`):**

1. **Compose** — generate `<project>/.maestro/<flow>.yaml` from the screens + selectors in the plan. Mark `status: composed`. Header comment block names the journey, start state, env vars (per `/authorflow` Phase D conventions in `authoring-flows.md`). Per-step comments name the screen + intent + selector reasoning when non-obvious.
2. **Resolve env** — for each `env_vars` entry, check the shell environment first; for missing ones, `AskUserQuestion` once with the "I won't store this" framing from `SKILL.md`. Forwarded to Maestro via `--env`, never persisted.
3. **Run once** — invoke `${CLAUDE_PLUGIN_ROOT}/scripts/run-flows.sh --flows <project>/.maestro/<flow>.yaml --platform <p> --env ...`.
4. **On pass** → mark `status: verified`. Update `<project>/.maestro/README.md` "Covered flows" entry. Mark `status: committed`. Render a one-line ack ("`login` verified, README updated") and move to next flow without re-prompting.
5. **On fail** → enter Tier 0/1/2 debug from `troubleshooting.md`. Iterate until green or until user says skip. **Three-strike rule:** if three consecutive runs fail with no diagnosis traction, stop, mark `status: failed`, store last-run context in `last_run`, surface the diagnosis to the user, and move on.

**Ack-on-pass, prompt-on-fail.** Successful flows scroll past with a single line; the user only re-engages on failures, missing env, or the next gate. This keeps "deep dive" honest — we go deep only when needed.

**Ordering rule.** Pending flows are authored in tour-add order (the user's mental order). Exception: any flow another flow depends on (chains via `runFlow:` or whose journey text references the dependency's success state) is hoisted earlier. Detected from selector overlap + journey-text mention of a prior flow.

**Driver:** Claude composes + runs; user gates each flow.

**Exit:** no `pending` remain, or user `stop`s.

### Phase 5 — Index and report

For each flow with `status: committed`, append an entry to `<project>/.maestro/README.md`'s "Covered flows" section using the format from `/authorflow` Phase F (journey, tags, env vars, gotchas).

Render a final summary:

```
Suite build complete.
  Planned:    5
  Committed:  4   (login, app-launch, view-list, settings)
  Failed:     1   (edit-profile — selector mismatch on save button)
  Skipped:    0
```

Suggest `/stabiliseflow <name>` for any flow the user plans to gate releases on.

Move `<project>/.maestro/.tour-plan.json` → `<project>/.maestro/.tour-plan.archive.json` so a future `/buildsuite` starts clean. The archive is preserved for diagnostic purposes; the user can delete it once they're done.

**Driver:** Claude reports.

## Plan schema (`.tour-plan.json`)

Single JSON file at `<project>/.maestro/.tour-plan.json`, gitignored.

```json
{
  "schema_version": 1,
  "created_at": "2026-04-30T14:22:01Z",
  "platform": "ios",
  "device": {
    "udid": "ABCD-1234",
    "model": "iPhone 17 Pro",
    "os": "iOS 26.2"
  },
  "app_id": "com.example.myapp",
  "screens": {
    "login": {
      "first_seen_step": 2,
      "screenshot": ".maestro/authoring-evidence/_tour/01-login.png",
      "selectors_unstable": false,
      "elements": [
        {
          "role": "email_input",
          "selector": { "kind": "id", "value": "email_input" },
          "reasoning": "testID present, wrapped in <View accessible> per RN container rule"
        },
        {
          "role": "password_input",
          "selector": { "kind": "id", "value": "password_input" },
          "reasoning": "testID present"
        },
        {
          "role": "submit_button",
          "selector": { "kind": "id", "value": "login_submit" },
          "reasoning": "testID; wrap tap in runFlow.when.visible due to spinner-replace"
        }
      ]
    }
  },
  "flows": [
    {
      "name": "login",
      "journey": "Open app, tap Login, enter email and password, land on home",
      "start_state": "logged out, clean install",
      "success_criterion": { "kind": "text_visible", "value": "Welcome" },
      "screens": ["login", "home"],
      "env_vars": ["MAESTRO_USERNAME", "MAESTRO_PASSWORD"],
      "tags": ["smoke", "auth"],
      "status": "pending",
      "yaml_path": null,
      "last_run": null
    }
  ]
}
```

### Field notes

- **`schema_version`** — day-one value `1`. Future schema changes bump this and migrate cleanly.
- **`screens`** — first-class and shared across flows. Two flows that traverse `home` reference the same `screens.home` entry; selectors picked once, reused everywhere. This is the leverage that justifies the heavy plan.
- **`screens.<name>.selectors_unstable`** — set to `true` when `maestro hierarchy` returned nothing useful during the tour (see "Tour-time" edge cases). Authoring uses text/visible-wait fallbacks for screens with this flag rather than relying on the (empty) selector cache. Default `false`.
- **`selector.kind`** — one of `id` (testID / resource-id), `accessibility`, `text`, `regex`. Mirrors the priority order in `writing-flows.md`. No `coordinates` — refused by design.
- **`status` enum** — `pending` -> `composed` -> `verified` -> `committed`, plus terminal states `skipped` and `failed`. Resume reads `status` to know which flows still need work.
- **Evidence path** — points into `.maestro/authoring-evidence/_tour/`. Tour screenshots live alongside per-flow ones, gitignored.
- **`last_run`** — appended on Phase 4 failures: `{ "timestamp": "...", "failed_step": "...", "reason": "..." }`. Resuming after a fix doesn't lose the diagnosis.
- **No full Maestro YAML in the schema.** YAML is generated from `screens` + `flows` on demand and lives in `<flow>.yaml` once `status >= composed`. Storing both would create drift.

## Coverage checklist UX

The visible artefact during Phase 2 — the main lever against tour tedium. Re-rendered after every screen visit and after any user-issued state change (`add`, `skip`, `done`).

```
Tour progress — 3/5 flows mapped, 7 screens visited

Flows
  [done]    app-launch        — opens, lands on home
  [done]    login             — login -> home
  [active]  view-list         — home -> conversations  <- currently mapping
  [pending] settings          — home -> settings -> toggle
  [pending] edit-profile      — settings -> profile -> edit (added mid-tour)

Screens cached
  login (3 selectors), home (5), conversations (4), settings (2)

Next: tap into a conversation to capture the messages screen.
Reply 'done' if view-list is finished, 'skip' to move to settings,
'add <name>' to add a flow, 'stop' to end the tour.
```

### Why this shape

- **Three flow states** (`done` / `active` / `pending`) — compressed view of the JSON `status` field. User sees how far they are at a glance.
- **Screen-cache count** — visible proof selectors are being captured.
- **Always-visible exit hatches** — `done`, `skip`, `add <name>`, `stop`. User never has to wonder how to bail.
- **One concrete next instruction** — the user knows exactly what to do with the device.

Render cadence is roughly every 30-60 seconds during the tour. When a screen's hierarchy is genuinely ambiguous (two elements with the same label, or no stable selector), checklist render is suspended for one `AskUserQuestion` prompt then resumed. That ambiguity prompt is the only legitimate user-prompt during a screen visit; everything else is automatic.

## Edge cases and error handling

### Tour-time

| Case | Behaviour |
|---|---|
| User taps to a screen Claude wasn't expecting (modal, unrouted target) | Treat as a discovered screen — capture screenshot + hierarchy + selectors, ask "what is this screen, and is it part of a flow we're already mapping or a new one?" Don't forcibly redirect. |
| Dead end (back-button-only screen with no useful content) | Claude offers "skip this — no selectors worth caching" with one-press confirmation. Plan records as visited-but-unused so we don't keep re-prompting. |
| `maestro hierarchy` returns nothing useful (empty / overlay / animation) | Wait 2s, retry once. If still empty, set `screens.<name>.selectors_unstable: true`, surface to user: "hierarchy unreadable here — tap forwards manually, I'll skip selector capture for this step." Authoring uses text/visible-wait fallbacks for this screen. |
| Two elements share the only available selector | The single ambiguity-prompt allowed per screen. User picks; choice recorded in `selector.reasoning`. |
| Flow file exists from `/initflow` but isn't yet listed in README's "Covered flows" | Treat as a stub. Include in the tour normally; tour rebuilds the YAML from the cached plan and overwrites the stub. User is told this at the start of Phase 1 so they're not surprised by the overwrite. |
| Flow file exists *and* is listed in README's "Covered flows" | Treat as committed. Excluded from the candidate list — `/buildsuite` does not touch it. User can `/authorflow <name>` separately to update it. |
| App crash mid-tour | In-memory plan lost (tour state doesn't persist before Phase 3). User restarts `/buildsuite`; refusal rule 2 handles any prior `.tour-plan.json`. |

### Authoring-loop

| Case | Behaviour |
|---|---|
| Flow's first run fails after 3 debug iterations with no traction | Stop iterating. Mark `status: failed`, store last-run context, render a brief diagnosis ("hierarchy still shows X but flow expects Y"). Move on. User can revisit with `/authorflow <name>` later. |
| Env var resolution: user declines to provide a required value | Mark `status: skipped` with `last_run.reason: "missing_env"`. Move on — don't block the loop. |
| `run-flows.sh` reports device disconnected mid-run | `${CLAUDE_PLUGIN_ROOT}/scripts/boot-sims.sh` -> re-install (with original `${CLAUDE_PLUGIN_ROOT}/scripts/install-app.sh` args) -> retry once. If second attempt fails, three-strike rule applies. |
| User says `stop` mid-flow during composition or debug | Save current `status` honestly (`composed` if YAML written but not run, `pending` otherwise — never overstate). Plan persisted. Phase 5 partial report runs. Resume next session picks up at the same flow. |
| README write conflict with user's manual edits | Read README, find "Covered flows" section, append entries below the last one. If section doesn't exist, create it. Never rewrite existing entries. |

### Cross-cutting

- **Credentials boundary held.** Same rule as the rest of the skill: read shell env, prompt for missing with the "I won't store this" framing, forward via `--env`, never persist. Each flow's env is resolved at *its* run-time, not batched up front.
- **ASCII-only output** for any new bash output (per `CLAUDE.md`'s `[ok]/[warn]/[err]/[*]` convention).
- **UK English** in all written prose: `stabilise`, `behaviour`, `prioritise`, etc. The command name `/buildsuite` is fine.
- **Project-agnostic** language. No real app names, generic examples only.

## Cross-references

- `authoring-flows.md` -> "Project discovery (shared)" — the discovery logic Phase 1 reuses.
- `authoring-flows.md` -> "Phase D — Compose" / "Phase E — Run once" / "Phase F — Commit + index" — the per-flow conventions Phase 4 reuses.
- `writing-flows.md` -> "Selectors" and "Tips for non-flaky flows" — the priority order Phase 2 applies automatically.
- `troubleshooting.md` -> "Efficient debugging (token-aware tiering)" — the Tier 0/1/2 ladder Phase 4 enters on a failed run.
- `SKILL.md` -> the lifecycle command table this command joins; the credentials boundary rule referenced from the deep-dive sequence.
