# `/buildsuite` Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a fourth lifecycle slash command `/buildsuite` that walks an app once with the user (a guided tour), builds a shared selector/screen plan persisted to `.maestro/.tour-plan.json`, then loops over each planned flow with per-flow checkpoints to compose, run, and commit working Maestro flows.

**Architecture:** Pure docs + orchestration change. One new slash command (`commands/buildsuite.md`), one new reference doc (`references/building-suites.md`), and small extensions to existing files (`SKILL.md`, `authoring-flows.md`, `initflow.md`, `README.md`, `CHANGELOG.md`, `.gitignore`). **No new bash scripts** — the tour reuses `maestro hierarchy`, `xcrun simctl io booted screenshot`, and `adb exec-out screencap` (all already documented in `authoring-flows.md` Phase C). The deep-dive sequence reuses `${CLAUDE_PLUGIN_ROOT}/scripts/run-flows.sh`. A light refactor in `authoring-flows.md` extracts shared project-discovery prose so `/initflow` and `/buildsuite` link to one source rather than duplicating it.

**Tech Stack:** Markdown (skill spec, command files, references), JSON schema (the `.tour-plan.json` shape, defined in the spec). No code language. No test framework — this repo has no unit tests by design (per `CLAUDE.md`); validation is end-to-end against a real mobile project after the docs land.

**Reference:** [`docs/superpowers/specs/2026-04-30-buildsuite-design.md`](../specs/2026-04-30-buildsuite-design.md)

---

## File structure

| File | Action | Lines (rough) | Responsibility |
|---|---|---|---|
| `.gitignore` | Modify | +2 | Add `.maestro/.tour-plan.json` and `.maestro/.tour-plan.archive.json` so this repo's validation runs don't accidentally commit them |
| `references/authoring-flows.md` | Refactor + extend | ~+30, ~-10 | (a) Extract the project-discovery prose under a new shared heading both `/initflow` and `/buildsuite` link into; (b) add `/buildsuite` row to the lifecycle table at the top; (c) add a cross-reference paragraph pointing to `building-suites.md` |
| `references/building-suites.md` | Create | ~350 | Depth doc for `/buildsuite` — five phases, plan schema, coverage-checklist UX, deep-dive sequence, edge cases. Sibling to `authoring-flows.md` |
| `commands/buildsuite.md` | Create | ~30-40 | Thin slash-command routing layer — frontmatter + delegation prose. Same shape as the other three command files. **Does not inline phase logic** |
| `skills/mobile-flow-runner/SKILL.md` | Extend | ~+25 | Add `/buildsuite` to the "Authoring flows" command table; add an orchestration note pointing at `building-suites.md`; add `.tour-plan.json` to the artefact list |
| `commands/initflow.md` | Modify | +2 lines in step 6 | Update the gitignore step to write all four tour-related entries |
| `references/maestro-readme-template.md` | Modify | minor | If the template lists `.maestro/` files, add a one-liner mentioning `.tour-plan.json` is transient |
| `README.md` | Extend | +3 lines | Add `/buildsuite` to the lifecycle commands list with a one-liner |
| `CHANGELOG.md` | Extend | +5 lines | Add `[Unreleased]` → `Added` entry describing `/buildsuite` and the plan format |

**Out of scope (per spec):** no new bash scripts; no code; no tests; no version bump (release happens separately per project release discipline).

---

## Task 1: Add tour-plan paths to repo `.gitignore`

The smallest, most isolated change. Done first to land the trivial bit and verify the workflow.

**Files:**
- Modify: `.gitignore`

- [ ] **Step 1: Read the current gitignore**

Run: `cat .gitignore`

Expected current contents (verify):
```
.DS_Store
.idea/
.vscode/
*.swp
*.swo

# Local artifacts produced when validating against a real project
.maestro/artifacts/
.maestro/authoring-evidence/
**/test_output/
```

- [ ] **Step 2: Append the two new tour-plan paths**

Edit `.gitignore` — under the existing "Local artifacts" comment, after the `authoring-evidence/` line, add:

```
.maestro/.tour-plan.json
.maestro/.tour-plan.archive.json
```

Final block under the "Local artifacts" comment:
```
# Local artifacts produced when validating against a real project
.maestro/artifacts/
.maestro/authoring-evidence/
.maestro/.tour-plan.json
.maestro/.tour-plan.archive.json
```

- [ ] **Step 3: Verify**

Run: `git check-ignore -v .maestro/.tour-plan.json`
Expected output: a line referencing `.gitignore` and the new pattern.

