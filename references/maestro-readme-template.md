# Maestro README template

Fixed template for `<project>/.maestro/README.md`. `/initflow` writes this file with project-specific values substituted. `/authorflow` appends to the "Covered flows" section as new flows land.

Substitution placeholders use `{{NAME}}` — Claude replaces these at scaffold time. Don't ship `{{...}}` placeholders to the user; replace or remove every one.

---

```markdown
# {{PROJECT_NAME}} — Maestro flows

Regression UI flows for {{PROJECT_NAME}}. Driven by [Maestro](https://maestro.mobile.dev) via the [mobile-flow-runner](https://github.com/ConnectivityChris/mobile-flow-runner) Claude Code skill.

## When to run these

Before pushing a build to TestFlight, App Store internal track, or Play Store internal track. Optionally before merging a PR that touches mobile UI.

## Running

Easiest path — invoke the skill from Claude Code:

> Smoke test the iOS build

For manual runs:

\`\`\`bash
# iOS, from project root
maestro --device <udid> test .maestro/

# Android
maestro --device <emulator-serial> test .maestro/

# Single flow
maestro test .maestro/login.yaml
\`\`\`

## Configuration

`.maestro/config.json` holds project defaults — bundleId, package, preferred device, dev build paths. Edit there rather than per-flow.

## Environment variables

Flows read sensitive values from the shell environment, never from a committed file. Set these before running auth-dependent flows:

| Variable | Used by | Purpose |
|---|---|---|
| `APP_ID` | all flows | iOS bundleId or Android package — usually substituted automatically |
| `MAESTRO_USERNAME` | `login.yaml` | login email |
| `MAESTRO_PASSWORD` | `login.yaml` | login password |
| `HOME_SCREEN_TEXT` | post-login flows | text that confirms successful navigation to home |
| `PROJECT_URL` | Expo Go only | dev server URL, e.g. `exp://192.168.1.10:8081` |

The skill prompts for missing values at run time. For persistent setup, export in your shell rc or use `direnv` with a gitignored `.envrc`.

## Covered flows

Each entry below names the user journey, required env, and any project-specific gotchas. Keep this list current as flows change.

### app-launch.yaml
- **Journey**: app launches and reaches the first interactive screen
- **Tags**: `smoke`
- **Env**: none
- **Gotchas**: none

<!-- /authorflow appends new entries here as flows are added -->

## Authoring a new flow

Use `/authorflow <flow-name>` from Claude Code. The skill walks through interview → screen capture → selector picking → compose → run, then appends an entry to this README.

For the full process, see the [authoring-flows reference](https://github.com/ConnectivityChris/mobile-flow-runner/blob/main/references/authoring-flows.md).

## Stabilising before release

After authoring, run `/stabiliseflow <flow>` to verify stability across multiple runs (default 3). Stabilisation is the gate before adding a flow to a release-blocking smoke set — a flow that passes once but fails one in three runs will block releases for the wrong reasons.

## Artifacts

Test runs write screenshots, video, and JUnit XML to `.maestro/artifacts/<run-id>/`. Authoring evidence (Phase C screenshots) lives at `.maestro/authoring-evidence/<flow>/`. Both are gitignored by default.
```

---

## Substitution variables

Claude must replace these when scaffolding the README:

| Placeholder | Source | Example |
|---|---|---|
| `{{PROJECT_NAME}}` | `app.json` `expo.name` or `package.json` `name` | `acme-mobile` |

Add new placeholders here when extending the template; do not introduce ad-hoc substitutions.
