---
description: Author a new Maestro flow via a guided phased loop — interview, walk the screens, compose, run, commit
argument-hint: [flow-name] (optional — flow name like "login" or "checkout"; if omitted, the interview asks)
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

The user has invoked `/authorflow` to author a new Maestro flow.

Argument: `$1` is the proposed flow name (e.g. `login`, `checkout`, `view-list`). If empty, ask during the interview.

Follow the **phased authoring loop** in `references/authoring-flows.md`. Summary:

- **Phase A — Discover.** If `<project>/.maestro/` doesn't exist, stop and tell the user to run `/initflow` first. Otherwise, read existing flows + the project's screen files to build context.
- **Phase B — Interview.** `AskUserQuestion`: which flow (if not given), the journey in plain English, the start state, the success criterion. Keep questions tight but don't sacrifice clarity.
- **Phase C — Walk the screens.** Booted sim/emulator must be ready (run `/initflow`'s preflight if not). For each step in the journey:
  1. Drive the app to the relevant screen (manual taps via the user, or automated via Maestro from prior steps).
  2. Take **one** screenshot (`xcrun simctl io booted screenshot <path>` for iOS, `adb exec-out screencap -p > <path>` for Android), saving to `<project>/.maestro/authoring-evidence/<flow-name>/<step-name>.png`.
  3. Run `maestro --device <udid-or-serial> hierarchy | jq '.. | objects | {text, "resource-id", "accessibility-label", enabled} | select(.text or ."resource-id" or ."accessibility-label")'` to inspect selectors as text.
  4. Pick the most stable selector (testID > accessibility-label > text > coordinates). Note *why* it was chosen.
- **Phase D — Compose.** Write `<project>/.maestro/<flow-name>.yaml` with `appId: ${APP_ID}`, the picked selectors, and a header comment per step naming the screen and the user's intent. Use `references/flow-examples/` as a template if relevant.
- **Phase E — Run once.** Invoke `${CLAUDE_PLUGIN_ROOT}/scripts/run-flows.sh --flows <project>/.maestro/<flow-name>.yaml --platform <p>`. **One-run stability bar** — if it passes, ship it. If it fails, drop into the Tier 0/1/2 debug protocol from `references/troubleshooting.md` and iterate.
- **Phase F — Commit + index.** Update `<project>/.maestro/README.md` with the new flow's entry (journey summary, env vars required, gotchas). Mention to the user they can later run `/stabiliseflow $1` to verify it's not flaky before relying on it for releases.

Do NOT skip Phase C's hierarchy step in favour of just guessing selectors. Picking the right selector first time avoids debug churn.