(The path doesn't need to exist for `git check-ignore` to confirm the rule.)

- [ ] **Step 4: Commit**

```bash
git add .gitignore
git commit -m "chore(gitignore): ignore .maestro/.tour-plan.json artifacts"
```

---

## Task 2: Refactor `authoring-flows.md` — extract shared project-discovery section

`/buildsuite` reuses `/initflow`'s project-discovery logic (read `app.json`, `package.json`, route directory; auth detection). Today that prose lives under "Init phase → 1. Discover" + "2. Auth detection" in `references/authoring-flows.md`. Extract those two subsections under a new top-level heading both commands can link into. **Don't change the meaning** — this is a refactor.

**Files:**
- Modify: `references/authoring-flows.md` (lines 13-47 area)

- [ ] **Step 1: Read the current `authoring-flows.md`**

Run: `cat references/authoring-flows.md` and confirm the structure:
- "## Init phase (`/initflow`)"
  - "### 1. Discover" (lines 17-29 currently)
  - "### 2. Auth detection" (lines 30-40 currently)
  - "### 3. Confirm and scaffold"
  - "### 4. Hand off"
- "## Phased authoring loop (`/authorflow`)"
  - "### Phase A — Discover" (different — per-flow, not project-wide; do not touch)

- [ ] **Step 2: Add a new top-level heading "Project discovery (shared)"**

Insert this section *before* the "## Init phase" heading. The new section's body is the verbatim contents of the current "### 1. Discover" and "### 2. Auth detection" subsections, but promoted one heading level (`###` → `##` is wrong — keep them as subsections under the new top-level heading; demote no further).

Final structure:

```markdown
# Authoring Maestro flows

[existing intro paragraph + lifecycle table — leave for now, Task 6 will edit the table]

## Project discovery (shared)

Used by `/initflow` for one-time scaffolding and `/buildsuite` for tour-time candidate enumeration. Project-wide; for per-flow discovery during `/authorflow` see "Phase A — Discover" below.

### Reading the project

[Move the body of the current "### 1. Discover" here, verbatim]

### Auth detection

[Move the body of the current "### 2. Auth detection" here, verbatim, including the table]

## Init phase (`/initflow`)

One-time bootstrap. Refuse to re-run if `.maestro/` already exists.

### 1. Discover and detect auth

See [Project discovery (shared)](#project-discovery-shared) above. After running discovery, build a candidate flow list. Common ones:

- `app-launch` — always
- `login` — only if auth detected
- Per top-level route (home, settings, etc.) — usually `view-list` or similar

### 2. Confirm and scaffold

[The current "### 3. Confirm and scaffold" body, verbatim — renumbered from 3 to 2]

### 3. Hand off

[The current "### 4. Hand off" body, verbatim — renumbered from 4 to 3]
```

- [ ] **Step 3: Verify the refactor preserves meaning**

Run: `git diff references/authoring-flows.md`

Sanity check: the diff should show *moved* content (additions in the new section, deletions in the old subsections), no semantic prose changes. Specifically:
- The auth-detection table contents are identical.
- The `app.json` / `package.json` / route-directory bullets are identical.
- The "two or more signals = scaffold `login.yaml`" rule is identical.

- [ ] **Step 4: Verify internal links still resolve**

Run: `grep -n "## " references/authoring-flows.md`

Confirm `## Project discovery (shared)`, `## Init phase (\`/initflow\`)`, `## Phased authoring loop (\`/authorflow\`)`, `## Stabilisation (\`/stabiliseflow\`)`, `## Editing existing flows` all appear. The `(#project-discovery-shared)` slug used in step 2 should match GitHub's slugification of the heading.

- [ ] **Step 5: Commit**

```bash
git add references/authoring-flows.md
git commit -m "refactor(refs): extract shared project-discovery section in authoring-flows.md"
```

---

## Task 3: Write `references/building-suites.md`

The depth doc for `/buildsuite`. The bulk of the implementation work lives here.

**Files:**
- Create: `references/building-suites.md`

- [ ] **Step 1: Outline the document structure**

The file's top-level structure must be:

```markdown
# Building a flow suite

[Intro paragraph: what /buildsuite is, when to use it, sibling to authoring-flows.md]

## Lifecycle position
## Refusal rules
## Argument shape and platform resolution
## The five phases
### Phase 1 — Discover and confirm
### Phase 2 — Guided tour
### Phase 3 — Plan materialisation
### Phase 4 — Authoring loop with per-flow checkpoint
### Phase 5 — Index and report
## Plan schema (`.tour-plan.json`)
## Coverage checklist UX
## Edge cases and error handling
### Tour-time
### Authoring-loop
### Cross-cutting
## Cross-references
```

- [ ] **Step 2: Write the intro + lifecycle position**

```markdown
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
```

- [ ] **Step 3: Write the refusal rules and argument shape**

```markdown
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
4. Else (no device booted), ask which platform to use, then run `preflight.sh` + `boot-sims.sh` to bring one up before Phase 1.
```

- [ ] **Step 4: Write Phase 1 — Discover and confirm**

```markdown
## The five phases

### Phase 1 — Discover and confirm

Re-use the project-discovery logic from `authoring-flows.md` → "Project discovery (shared)". Read `app.json` / `app.config.{js,ts}`, `package.json`, the route directory; run auth detection. Subtract any flows already listed in `<project>/.maestro/README.md` "Covered flows" — `/buildsuite` does not touch committed flows. Stub `.yaml` files from `/initflow` (present on disk but not in README) **are** included in the candidate list — the tour will rebuild them.

Present the resulting candidate list to the user with a one-line journey guess each, via `AskUserQuestion` (multi-select). The user prunes / edits / confirms. The locked candidate list becomes the tour's starting checklist.

If the user is rebuilding stub flows from `/initflow`, tell them once: "These stub `.yaml` files will be overwritten by the tour with real selectors."

**Driver:** Claude proposes; user confirms.
```

- [ ] **Step 5: Write Phase 2 — Guided tour**

```markdown
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
```

- [ ] **Step 6: Write Phase 3 — Plan materialisation and Phase 4 — Authoring loop**

```markdown
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
4. **On pass** → mark `status: verified`. Update `<project>/.maestro/README.md` "Covered flows" entry. Mark `status: committed`. Render a one-line ack ("`login` ✓ verified, README updated") and move to next flow without re-prompting.
5. **On fail** → enter Tier 0/1/2 debug from `troubleshooting.md`. Iterate until green or until user says skip. **Three-strike rule:** if three consecutive runs fail with no diagnosis traction, stop, mark `status: failed`, store last-run context in `last_run`, surface the diagnosis to the user, and move on.

**Ack-on-pass, prompt-on-fail.** Successful flows scroll past with a single line; the user only re-engages on failures, missing env, or the next gate. This keeps "deep dive" honest — we go deep only when needed.

**Ordering rule.** Pending flows are authored in tour-add order (the user's mental order). Exception: any flow another flow depends on (chains via `runFlow:` or whose journey text references the dependency's success state) is hoisted earlier. Detected from selector overlap + journey-text mention of a prior flow.

**Driver:** Claude composes + runs; user gates each flow.

**Exit:** no `pending` remain, or user `stop`s.
```

- [ ] **Step 7: Write Phase 5 — Index and report**

```markdown
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
```

- [ ] **Step 8: Write the plan schema section**

```markdown
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

### Field notes

- **`schema_version`** — day-one value `1`. Future schema changes bump this and migrate cleanly.
- **`screens`** — first-class and shared across flows. Two flows that traverse `home` reference the same `screens.home` entry; selectors picked once, reused everywhere. This is the leverage that justifies the heavy plan.
- **`screens.<name>.selectors_unstable`** — set to `true` when `maestro hierarchy` returned nothing useful during the tour (see "Tour-time" edge cases). Authoring uses text/visible-wait fallbacks for screens with this flag rather than relying on the (empty) selector cache. Default `false`.
- **`selector.kind`** — one of `id` (testID / resource-id), `accessibility`, `text`, `regex`. Mirrors the priority order in `writing-flows.md`. No `coordinates` — refused by design.
- **`status` enum** — `pending` → `composed` → `verified` → `committed`, plus terminal states `skipped` and `failed`. Resume reads `status` to know which flows still need work.
- **Evidence path** — points into `.maestro/authoring-evidence/_tour/`. Tour screenshots live alongside per-flow ones, gitignored.
- **`last_run`** — appended on Phase 4 failures: `{ "timestamp": "...", "failed_step": "...", "reason": "..." }`. Resuming after a fix doesn't lose the diagnosis.
- **No full Maestro YAML in the schema.** YAML is generated from `screens` + `flows` on demand and lives in `<flow>.yaml` once `status >= composed`. Storing both would create drift.
```

- [ ] **Step 9: Write the coverage-checklist UX section**

```markdown
## Coverage checklist UX

The visible artefact during Phase 2 — the main lever against tour tedium. Re-rendered after every screen visit and after any user-issued state change (`add`, `skip`, `done`).

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

- **Three flow states** (`done` / `active` / `pending`) — compressed view of the JSON `status` field. User sees how far they are at a glance.
- **Screen-cache count** — visible proof selectors are being captured.
- **Always-visible exit hatches** — `done`, `skip`, `add <name>`, `stop`. User never has to wonder how to bail.
- **One concrete next instruction** — the user knows exactly what to do with the device.

Render cadence is roughly every 30-60 seconds during the tour. When a screen's hierarchy is genuinely ambiguous (two elements with the same label, or no stable selector), checklist render is suspended for one `AskUserQuestion` prompt then resumed. That ambiguity prompt is the only legitimate user-prompt during a screen visit; everything else is automatic.
```

- [ ] **Step 10: Write edge cases — tour-time**

```markdown
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
```

- [ ] **Step 11: Write edge cases — authoring-loop and cross-cutting**

```markdown
### Authoring-loop

| Case | Behaviour |
|---|---|
| Flow's first run fails after 3 debug iterations with no traction | Stop iterating. Mark `status: failed`, store last-run context, render a brief diagnosis ("hierarchy still shows X but flow expects Y"). Move on. User can revisit with `/authorflow <name>` later. |
| Env var resolution: user declines to provide a required value | Mark `status: skipped` with `last_run.reason: "missing_env"`. Move on — don't block the loop. |
| `run-flows.sh` reports device disconnected mid-run | `boot-sims.sh` → re-install (with original `install-app.sh` args) → retry once. If second attempt fails, three-strike rule applies. |
| User says `stop` mid-flow during composition or debug | Save current `status` honestly (`composed` if YAML written but not run, `pending` otherwise — never overstate). Plan persisted. Phase 5 partial report runs. Resume next session picks up at the same flow. |
| README write conflict with user's manual edits | Read README, find "Covered flows" section, append entries below the last one. If section doesn't exist, create it. Never rewrite existing entries. |

### Cross-cutting

- **Credentials boundary held.** Same rule as the rest of the skill: read shell env, prompt for missing with the "I won't store this" framing, forward via `--env`, never persist. Each flow's env is resolved at *its* run-time, not batched up front.
- **ASCII-only output** for any new bash output (per `CLAUDE.md`'s `[ok]/[warn]/[err]/[*]` convention).
- **UK English** in all written prose: `stabilise`, `behaviour`, `prioritise`, etc. The command name `/buildsuite` is fine.
- **Project-agnostic** language. No real app names, generic examples.

## Cross-references

- `authoring-flows.md` → "Project discovery (shared)" — the discovery logic Phase 1 reuses
- `authoring-flows.md` → "Phase D — Compose" / "Phase E — Run once" / "Phase F — Commit + index" — the per-flow conventions Phase 4 reuses
- `writing-flows.md` → "Picking the right selector" — the priority order Phase 2 applies automatically
- `troubleshooting.md` → Tier 0/1/2 — the failure-diagnosis ladder Phase 4 enters on a failed run
- `SKILL.md` → "Authoring flows" command table — the lifecycle table this command joins
```

- [ ] **Step 12: Verify the file is complete and correctly cross-referenced**

Run: `wc -l references/building-suites.md`

Expected: ~300-380 lines.

Run: `grep -n "^##" references/building-suites.md`

Expected: top-level headings appear in this order — `Building a flow suite`, `Lifecycle position`, `Refusal rules`, `Argument shape and platform resolution`, `The five phases`, `Plan schema (\`.tour-plan.json\`)`, `Coverage checklist UX`, `Edge cases and error handling`, `Cross-references`.

Run: `grep -n "${CLAUDE_PLUGIN_ROOT}" references/building-suites.md`

Expected: at least 2 matches (preflight + boot-sims in refusal rules; run-flows in deep-dive sequence). All script paths must use `${CLAUDE_PLUGIN_ROOT}/scripts/<name>.sh` form, never relative or absolute paths.

Run: `grep -ni "TBD\|TODO\|FIXME\|\?\?\?" references/building-suites.md || echo "[ok] no placeholders"`

Expected: `[ok] no placeholders`.

Run: `grep -i "stabilize\|stabilizing\|behavior\|color\|prioritize" references/building-suites.md || echo "[ok] UK English"`

Expected: `[ok] UK English` (US-English variants forbidden per `CLAUDE.md`).

- [ ] **Step 13: Commit**

```bash
git add references/building-suites.md
git commit -m "docs(refs): add building-suites.md depth doc for /buildsuite"
```

---

## Task 4: Write `commands/buildsuite.md`

Thin slash-command routing layer. Same shape as the existing three. Delegates to `references/building-suites.md`; does NOT inline phase logic.

**Files:**
- Create: `commands/buildsuite.md`

- [ ] **Step 1: Read the existing command files for format reference**

Run: `cat commands/initflow.md commands/authorflow.md commands/stabiliseflow.md`

Note the consistent shape:
- YAML frontmatter: `description`, `argument-hint`, `allowed-tools`
- Body: 1-2 lines stating user has invoked the command, then a delegation prose pointing at a specific section in a reference doc.

- [ ] **Step 2: Write `commands/buildsuite.md`**

Create the file with this exact content:

```markdown
---
description: Build a core suite of flows in one session — guided tour of the app, then per-flow authoring with checkpoints
argument-hint: [--platform ios|android] (optional — platform; defaults to whichever sim/emulator is booted)
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

The user has invoked `/buildsuite` to build a core flow suite from a guided tour of the running app.

Follow `references/building-suites.md` end-to-end. Summary of the five phases:

- **Phase 1 — Discover and confirm.** If `<project>/.maestro/` doesn't exist, stop and tell the user to run `/initflow` first. Otherwise, re-use project-discovery from `references/authoring-flows.md` → "Project discovery (shared)". Subtract flows already listed in the project's `<project>/.maestro/README.md` "Covered flows" section. Present the candidate list (with stubs from `/initflow` flagged as "will be overwritten") via `AskUserQuestion`; the user prunes / confirms.
- **Phase 2 — Guided tour.** Claude announces the next screen to visit; the user taps; Claude takes a screenshot, dumps `maestro hierarchy`, picks selectors automatically (priority order from `references/writing-flows.md`), and re-renders the coverage checklist. User directives: `done`, `skip`, `add <name>`, `stop`. Ask the user only on genuine selector ambiguity.
- **Phase 3 — Plan materialisation.** Write `<project>/.maestro/.tour-plan.json` per the schema in `references/building-suites.md` → "Plan schema". This is the persistence boundary — interrupted tours before this step are lost; after this step the user can resume in a new session.
- **Phase 4 — Authoring loop.** For each `pending` flow, ask `[yes / skip / stop]`. On `yes`, compose the YAML from cached selectors, resolve env vars (shell first, prompt for missing with "I won't store this"), run once via `${CLAUDE_PLUGIN_ROOT}/scripts/run-flows.sh`. On pass, update `status` and the README. On fail, enter Tier 0/1/2 debug from `references/troubleshooting.md`; **three-strike rule** — give up after three failed iterations with no traction, mark `failed`, move on.
- **Phase 5 — Index and report.** Append committed-flow entries to `<project>/.maestro/README.md`. Render the planned/committed/failed/skipped summary. Move `.tour-plan.json` → `.tour-plan.archive.json`. Suggest `/stabiliseflow <name>` for release-gate flows.

If `<project>/.maestro/.tour-plan.json` already exists with unfinished entries, ask whether to resume or discard. Default: resume — the plan is the persistence boundary.

If no device is booted at start, resolve platform per `references/building-suites.md` → "Argument shape and platform resolution", then run `${CLAUDE_PLUGIN_ROOT}/scripts/preflight.sh` and `${CLAUDE_PLUGIN_ROOT}/scripts/boot-sims.sh` before Phase 1.

Do NOT inline the phase details into this file — they live in `references/building-suites.md` for a reason. This file is a routing layer.
```

- [ ] **Step 3: Verify the frontmatter is valid and tooling matches the others**

Run: `head -5 commands/buildsuite.md`

Expected: `---` opening, then `description:`, `argument-hint:`, `allowed-tools:` lines, then `---` closing.

Run: `grep -A1 "^allowed-tools:" commands/buildsuite.md`

Expected: `Read, Write, Edit, Bash, Glob, Grep` — same toolset as `authorflow.md` and `initflow.md`.

- [ ] **Step 4: Verify the file does not duplicate phase logic from the reference**

Run: `wc -l commands/buildsuite.md`

Expected: roughly 30-40 lines. If it's >60, you've inlined too much — re-read the existing command files and trim.

- [ ] **Step 5: Commit**

```bash
git add commands/buildsuite.md
git commit -m "feat(commands): add /buildsuite slash command"
```

---

## Task 5: Update `skills/mobile-flow-runner/SKILL.md`

Add `/buildsuite` to the lifecycle commands table; add a one-paragraph orchestration note pointing at `building-suites.md`; mention `.tour-plan.json` as a runtime artefact.

**Files:**
- Modify: `skills/mobile-flow-runner/SKILL.md` (the "Authoring flows" section, currently around lines 142-156)

- [ ] **Step 1: Read the current "Authoring flows" section**

Run: `sed -n '142,172p' skills/mobile-flow-runner/SKILL.md`

Confirm the table at lines 146-150 has three rows (`/initflow`, `/authorflow`, `/stabiliseflow`).

- [ ] **Step 2: Add `/buildsuite` row to the lifecycle table**

Insert a new table row between `/initflow` and `/authorflow` (so the order matches typical user invocation: init → buildsuite → individual authoring → stabilise):

```markdown
| `/buildsuite` | After `/initflow`, when you want a real suite of flows fast | Guided tour — walks the running app once with the user, builds a shared selector + screen plan in `.tour-plan.json`, then loops over each planned flow with a per-flow checkpoint to compose, run, and commit. Reuses Phase D-F of `/authorflow` and the Tier 0/1/2 debug ladder for failed runs |
```

- [ ] **Step 3: Add an orchestration paragraph after the table**

After the existing line "The full process — phase definitions, auth-detection grep patterns, selector-priority order, screenshot/hierarchy capture commands, README template — lives in `references/authoring-flows.md`. **Read it before authoring**, do not improvise.", add this paragraph:

```markdown
For `/buildsuite` specifically, the depth doc is `references/building-suites.md` — five phases (Discover & confirm → Guided tour → Plan materialisation → Authoring loop → Index & report), the `.tour-plan.json` schema, the coverage-checklist UX, and the edge cases. Read it before invoking the command. `/buildsuite` shares project-discovery logic with `/initflow` (extracted under "Project discovery (shared)" in `authoring-flows.md`) and reuses Phase D-F conventions from `/authorflow` for the per-flow deep dives.
```

- [ ] **Step 4: Add `.tour-plan.json` to the artefacts mention**

The current SKILL.md doesn't have a single "artefacts list", but the "Authoring evidence" section under "Authoring flows" mentions `<project>/.maestro/authoring-evidence/<flow>/`. Append a new subsection just below it:

```markdown
### Tour plan

`/buildsuite` writes its working plan to `<project>/.maestro/.tour-plan.json` between Phase 3 and Phase 5. The file is the persistence boundary for tour-derived data — once written, the user can quit and resume in a new session via `/buildsuite` (which detects an unfinished plan and offers to resume). On successful Phase 5 completion the plan is moved to `.tour-plan.archive.json` so a future invocation starts clean. Both files are gitignored. Schema in `references/building-suites.md` → "Plan schema".
```

- [ ] **Step 5: Verify the changes**

Run: `git diff skills/mobile-flow-runner/SKILL.md`

Sanity check: only additions (one new table row, one new paragraph after the existing reference, one new subsection); no edits to existing prose.

Run: `grep -c "/buildsuite" skills/mobile-flow-runner/SKILL.md`

Expected: 4 mentions (table row + orchestration paragraph + tour-plan subsection + the cross-reference in the orchestration paragraph). Adjust the assertion to the exact count after editing.

- [ ] **Step 6: Commit**

```bash
git add skills/mobile-flow-runner/SKILL.md
git commit -m "docs(skill): wire /buildsuite into SKILL.md orchestration"
```

---

## Task 6: Update lifecycle table + cross-reference in `references/authoring-flows.md`

Add `/buildsuite` to the lifecycle table at the top of `authoring-flows.md`, and a one-paragraph cross-reference pointing at `building-suites.md`. Don't duplicate any content.

**Files:**
- Modify: `references/authoring-flows.md` (table near top — see step 1 to find exact lines after Task 2's refactor)

- [ ] **Step 1: Find the lifecycle table**

Run: `grep -n "Command \| When \| Phase" references/authoring-flows.md` (or whatever the table header text is — confirm by reading the top of the file).

Open the file at that area. The table is in the intro before "## Project discovery (shared)" (added by Task 2).

- [ ] **Step 2: Add the `/buildsuite` row to the table**

Insert a new row between `/initflow` and `/authorflow`:

```markdown
| `/buildsuite` | After init, when you want a working suite of flows fast | One guided tour → N flows authored sequentially with per-flow checkpoints |
```

- [ ] **Step 3: Add a one-paragraph cross-reference paragraph below the table**

After the table, add (or extend an existing intro paragraph with):

```markdown
For `/buildsuite` — the multi-flow tour-then-author lifecycle — see `building-suites.md`. It reuses the project-discovery logic below (Phase 1 of `/buildsuite`) and the per-flow Compose/Run/Commit conventions from `/authorflow` (Phase 4 of `/buildsuite`).
```

- [ ] **Step 4: Verify the table now has four rows and the cross-ref renders**

Run: `grep -A6 "^| Command" references/authoring-flows.md`

Expected: a four-row table. Order: `/initflow`, `/buildsuite`, `/authorflow`, `/stabiliseflow`.

Run: `grep -c "building-suites.md" references/authoring-flows.md`

Expected: at least 1 match.

- [ ] **Step 5: Commit**

```bash
git add references/authoring-flows.md
git commit -m "docs(refs): add /buildsuite to lifecycle table and cross-reference"
```

---

## Task 7: Update `commands/initflow.md` to gitignore tour-plan paths

`/initflow` currently writes `.maestro/artifacts/` and `.maestro/authoring-evidence/` to the project's `.gitignore`. It now also needs to write the two new tour-plan paths so subsequent `/buildsuite` runs don't accidentally commit the plan.

**Files:**
- Modify: `commands/initflow.md` (line 27 area)
- Modify: `references/authoring-flows.md` (the gitignore block in the "Init phase" section's scaffolding step — line ~55-59 area)

- [ ] **Step 1: Read the current gitignore step in `commands/initflow.md`**

Run: `grep -n "gitignore" commands/initflow.md`

Expected: a single match around line 27: `Update \`.gitignore\` if needed: add \`.maestro/artifacts/\` and \`.maestro/authoring-evidence/\`.`

- [ ] **Step 2: Update the line to include the two new entries**

Edit `commands/initflow.md` line 27. Replace:

```
6. **Update `.gitignore`** if needed: add `.maestro/artifacts/` and `.maestro/authoring-evidence/`.
```

With:

```
6. **Update `.gitignore`** if needed: add `.maestro/artifacts/`, `.maestro/authoring-evidence/`, `.maestro/.tour-plan.json`, and `.maestro/.tour-plan.archive.json`.
```

- [ ] **Step 3: Read the matching section in `references/authoring-flows.md`**

Run: `grep -n -A3 "Append to.*gitignore" references/authoring-flows.md`

Expected: a code block listing the gitignore entries.

- [ ] **Step 4: Update the gitignore code block**

Edit `references/authoring-flows.md`. Find the block:

```
.maestro/artifacts/
.maestro/authoring-evidence/
```

Replace with:

```
.maestro/artifacts/
.maestro/authoring-evidence/
.maestro/.tour-plan.json
.maestro/.tour-plan.archive.json
```

- [ ] **Step 5: Verify**

Run: `grep -A4 "Append to.*gitignore" references/authoring-flows.md`

Expected: all four entries present in the code block.

Run: `grep "tour-plan" commands/initflow.md`

Expected: 1 match in the line you edited.

- [ ] **Step 6: Commit**

```bash
git add commands/initflow.md references/authoring-flows.md
git commit -m "feat(commands): /initflow writes tour-plan paths to project gitignore"
```

---

## Task 8: Update `references/maestro-readme-template.md`

The template generates the project's `.maestro/README.md`. If the template enumerates files that live under `.maestro/`, add a brief mention of `.tour-plan.json` so future contributors aren't confused by it appearing.

**Files:**
- Modify: `references/maestro-readme-template.md` (only if it lists `.maestro/` files; skip otherwise)

- [ ] **Step 1: Inspect the template**

Run: `cat references/maestro-readme-template.md`

Look for: any list of files in `.maestro/`, any "Files in this directory" section, or any mention of `artifacts/` or `authoring-evidence/`.

- [ ] **Step 2: Decide whether an edit is needed**

- If the template **does** enumerate `.maestro/` contents, add this entry alongside `artifacts/` and `authoring-evidence/`:
  ```markdown
  - **`.tour-plan.json` / `.tour-plan.archive.json`** — transient working state from `/buildsuite`. Gitignored. Safe to delete; will be regenerated by the next tour.
  ```
- If the template **does not** enumerate `.maestro/` contents, skip the edit and write a one-line commit-skip note:
  ```
  [skip] template doesn't enumerate .maestro/ files; no edit needed.
  ```

- [ ] **Step 3: Verify (only if edited)**

Run: `grep "tour-plan" references/maestro-readme-template.md`

Expected: 1 match.

- [ ] **Step 4: Commit (only if edited)**

```bash
git add references/maestro-readme-template.md
git commit -m "docs(template): mention .tour-plan.json in project README template"
```

If skipped: no commit, move on to Task 9.

---

## Task 9: Update top-level `README.md`

Add `/buildsuite` to the lifecycle commands list with a one-liner.

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Find the lifecycle commands section in the README**

Run: `grep -n "/initflow\|/authorflow\|/stabiliseflow" README.md`

Identify the bullet list (or table) where the commands are introduced.

- [ ] **Step 2: Add the `/buildsuite` entry**

Insert between `/initflow` and `/authorflow`:

```markdown
- **`/buildsuite`** — after `/initflow`, build a core suite of flows in one session via a guided tour of the app + per-flow authoring checkpoints. See `commands/buildsuite.md`.
```

(Match the bullet/table format of the existing entries — adjust prose accordingly.)

- [ ] **Step 3: Verify**

Run: `grep -n "/buildsuite" README.md`

Expected: 1 match in the lifecycle list.

- [ ] **Step 4: Commit**

```bash
git add README.md
git commit -m "docs(readme): add /buildsuite to lifecycle commands"
```

---

## Task 10: Update `CHANGELOG.md` with `[Unreleased]` entry

Add an entry under `[Unreleased]` → `Added` describing the new command and the plan format. **Do not bump `version` in `plugin.json`** — release happens separately per the project's release discipline (see `CLAUDE.md` → "Release process").

**Files:**
- Modify: `CHANGELOG.md`

- [ ] **Step 1: Read the current `[Unreleased]` block**

Run: `sed -n '/## \[Unreleased\]/,/## \[/p' CHANGELOG.md | head -40`

Confirm the section exists with subsections like `Added`, `Changed`, `Fixed` (Keep a Changelog format).

If `[Unreleased]` is missing, add it at the top of the changelog above the most recent release entry.

- [ ] **Step 2: Append entries under `Added`**

Add to `[Unreleased]` → `Added`:

```markdown
- `/buildsuite` slash command — fourth lifecycle command for building a core suite of flows in a single session. Walks the running app once with the user (a guided tour), builds a shared selector + screen plan persisted to `<project>/.maestro/.tour-plan.json`, then loops over each planned flow with a per-flow `[yes / skip / stop]` checkpoint to compose, run, and commit. Reuses `/initflow`'s project-discovery logic and `/authorflow`'s Phase D-F conventions. Full design in `docs/superpowers/specs/2026-04-30-buildsuite-design.md`; depth doc in `references/building-suites.md`.
- `references/building-suites.md` — depth doc for `/buildsuite` (five phases, plan schema, coverage-checklist UX, edge cases).
- `references/authoring-flows.md` — extracted "Project discovery (shared)" section reused by `/initflow` and `/buildsuite`.
```

If there's a `Changed` subsection (or it makes sense to add one), also note:

```markdown
- `/initflow` now writes `.maestro/.tour-plan.json` and `.maestro/.tour-plan.archive.json` to the project's `.gitignore` alongside the existing `artifacts/` and `authoring-evidence/` entries.
```

- [ ] **Step 3: Verify**

Run: `grep -A20 "## \[Unreleased\]" CHANGELOG.md`

Expected: the new entries appear under `Added` (and `Changed` if you used it).

- [ ] **Step 4: Commit**

```bash
git add CHANGELOG.md
git commit -m "docs(changelog): add /buildsuite Unreleased entry"
```

---

## Task 11: End-to-end validation against a real project

There are no unit tests in this repo by design (per `CLAUDE.md`). Validation is end-to-end against a real mobile project. Run through the full new flow at least once before considering this work shippable.

**Files:**
- None modified — verification only.

- [ ] **Step 1: Confirm the full diff is clean and self-consistent**

Run: `git log --oneline main.. | head -20`

Expected: ~10 commits with conventional-commit messages: `chore`, `refactor`, `docs`, `feat`. No `wip` or `tmp` commits.

Run: `git diff main..HEAD --stat`

Expected: only the files listed in the "File structure" table at the top of this plan; nothing else touched.

- [ ] **Step 2: Local-install the plugin into Claude Code**

Run (in a separate Claude Code session, per `CLAUDE.md` validation workflow):

```bash
claude --plugin-dir ~/dev/mobile-flow-runner
```

Verify in that session:
- `/buildsuite` appears in the slash-command list (autocomplete).
- `/initflow`, `/authorflow`, `/stabiliseflow` still appear unchanged.
- The skill triggers normally on natural-language prompts ("smoke test the iOS build") — the SKILL.md frontmatter is unchanged so this should work as before.

- [ ] **Step 3: Run `/buildsuite` against a sample Expo project**

Pick or create a small Expo project with a `.maestro/` directory already scaffolded by `/initflow` (so refusal rule 1 doesn't fire). The project should have at minimum: a launch screen, a login screen with `testID`s on `email_input` / `password_input` / a submit button, and one post-login screen.

In the Claude Code session against that project, run:

```
/buildsuite --platform ios
```

Walk through:
- Phase 1 — confirm Claude proposes a candidate list (app-launch, login, plus any per-route candidates).
- Phase 2 — drive the device manually as Claude prompts. Confirm the coverage checklist re-renders after every screen visit. Confirm `add <name>` and `skip` directives work.
- Phase 3 — confirm `<project>/.maestro/.tour-plan.json` is written. Inspect it manually:
  ```bash
  cat <project>/.maestro/.tour-plan.json | jq .
  ```
  Expected: matches the schema in `references/building-suites.md` (schema_version 1, screens dict, flows array with `status: pending`).
- Phase 4 — accept the first flow with `yes`, watch it compose + run + commit. Reject the second with `skip`. Stop after the third with `stop`.
- Phase 5 — confirm the final summary renders, README is updated for committed flows, and `.tour-plan.archive.json` is created (only on natural completion, not after `stop`).

- [ ] **Step 4: Validate the resume path**

In the same project:

```
/buildsuite
```

Expected: refusal rule 2 fires — Claude detects the unfinished `.tour-plan.json` (because we `stop`ped in step 3 before all flows were authored) and asks resume vs. start over. Choose resume; confirm Claude picks up at the next `pending` flow.

- [ ] **Step 5: Validate the credentials boundary**

If a flow needs `MAESTRO_USERNAME` / `MAESTRO_PASSWORD`:

- Run with neither set in the shell. Confirm Claude prompts via `AskUserQuestion` with the "I won't store this" framing.
- After the run, confirm:
  ```bash
  grep -r "MAESTRO_USERNAME\|MAESTRO_PASSWORD" <project>/.maestro/
  ```
  Returns no matches in `.tour-plan.json` or any committed YAML — only the variable *names* should appear, never values.

- [ ] **Step 6: Spot-check the documentation cross-references**

Run from this repo:

```bash
grep -l "building-suites.md" SKILL.md commands/ references/ README.md
grep -l "authoring-flows.md" SKILL.md commands/ references/ README.md
```

Expected: cross-references resolve. No broken links.

Run:

```bash
for f in commands/buildsuite.md references/building-suites.md; do
  echo "=== $f ==="
  grep -n "{CLAUDE_PLUGIN_ROOT}" "$f" || echo "(no script refs)"
done
```

Expected: every script invocation uses `${CLAUDE_PLUGIN_ROOT}/scripts/<name>.sh` form, never relative or absolute paths.

- [ ] **Step 7: Update CHANGELOG with the validation env**

Edit `CHANGELOG.md` `[Unreleased]` block — append to the existing `Added` entry (or add a new `Validated` subsection at the bottom of `[Unreleased]`):

```markdown
**Validated** against an Expo SDK <X> project on iOS <Y> with Maestro <Z>, running `/buildsuite --platform ios` end-to-end through Phase 5. Resume path verified by `stop`ping mid-Phase 4 and re-invoking. Credentials boundary verified — no env values appear in `.tour-plan.json`.
```

Substitute the actual SDK / iOS / Maestro versions you tested with.

- [ ] **Step 8: Final commit**

```bash
git add CHANGELOG.md
git commit -m "docs(changelog): record /buildsuite validation env"
```

- [ ] **Step 9: Confirm the branch is ready to ship (do not tag yet)**

Run: `git log --oneline main..HEAD`

Expected: ~11 commits in lifecycle order. Tagging + version bump + push are out of scope for this plan — they happen at release time per `CLAUDE.md` "Release process".

---

## Self-review notes

After implementation, do a final pass:

1. **Spec coverage:** every section of the spec at `docs/superpowers/specs/2026-04-30-buildsuite-design.md` is reachable from the docs landed by this plan? In particular:
   - Lifecycle position table → Task 5 (SKILL.md) + Task 6 (authoring-flows.md) + Task 9 (README.md). ✓
   - Refusal rules → Task 3 (building-suites.md) + Task 4 (commands/buildsuite.md). ✓
   - Argument shape and platform resolution → Task 3 + Task 4. ✓
   - Five phases → Task 3. ✓
   - Plan schema → Task 3. ✓
   - Coverage checklist UX → Task 3. ✓
   - File layout → all of Tasks 1-10. ✓
   - Edge cases → Task 3. ✓
2. **Type/name consistency:** `selector.kind` values (`id`, `accessibility`, `text`, `regex`); `status` values (`pending`, `composed`, `verified`, `committed`, `skipped`, `failed`); user directives (`done`, `skip`, `add <name>`, `stop`); `[yes / skip / stop]` for the per-flow gate — used identically across the spec, the depth doc (Task 3), and the command file (Task 4). Re-grep to confirm nothing drifted.
3. **No placeholders:** scan every `references/building-suites.md` and `commands/buildsuite.md` paragraph for `TBD`, `TODO`, `???`, `<...>` placeholders. (`<project>`, `<flow>`, `<name>`, `<udid-or-serial>` are intentional template variables — leave them.)
