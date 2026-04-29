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
2. **In React Native, use regex text selectors** — see the next section.
3. **Wait for animations** explicitly (`waitForAnimationToEnd`) rather than sleeping.
4. **Use `extendedWaitUntil`** for slow loads instead of `assertVisible` immediately after a network action.
5. **Wipe state at the start** of any flow that depends on a clean slate (`launchApp: { clearState: true }`) — but see [Expo Go gotchas](#expo-go-gotchas) below.
6. **Use tags** (`tags: [smoke]`) so `--include-tags=smoke` runs only the fast set in the local loop.

## React Native + Maestro: the `accessibilityText` gotcha

React Native on iOS bundles all child `Text` content into the parent view's combined `accessibilityText` for VoiceOver. So a login screen with separate `<Text>Email</Text>` and `<Text>Password</Text>` exposes a single parent element with:

```
accessibilityText = "Log In, Email, happi@example.com, Password, *********, Forgot your password?, ..."
```

Maestro's exact `text` matcher won't find the discrete word `"Email"` as a leaf element under that parent. **Use regex selectors against `text`** — they match the combined string:

```yaml
# WRONG — exact match against a leaf 'Email' element that doesn't exist
- assertVisible: "Email"

# RIGHT — regex match against any visible text containing 'Email'
- assertVisible:
    text: ".*Email.*"
```

For uniqueness, prefer slightly longer substrings:

```yaml
- assertVisible:
    text: ".*Forgot your password.*"
```

## React Native + Maestro: making `testID` actually work

`testID` is the right primary selector for tappable elements — it's deterministic and immune to layout shifts. But there's a subtlety on RN/iOS:

| Component | Does `testID` get exposed to Maestro? |
|---|---|
| `<Pressable>`, `<Button>` (custom Pressable-based) | **Yes** — these are already discrete accessibility elements |
| `<TextInput>` | **No, by default** — gets swallowed into the parent's bundled `accessibilityText` |

The fix for `TextInput`: wrap it in a `<View accessible testID="...">`. The `accessible` prop forces that View to be a single accessibility node, exposing the `testID` as a `resource-id` Maestro can match.

**Don't put testID directly on FormTextInput / Input / TextInput** — wrap it:

```tsx
// WRONG — testID is silently dropped from Maestro's view
<FormTextInput
  name="email"
  testID="email_input"
  ...
/>

// RIGHT — wrapper View becomes the discrete accessibility element
<View accessible testID="email_input">
  <FormTextInput
    name="email"
    ...
  />
</View>
```

Then in the flow:

```yaml
- tapOn:
    id: "email_input"
- inputText: ${MAESTRO_USERNAME}
```

Verify by running `maestro hierarchy` after a project reload — your testIDs should appear as `resource-id` entries.

## Buttons that vanish mid-transition

A `<Button>` whose label switches to a `<Spinner>` while submitting (typical for login / save / submit) can momentarily lose its testID from the accessibility tree as the children swap. If your flow has:

```yaml
- tapOn:
    id: "login_submit"
- extendedWaitUntil:
    visible: ...
```

…and the form auto-submits on keyboard return (or is a fast network), Maestro can race the transition and report "Element not found" when really the action succeeded. Make the tap optional:

```yaml
- runFlow:
    when:
      visible:
        id: "login_submit"
    commands:
      - tapOn:
          id: "login_submit"

- extendedWaitUntil:
    visible: ...
```

The flow asserts the *outcome* (navigated to home), not the *interaction* (tap occurred), which is what you actually care about.

## Expo Go gotchas

Running flows against an app loaded inside Expo Go (rather than a native dev build) has two specific traps:

### 1. `launchApp host.exp.Exponent` shows Expo Go's home screen, not your project

`launchApp` kills and relaunches the app. For Expo Go, that drops you back to Expo Go's "Recently opened" / project-picker screen — not your loaded project. To get back into your project, use `openLink` with the dev server URL:

```yaml
appId: ${APP_ID}
---
- openLink: ${PROJECT_URL}    # e.g. exp://localhost:8081
- waitForAnimationToEnd
- extendedWaitUntil:
    visible:
      text: ".*Email.*"
    timeout: 120000           # cold bundle compile can take a while
```

Or skip `launchApp` entirely if the project is already loaded from the install step — `openLink` alone is enough.

### 2. Cold bundle compile is slow

The first time a flow loads the project after Expo Go was launched fresh, the JS bundle has to compile and download. This can take 60–120s on a real-world Expo project. Either:

- **Bump `extendedWaitUntil` timeout** to 120000 ms or more for the first assertion
- **Or warm the bundle before running flows** — open the project in Expo Go once, wait for it to fully render, then start the flow

After the bundle is warm, subsequent runs are seconds, not minutes. None of this applies to native dev builds — those launch instantly.

### 3. State leaks across runs

Expo Go keeps your project loaded across flow runs. This means **app state survives**: a successful login on run #1 leaves the user authenticated for run #2, so the login flow under test doesn't actually exercise login the second time — it auto-redirects to home and the test silently lies.

Two layers of state to clear:

| Storage | Cleared by |
|---|---|
| iOS Keychain (where `expo-secure-store` lives) | `clearKeychain` |
| JS-side caches (TanStack Query, Zustand, React state) | `launchApp clearState: true` (kills Expo Go's JS context) |

The combination at the start of any flow that depends on a clean slate:

```yaml
- clearKeychain
- launchApp:
    clearState: true
- openLink: ${PROJECT_URL}
- waitForAnimationToEnd
- extendedWaitUntil:
    visible:
      id: "..."
    timeout: 120000   # cold reload after clearState
```

Cost: a cold bundle reload (the 60-120s tax). Worth it for any auth-dependent flow.

### Parameterise the appId

Use `appId: ${APP_ID}` and pass the right value at run time:

| Build | `APP_ID` value |
|---|---|
| Expo Go (iOS) | `host.exp.Exponent` (capital E — matters) |
| Expo Go (Android) | `host.exp.exponent` (lowercase) |
| Native dev build / TestFlight / store | your project's `bundleIdentifier` / `package` |

This way the same flow file works against both environments.

## Inspecting your app

To find selectors interactively:

```bash
maestro studio
```

This opens a browser at the running app and lets you hover over elements to copy selectors.
