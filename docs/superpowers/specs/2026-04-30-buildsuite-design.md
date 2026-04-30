# `/buildsuite` design

**Date:** 2026-04-30
**Status:** Approved design, pending implementation plan
**Owner:** Chris Howard

## Summary

`/buildsuite` is a new fourth lifecycle slash command for `mobile-flow-runner`. It produces a core set of working Maestro flows for a project in a single session, by first walking the running app with the user (a guided **tour**) to build a comprehensive selector + screen plan, then looping over each planned flow for an authoring deep-dive with per-flow checkpoints.

It sits between `/initflow` (one-time scaffold) and `/authorflow` (per-flow authoring) — for the case where a project has been initialised but no real flows exist yet, and the user wants to bootstrap a useful smoke suite without invoking `/authorflow` six times.

## Problem

Today the flow lifecycle is:

| Command | Output |
|---|---|
| `/initflow` | Scaffolded stubs — selectors are guesses based on common labels, mostly don't match the real app |
| `/authorflow <name>` | One real flow, end-to-end (interview → screen walk → compose → run → commit) |
| `/stabiliseflow <flow>` | Flakiness verdict on an existing flow |

To get from "fresh project" to "useful smoke suite of N flows" today, the user runs `/initflow` once and then `/authorflow` N times. Each `/authorflow` re-discovers the project, re-interviews the user, re-walks screens that other flows have already visited, and re-picks selectors that other flows already know. For an app with 4-6 core journeys this is hours of repeated work.

**The thesis behind `/buildsuite`:** most of the per-flow re-work is avoidable by walking the whole app *once*, building a shared selector + screen cache, then composing N flows mechanically from that cache.

## Lifecycle position

`/buildsuite` becomes the fourth lifecycle command:

| Command | When | Output |
|---|---|---|
| `/initflow` | Once per project, no `.maestro/` exists | Scaffolded stubs |
| **`/buildsuite`** | **After `/initflow`, when you want a real suite fast** | **A core set of working flows authored from a guided tour** |
| `/authorflow <name>` | Per new individual flow, post-suite | One additional flow |
| `/stabiliseflow <flow>` | Before relying on a flow as a release gate | Flakiness verdict |

### Refusal rules

Mirroring the existing pattern:

1. If `<project>/.maestro/` doesn't exist → stop, tell the user to run `/initflow` first.
2. If `<project>/.maestro/.tour-plan.json` exists with unfinished entries → ask: resume the in-progress suite, or discard and start over? Default: resume.
3. If the device isn't booted → run `preflight.sh` then `boot-sims.sh` first, same as `/authorflow`.
4. **Does not refuse** if some flows already exist in `.maestro/` — `/buildsuite` augments rather than replaces. Flows listed in the project's `<project>/.maestro/README.md` "Covered flows" section are treated as committed and excluded from the candidate list. Stub `.yaml` files from `/initflow` (present on disk but not yet listed in README) are included in the tour as candidates and rebuilt — the tour overwrites the stub once selectors are cached. The user is told this once at the start of Phase 1.

### Argument shape

`/buildsuite [--platform ios|android]`

No flow-name argument — that's what the tour produces. Platform resolution order:
1. If `--platform` is passed, use that.
2. Else if exactly one sim/emulator is booted, use its platform.
3. Else if both platforms have a booted device, ask the user once (`AskUserQuestion`).
4. Else (no device booted), ask which platform to use, then run `preflight.sh` + `boot-sims.sh` to bring one up before Phase 1.

## Phases

Five phases, executed in order. Each is a section in `commands/buildsuite.md` and `references/building-suites.md`.

### Phase 1 — Discover & confirm

Re-use `/initflow`'s discovery logic (read `app.json` / `app.config.{js,ts}`, `package.json`, route directory; run auth detection per `references/authoring-flows.md`). Subtract any flows already authored in `<project>/.maestro/`. Present the resulting candidate list to the user with a one-line journey guess each, via `AskUserQuestion`. User prunes / edits / confirms. Locked candidate list becomes the tour's starting checklist.

**Driver:** Claude proposes; user confirms.

### Phase 2 — Guided tour

Claude announces the next screen to visit ("next: tap into Login for the `login` flow"). The user taps to that screen on the device. Claude takes a screenshot, dumps `maestro hierarchy`, picks selectors automatically using the priority order from `references/writing-flows.md` (`testID` > `accessibilityLabel` > text; never coordinates), and records screen + selectors into the in-memory plan.

The user is asked questions only on **genuine ambiguity** (two elements share the only available selector, or no stable selector exists). Everything else is automatic. After every screen visit, the coverage checklist is re-rendered.

