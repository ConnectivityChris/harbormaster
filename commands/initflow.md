---
description: Bootstrap a project for mobile-flow-runner — scaffolds .maestro/ directory, config, README, and starter flows
argument-hint: (no arguments)
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

The user has invoked `/initflow` to bootstrap mobile testing for this project.

Run the **init phase** of the mobile-flow-runner skill — a one-time setup that scaffolds the project's `.maestro/` directory. Do this once per project; for adding individual flows after init, the user invokes `/authorflow` instead.

Follow `references/authoring-flows.md` → "Init phase" for the full procedure. Summary:

1. **Refuse to re-init.** If `<project>/.maestro/` already exists, stop and tell the user to use `/authorflow` to add a new flow instead. Do not overwrite an existing setup.

2. **Discover the project.** Read `app.json`, `app.config.ts|js`, `package.json`, and skim the route/screen directory (`app/` for Expo Router, `screens/` for classic). Build a candidate list of likely flows.

3. **Detect auth.** Grep for the patterns in `references/authoring-flows.md` → "Auth detection". If positive, plan to scaffold `login.yaml`. If not, skip it.

4. **Confirm with the user.** Use `AskUserQuestion` to confirm: bundleId, package, scaffolded flows. Let them opt out of any individual flow.

5. **Scaffold.** Write to `<project>/.maestro/`:
   - `config.json` — the **skill's** config (bundleId, devBuildPath, preferredDevice). Populated from discovered values.
   - `config.yaml` — the **Maestro workspace** config. Copy from `references/flow-examples/config.yaml`. Two different files with overlapping names; both belong here.
   - `README.md` — using the template at `references/maestro-readme-template.md`, with project-specific values substituted
   - `app-launch.yaml` — copied from `references/flow-examples/app-launch.yaml`, `appId` substituted
   - `login.yaml` — copied from `references/flow-examples/login.yaml`, `appId` substituted (only if auth detected)

6. **Update `.gitignore`** if needed: add `.maestro/artifacts/`, `.maestro/authoring-evidence/`, `.maestro/.tour-plan.json`, and `.maestro/.tour-plan.archive.json`.

7. **Suggest next steps.** Tell the user: scaffolded flows are stubs and need their app's actual selectors. Recommend running `/authorflow` to walk through customising one, starting with `app-launch`.

Do NOT run any flow during init — scaffolding only. Running comes later.
