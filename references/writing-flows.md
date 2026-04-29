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
accessibilityText = "Log In, Email, user@example.com, Password, *********, Forgot your password?, ..."
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
| `<TextInput>` (bare, no `accessible`) | **No** — testID is dropped, placeholder gets bundled into parent's `accessibilityText` |
| `<TextInput accessible>` (bare, accessible prop directly on it) | **Still no** — empirically verified; the parent's bundled accessibility container wins |
| `<View accessible testID="..."><TextInput .../></View>` | **Yes** — wrapper becomes a discrete node and exposes the testID |

The fix for `TextInput`: wrap it in a `<View accessible testID="...">`. The `accessible` prop on the **wrapper View** (not the TextInput itself) forces a single discrete accessibility node, exposing the `testID` as a `resource-id` Maestro can match. Setting `accessible` directly on the TextInput does not work — verified by adding bare `<TextInput accessible testID="...">` instances and observing they never surface in `maestro hierarchy` regardless.

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

**Bottom line: Expo Go is fine for inner-loop "did I break launch?" checks but not suitable for hands-off regression runs.** Expo Go is a developer tool, not a test target — it surfaces dev menus, "What's new" popovers, network-permission prompts, and project-load dialogs that can block a flow mid-run and require manual taps from the user. For automated pre-release smoke tests, build a dev client (`bunx expo run:ios` / `:android`) and target your real bundle ID — flows run hands-off against a clean install.

That said, if you're using Expo Go anyway:

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

### 3. Dev tools popovers can block flows

Expo Go's floating dev-menu button, the occasional "What's new in Expo Go" sheet, network-permission prompts on first launch, and "Open with…" intent dialogs all need to be dismissed manually if they appear mid-flow. There's no reliable programmatic dismiss for all of them. If a flow stalls mid-step, check the simulator — there's likely a dialog the user has to tap through.

This is the single best reason to switch to a dev build for any flow you want to run hands-off.

### 4. State leaks across runs

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

This skill is mostly automated — Claude drives flow authoring and debugging itself, using text-based inspection where possible.

**Default for Claude (and for scripted use):** dump the current screen's accessibility tree as text. Cheap, grep-able, parseable.

```bash
maestro --device <udid-or-serial> hierarchy
```

Filter to the fields that matter (text, ids, enabled state) to keep token cost low:

```bash
maestro --device <udid-or-serial> hierarchy \
  | jq '.. | objects | {text, "resource-id", enabled} | select(.text or ."resource-id")'
```

When **debugging a failed flow**, prefer `maestro hierarchy` over screenshots — see `troubleshooting.md` → "Efficient debugging" for the cost tiering.

**For human users iterating at the keyboard:** `maestro studio` opens a browser-based interactive inspector — hover over elements to copy selectors. This is a user-only tool; Claude can't drive its browser UI, so it should not be invoked from the skill flow.

```bash
maestro studio   # user-only — interactive browser inspector
```