The user can `add <name>` mid-tour to insert a newly-discovered flow into the checklist. The user can `done` to declare the current flow finished, `skip` to jump to the next flow, or `stop` to end the tour with whatever's been captured.

**Driver:** user taps device; Claude navigates and observes.

**Exit:** when the checklist is exhausted, or user `stop`s.

### Phase 3 — Plan materialisation

Write `<project>/.maestro/.tour-plan.json` containing the screens cache, the flow list with statuses, the device + platform context, and the schema version. Tell the user "tour complete — N flows planned. Authoring next, with a checkpoint per flow."

This is the persistence boundary. After this phase, the user can quit and resume in a new session; before this phase, an interrupted tour is lost.

**Driver:** Claude writes; user passive.

### Phase 4 — Authoring loop with per-flow checkpoint

For each flow with `status: pending` (in tour-add order, with dependency hoisting — see "Ordering rule" below):

1. Render a one-screen summary: name, journey, screens touched, cached selector count, env vars needed.
2. Ask `[yes / skip / stop]`.
   - `yes` → enter deep-dive sequence below.
   - `skip` → mark `status: skipped`, move to next flow. Skipped flows stay in the plan.
   - `stop` → leave the loop, plan persists with current statuses, jump to Phase 5 partial report.

**Deep-dive sequence (per `yes`):**

1. **Compose** — generate `<project>/.maestro/<flow>.yaml` from the screens + selectors in the plan. Mark `status: composed`. Header comment block names the journey, start state, env vars (per `/authorflow` Phase D conventions). Per-step comments name the screen + intent + selector reasoning when non-obvious.
2. **Resolve env** — for each `env_vars` entry, check shell environment first; for missing ones, `AskUserQuestion` once with the "I won't store this" framing. Forwarded to Maestro via `--env`, never persisted.
3. **Run once** — invoke `${CLAUDE_PLUGIN_ROOT}/scripts/run-flows.sh --flows <flow>.yaml --platform <p> --env ...`.
4. **On pass** → mark `status: verified`. Update README entry. Mark `status: committed`. Render a one-line ack ("`login` ✓ verified, README updated") and move to next flow without re-prompting.
5. **On fail** → enter Tier 0/1/2 debug from `references/troubleshooting.md`. Iterate until green or until user says skip. **Three-strike rule:** if three consecutive runs fail with no diagnosis traction, stop, mark `status: failed`, store last-run context, surface the diagnosis to the user, and move on.

**Ack-on-pass, prompt-on-fail.** Successful flows scroll past with a single line; user only re-engages on failures, missing env, or the next gate. This keeps "deep dive" honest — we go deep only when needed.

**Ordering rule.** Pending flows are authored in the order they were added to the plan during Phase 2 (the user's mental order). Exception: any flow another flow depends on (chains via `runFlow:` or whose journey text references the dependency's success state) is hoisted earlier. Detected from selector overlap + journey-text mention of a prior flow.

**Driver:** Claude composes + runs; user gates each flow.

**Exit:** no `pending` remain, or user `stop`s.

### Phase 5 — Index & report

For each flow with `status: committed`, append an entry to `<project>/.maestro/README.md`'s "Covered flows" section using the format from `/authorflow` Phase F (journey, tags, env vars, gotchas).

Render a final summary: N planned / M authored / K verified / J failed / S skipped. Suggest `/stabiliseflow <name>` for any flow the user plans to gate releases on.

