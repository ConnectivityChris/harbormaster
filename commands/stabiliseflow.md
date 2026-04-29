---
description: Run an existing flow N times consecutively to detect flakiness — defaults to 3 runs
argument-hint: [flow-path] [run-count] (run-count optional, defaults to 3)
allowed-tools: Read, Bash, Glob
---

The user has invoked `/stabiliseflow` to harden an existing flow.

Arguments:
- `$1` — flow path or name (e.g. `login.yaml`, or just `login`). Resolve relative to `<project>/.maestro/`.
- `$2` — run count, defaults to **3** if omitted. Override accepted (e.g. `/stabiliseflow login 5`).

Procedure:

1. **Resolve the flow path.** If `$1` doesn't end in `.yaml`, append it. If the path doesn't exist under `<project>/.maestro/`, error and tell the user.

2. **Confirm the bar.** Tell the user: "Running `<flow>` <N> consecutive times. Pass = all <N> succeed; fail = any single failure."

3. **Run N times.** Invoke `${CLAUDE_PLUGIN_ROOT}/scripts/run-flows.sh` once per run, each with a distinct `--output` directory (`<project>/.maestro/artifacts/stabilise-<run-id>/run-<n>/`). Don't parallelise — flakiness often comes from shared device state, and parallel runs confound the diagnosis.

4. **Track results.** After each run record: pass/fail, wall-clock duration, and (on failure) the failed step.

5. **Report.**
   - **All passed**: tell the user the flow is stable across <N> runs and report the duration spread (min/max/mean). Suggest they commit it as a smoke flow.
   - **Some failed**: report the pass count (e.g. "2/3 passed"), enumerate which runs failed and at which step, and diagnose the flakiness using the Tier 0/1 debug protocol from `references/troubleshooting.md`. Common causes: race conditions on button transitions (see `references/writing-flows.md` → "Buttons that vanish mid-transition"), missing `extendedWaitUntil` on slow loads, `clearState` interaction with Expo Go cold-bundle compile.

6. **Suggest fixes.** Don't just report failures — propose concrete YAML changes (e.g. "wrap the submit tap in `runFlow: when: visible:` to handle the spinner-replace race"). If the user accepts, apply the fix and offer to re-run the stabilise loop.

Do NOT modify the flow without the user's say-so. Suggestions are for review.
