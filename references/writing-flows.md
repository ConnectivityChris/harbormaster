# Writing Maestro flows

A focused cheat sheet for the Maestro YAML commands you actually need for regression flows. For the full reference, see https://docs.maestro.dev.

## Anatomy

Every flow file starts with config, then `---`, then a list of commands.

```yaml
appId: com.example.app    # iOS bundle ID or Android package
tags:                     # optional — filter with --include-tags / --exclude-tags
  - smoke
---
- launchApp
- assertVisible: "Welcome"
```

For cross-platform flows, parameterise the `appId`:

```yaml
appId: ${APP_ID}
---
- launchApp
```

Then run with `maestro test -e APP_ID=com.example.app flow.yaml`.

## Selectors

Maestro picks elements by visible text by default. You can also match by ID, accessibility label, or coordinate (avoid coordinates).

```yaml
- tapOn: "Login"                     # text
- tapOn:
    id: "login_button"               # testID (RN) or resource-id (Android)
- tapOn:
    text: "Sign in"
    enabled: true
- tapOn:
    point: "50%,90%"                 # last resort
```

## The commands you'll use 80% of the time

```yaml
# Launch / lifecycle
- launchApp
- launchApp:
    clearState: true                 # wipe app state first
- stopApp
- killApp

# Tapping and typing
- tapOn: "Continue"
- doubleTapOn: "Avatar"
- longPressOn: "Message"
- inputText: "hello@example.com"
- eraseText: 5                       # delete last N chars
- hideKeyboard

# Assertions
- assertVisible: "Inbox"
- assertVisible:
    text: "3 new messages"
- assertNotVisible: "Loading"

# Waiting
- waitForAnimationToEnd
- extendedWaitUntil:
    visible: "Inbox"
    timeout: 10000                   # ms

# Navigation
- back                               # Android back / iOS swipe
- scroll                             # one screen down
- scrollUntilVisible:
    element: "Settings"
    direction: DOWN

# Swipe
- swipe:
    from: "Item to delete"
    direction: LEFT

# Screenshots
- takeScreenshot: home-screen        # saved alongside artifacts
```

## Env vars

Reference env vars with `${VAR}`:

```yaml
appId: com.example.app
---
- launchApp
- tapOn: "Sign in"
- inputText: ${USERNAME}
- tapOn: "Next"
- inputText: ${PASSWORD}
- tapOn: "Log in"
```

Pass them in via `--env KEY=VALUE` (the `run-flows.sh` script forwards `--env` args through).

## Composing flows

Use `runFlow` to chain shared sub-flows:

```yaml
appId: com.example.app
---
- runFlow: ../shared/login.yaml
- tapOn: "Settings"
- assertVisible: "Account"
```

## Conditional and retry

```yaml
- runFlow:
    when:
      visible: "Allow notifications?"
    commands:
      - tapOn: "Allow"

- retry:
    maxRetries: 3
    commands:
      - tapOn: "Refresh"
      - assertVisible: "Inbox"
```

## Tips for non-flaky flows

1. **Prefer text and accessibility-label selectors over IDs**, and IDs over coordinates. Coordinates are screen-size-dependent and brittle.
2. **In React Native**, set `accessibilityLabel` on critical elements rather than relying on text — text can change with copy edits.
3. **Wait for animations** explicitly (`waitForAnimationToEnd`) rather than sleeping.
4. **Use `extendedWaitUntil`** for slow loads instead of `assertVisible` immediately after a network action.
5. **Wipe state at the start** of any flow that depends on a clean slate (`launchApp: { clearState: true }`).
6. **Use tags** (`tags: [smoke]`) so `--include-tags=smoke` runs only the fast set in the local loop.

## Inspecting your app

To find selectors interactively:

```bash
maestro studio
```

This opens a browser at the running app and lets you hover over elements to copy selectors.