Move `.tour-plan.json` → `.tour-plan.archive.json` so a future `/buildsuite` starts clean. (Archive preserved for diagnostic purposes; users can delete it once they're done.)

**Driver:** Claude reports.

## `.tour-plan.json` schema

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
      "journey": "Open app → tap Login → enter email+password → land on home",
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

### Schema notes

- **Screens are first-class and shared.** Two flows that traverse `home` reference the same `screens.home` entry — selectors picked once, reused everywhere. This is the leverage that justifies the heavy plan.
- **`status` enum per flow:** `pending` → `composed` → `verified` → `committed`, plus terminal states `skipped` and `failed`. Resume reads `status` to know which flows still need work.
- **`selector.kind`** is one of `id` (testID / resource-id), `accessibility`, `text`, `regex`. Mirrors the priority order in `references/writing-flows.md`. No `coordinates` — refused by design.
- **Evidence path** points into `.maestro/authoring-evidence/_tour/` so tour screenshots live alongside per-flow ones, gitignored by default.
- **`schema_version`** so future changes can migrate cleanly. Day-one value is `1`.
- **`last_run`** appends timestamp + failed step on Phase 4 failures, so resuming after a fix doesn't lose the diagnosis.
- **No full Maestro YAML in the schema.** YAML is generated from screens + flows on demand and lives in `<flow>.yaml` once `status >= composed`. Storing both would create drift.
- **Optional per-screen flag `selectors_unstable: true`** is set when `maestro hierarchy` returned nothing useful during the tour (see the tour-time edge cases). Authoring uses text/visible-wait fallbacks for screens with this flag rather than relying on the (empty) selector cache.

## Coverage checklist UX

The visible artefact during Phase 2 — the main lever against tour tedium. Re-rendered after every screen visit.

```
Tour progress — 3/5 flows mapped, 7 screens visited

Flows
  [done]    app-launch        — opens, lands on home
  [done]    login             — login → home
  [active]  view-list         — home → conversations  ← currently mapping
  [pending] settings          — home → settings → toggle
  [pending] edit-profile      — settings → profile → edit (added mid-tour)

Screens cached
  login (3 selectors), home (5), conversations (4), settings (2)

Next: tap into a conversation to capture the messages screen.
Reply 'done' if view-list is finished, 'skip' to move to settings,
'add <name>' to add a flow, 'stop' to end the tour.
```

### Why this shape

- **Three flow states** (`done` / `active` / `pending`) — compressed view of the JSON status field. User knows at a glance how far they are.
- **Screen-cache count** — visible proof selectors are being captured, so the user trusts the tour is doing work and not just asking questions.
- **Always-visible exit hatches** — `done`, `skip`, `add <name>`, `stop`. User never has to wonder how to bail.
- **One concrete next instruction** — the user knows exactly what to do with the device.

### Re-render cadence

After every `maestro hierarchy` dump (every screen visited) and after any user-issued state change (`add`, `skip`, `done`). Roughly one render every 30-60 seconds during the tour.

### Ambiguity handling

When a screen has two elements with the same label or no stable selector, the checklist render is suspended for one `AskUserQuestion` cycle ("two buttons say 'Continue' on this screen — which is the one that submits?"), then resumed. This is the only legitimate user-prompt during a screen visit; everything else is automatic.

## File layout

### New files

| File | Purpose |
|---|---|
| `commands/buildsuite.md` | Slash command entry point. Thin routing layer (~30 lines), same shape as the other three: YAML frontmatter (description, argument-hint, allowed-tools) + a markdown prompt that delegates to `references/building-suites.md` and the relevant `SKILL.md` sections. **Does not inline phase logic.** |
| `references/building-suites.md` | Depth doc for `/buildsuite`. Five phases described in detail, the `.tour-plan.json` schema, the coverage checklist UX, the deep-dive sequence, edge cases. Sibling to `authoring-flows.md`. |

### Extended files

| File | Change |
|---|---|
| `skills/mobile-flow-runner/SKILL.md` | Add a section after the existing `/authorflow` orchestration: "When `/buildsuite` is invoked, follow `references/building-suites.md`." Add `.tour-plan.json` to the artefact list. Add the new refusal rule (resume vs. start-over). |
| `references/authoring-flows.md` | Add `/buildsuite` to the lifecycle table at the top. Add a one-paragraph cross-reference to `building-suites.md`. Don't duplicate content. |
| `README.md` | Add `/buildsuite` to the lifecycle commands list with a one-liner. |
| `CHANGELOG.md` | `[Unreleased]` entry under `Added` describing `/buildsuite` and the plan format. Version bump + tag happens at release time per project release discipline, not now. |
| `.gitignore` (this repo) | Add `.maestro/.tour-plan.json` and `.maestro/.tour-plan.archive.json`. |
| Project-side `.gitignore` (added by `/initflow`) | Same two entries appended when `/initflow` runs against a project. Update `references/maestro-readme-template.md` if it references gitignored paths. |

### Reuse rules (explicit — these are the leverage)

- **Discovery in Phase 1** uses the same logic as `/initflow`'s discovery step. Light refactor: extract that prose under a heading both commands link into, in `references/authoring-flows.md`. Don't duplicate.
- **Selector picking in Phase 2** uses the priority order already documented in `references/writing-flows.md`. No new rules.
- **Compose / Run / Debug in Phase 4** call into `/authorflow`'s Phase D-E plus `troubleshooting.md`'s Tier 0/1/2. `building-suites.md` describes how the cached plan substitutes for Phase B/C inputs and links to the existing phase docs for everything else.
- **README index update in Phase 5** uses the same one-flow entry format as `/authorflow` Phase F.

### What's deliberately NOT new

No bash scripts. The tour is conversational orchestration on top of `maestro hierarchy` (already a Maestro CLI command) and `xcrun simctl io booted screenshot` / `adb exec-out screencap` (already documented in Phase C of `authoring-flows.md`). Bash scripts are reserved for mechanical, side-effecting operations.

## Edge cases & error handling

### Tour-time

| Case | Behaviour |
|---|---|
| User taps to a screen Claude wasn't expecting (modal, unrouted target) | Treat as a discovered screen — capture screenshot + hierarchy + selectors, ask "what is this screen, and is it part of a flow we're already mapping or a new one?" Don't forcibly redirect. |
| Dead end (back-button-only screen with no useful content) | Claude offers "skip this — no selectors worth caching" with one-press confirmation. Plan records as visited-but-unused so we don't keep re-prompting. |
| `maestro hierarchy` returns nothing useful (empty / overlay / animation) | Wait 2s, retry once. If still empty, surface to user: "hierarchy unreadable here — tap forwards manually, I'll skip selector capture for this step." Plan flags the screen `selectors_unstable: true` so authoring uses text/visible-wait fallbacks. |
| Two elements share the only available selector | The single ambiguity-prompt allowed per screen. User picks; choice recorded in `selector.reasoning`. |
| Flow file exists from `/initflow` but isn't yet listed in README's "Covered flows" | Treat as a stub. Include in the tour normally; tour rebuilds the YAML from the cached plan and overwrites the stub. User is told this at the start of Phase 1 so they're not surprised by the overwrite. |
| Flow file exists *and* is listed in README's "Covered flows" | Treat as committed. Excluded from the candidate list — `/buildsuite` does not touch it. User can `/authorflow <name>` separately to update it. |
| App crash mid-tour | In-memory plan lost (per resume model: tour state doesn't persist). User restarts `/buildsuite`; refusal rule 2 handles any prior `.tour-plan.json`. |

### Authoring-loop

| Case | Behaviour |
|---|---|
| Flow's first run fails after 3 debug iterations with no traction | Stop iterating. Mark `status: failed`, store last-run context, render brief diagnosis ("hierarchy still shows X but flow expects Y"). Move on. User can revisit with `/authorflow <name>` later. |
| Env var resolution: user declines to provide a required value | Mark `status: skipped` with `reason: missing_env`. Move on. |
| `run-flows.sh` reports device disconnected mid-run | `boot-sims.sh` → re-install (with original `install-app.sh` args) → retry once. If second attempt fails, three-strike rule applies. |
| User says `stop` mid-flow during composition or debug | Save current `status` honestly (`composed` if YAML written but not run, `pending` otherwise — never overstate). Plan persisted. Phase 5 partial report runs. Resume next session picks up at the same flow. |
| README write conflict with user's manual edits | Read README, find "Covered flows" section, append entries below the last one. If section doesn't exist, create it. Never rewrite existing entries. |

### Cross-cutting

- **Credentials boundary held.** Same rule as the rest of the skill: read shell env, prompt for missing with the "I won't store this" framing, forward via `--env`, never persist. Each flow's env is resolved at *its* run-time, not batched up front.
- **ASCII-only output** for any new bash output (per `CLAUDE.md`'s `[ok]/[warn]/[err]/[*]` convention).
- **UK English** in all written prose: `stabilise`, `behaviour`, `prioritise`, etc. Command name `/buildsuite` is fine.
- **Project-agnostic** language in `building-suites.md` and `commands/buildsuite.md`. No real app names, generic examples.

## Open question (non-blocking)

Should `/buildsuite` ever run `/stabiliseflow` automatically on the verified flows at the end? Default decision: **no.** Stabilisation is a deliberate pre-release step; doing it inside `/buildsuite` would balloon the session and conflate two distinct lifecycle phases. User can run `/stabiliseflow <name>` when ready.

## Success criteria

1. A user with an Expo or React Native project can go from "no `.maestro/` flows" to a committed suite of 4-6 verified smoke flows in a single `/buildsuite` session, without separately invoking `/authorflow`.
2. Per-flow re-work (re-discovery, re-walking shared screens, re-picking selectors) is eliminated by the shared screen cache.
3. The user can `stop` at any point and resume in a new session without losing tour-derived plan data.
4. The credentials boundary, ASCII-output rule, UK-English convention, and project-agnostic-docs rule are all preserved.
5. No new bash scripts are added — leverage of existing `preflight.sh`, `boot-sims.sh`, `install-app.sh`, `run-flows.sh`, `list-devices.sh` is total.

## Out of scope

- Cross-platform tour (iOS + Android in one session) — out of scope per Q6b. Single platform per `/buildsuite` run; flows generalise across platforms via Maestro's design.
- Automatic stabilisation (running `/stabiliseflow` inside `/buildsuite`) — out of scope per the open question above.
- Mid-tour resume (persisting tour state before Phase 3) — out of scope per Q5. Plan persists at Phase 3 only.
- Claude-driven taps via Maestro `tapOn` during the tour — out of scope per Q2. User drives the device; Claude navigates by instruction.
