---
description: Build a core suite of flows in one session — guided tour of the app, then per-flow authoring with checkpoints
argument-hint: [--platform ios|android] (optional — platform; defaults to whichever sim/emulator is booted)
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

The user has invoked `/buildsuite` to build a core flow suite from a guided tour of the running app.

Follow `references/building-suites.md` end-to-end. Summary of the five phases:

- **Phase 1 — Discover and confirm.** If `<project>/.maestro/` doesn't exist, stop and tell the user to run `/initflow` first. Otherwise, re-use project-discovery from `references/authoring-flows.md` → "Project discovery (shared)". Subtract flows already listed in `<project>/.maestro/README.md` "Covered flows" section. Present the candidate list (with stubs from `/initflow` flagged as "will be overwritten") via `AskUserQuestion`; the user prunes / confirms.
- **Phase 2 — Guided tour.** Claude announces the next screen to visit; the user taps; Claude takes a screenshot, dumps `maestro hierarchy`, picks selectors automatically (priority order from `references/writing-flows.md`), and re-renders the coverage checklist. User directives: `done`, `skip`, `add <name>`, `stop`. Ask the user only on genuine selector ambiguity.
- **Phase 3 — Plan materialisation.** Write `<project>/.maestro/.tour-plan.json` per the schema in `references/building-suites.md` → "Plan schema". This is the persistence boundary — interrupted tours before this step are lost; after this step the user can resume in a new session.
- **Phase 4 — Authoring loop.** For each `pending` flow, ask `[yes / skip / stop]`. On `yes`, compose the YAML from cached selectors, resolve env vars (shell first, prompt for missing with "I won't store this"), run once via `${CLAUDE_PLUGIN_ROOT}/scripts/run-flows.sh`. On pass, update `status` and the README. On fail, enter Tier 0/1/2 debug from `references/troubleshooting.md`; **three-strike rule** — give up after three failed iterations with no traction, mark `failed`, move on.
- **Phase 5 — Index and report.** Append committed-flow entries to `<project>/.maestro/README.md`. Render the planned/committed/failed/skipped summary. Move `.tour-plan.json` → `.tour-plan.archive.json`. Suggest `/stabiliseflow <name>` for release-gate flows.

If `<project>/.maestro/.tour-plan.json` already exists with unfinished entries, ask whether to resume or discard. Default: resume — the plan is the persistence boundary.

If no device is booted at start, resolve platform per `references/building-suites.md` → "Argument shape and platform resolution", then run `${CLAUDE_PLUGIN_ROOT}/scripts/preflight.sh` and `${CLAUDE_PLUGIN_ROOT}/scripts/boot-sims.sh` before Phase 1.

Do NOT inline the phase details into this file — they live in `references/building-suites.md` for a reason. This file is a routing layer.
