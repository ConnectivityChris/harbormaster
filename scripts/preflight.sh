#!/bin/bash
# Verify required tools for harbormaster are installed.
# Outputs a structured status report. Exits 0 if at least one platform (iOS or
# Android) is fully usable AND Maestro is installed. Exits 1 otherwise.

set -u

OK="[ok]"
WARN="[warn]"
ERR="[err]"
ok_count=0
warn_count=0
err_count=0

# Per-platform usability flags. A platform is "ok" only if every check it needs
# passed; any failure on its dependency chain flips it to false. The script
# exits 0 if at least one platform is ok and maestro is present.
ios_ok=true
android_ok=true

if [[ "$(uname)" != "Darwin" ]]; then
  echo "${ERR} harbormaster requires macOS (iOS simulator unavailable elsewhere)"
  exit 1
fi
echo "${OK} macOS detected"
ok_count=$((ok_count + 1))

echo ""
echo "iOS:"

if ! xcode-select -p &>/dev/null; then
  echo "${WARN} Xcode CLI tools not installed — iOS path disabled"
  echo "    Fix: xcode-select --install"
  echo "    See: references/ios-setup.md"
  warn_count=$((warn_count + 1))
  ios_ok=false
else
  XCODE_PATH=$(xcode-select -p)
  if [[ "$XCODE_PATH" == "/Library/Developer/CommandLineTools" ]]; then
    echo "${WARN} Only Xcode CLI tools found, not full Xcode — iOS simulator will not work"
    echo "    Fix: install Xcode.app from the App Store (https://apps.apple.com/app/xcode/id497799835), then:"
    echo "         sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
    echo "    See: references/ios-setup.md"
    warn_count=$((warn_count + 1))
    ios_ok=false
  else
    echo "${OK} Full Xcode at $XCODE_PATH"
    ok_count=$((ok_count + 1))
  fi
fi

if $ios_ok; then
  if command -v xcrun &>/dev/null && xcrun simctl list devices available &>/dev/null; then
    ios_count=$(xcrun simctl list devices available | grep -cE "iPhone|iPad" || true)
    if [[ $ios_count -gt 0 ]]; then
      echo "${OK} $ios_count iOS simulator(s) available"
      ok_count=$((ok_count + 1))
    else
      echo "${WARN} No iOS simulators available — iOS path disabled"
      echo "    Fix: open Xcode [*] Settings [*] Platforms and download a simulator runtime"
      warn_count=$((warn_count + 1))
      ios_ok=false
    fi
  else
    echo "${WARN} xcrun simctl not working — iOS path disabled"
    warn_count=$((warn_count + 1))
    ios_ok=false
  fi
fi

echo ""
echo "Android:"

if ! command -v adb &>/dev/null; then
  echo "${WARN} adb not on PATH — Android path disabled"
  echo "    Fix: install Android Studio (https://developer.android.com/studio),"
  echo "         then add \$ANDROID_HOME/platform-tools to PATH"
  echo "    See: references/android-setup.md"
  warn_count=$((warn_count + 1))
  android_ok=false
fi

if [[ -z "${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}" ]]; then
  echo "${WARN} ANDROID_HOME / ANDROID_SDK_ROOT not set — Android path disabled"
  echo "    Fix: export ANDROID_HOME=\"\$HOME/Library/Android/sdk\" (default Android Studio location)"
  echo "    See: references/android-setup.md"
  warn_count=$((warn_count + 1))
  android_ok=false
fi

if $android_ok; then
  if ! command -v emulator &>/dev/null; then
    echo "${WARN} emulator binary not on PATH — Android path disabled"
    echo "    Fix: add \$ANDROID_HOME/emulator to PATH"
    echo "    See: references/android-setup.md"
    warn_count=$((warn_count + 1))
    android_ok=false
  else
    avd_count=$(emulator -list-avds 2>/dev/null | grep -c . || true)
    if [[ $avd_count -gt 0 ]]; then
      echo "${OK} $avd_count AVD(s) configured"
      ok_count=$((ok_count + 1))
    else
      echo "${WARN} No AVDs configured — Android path disabled"
      echo "    Fix: open Android Studio [*] Device Manager [*] Create Virtual Device"
      echo "    See: references/android-setup.md"
      warn_count=$((warn_count + 1))
      android_ok=false
    fi
  fi
fi

echo ""
echo "Shared:"

maestro_ok=true
if command -v maestro &>/dev/null; then
  ver=$(maestro --version 2>&1 | head -n1 || echo "unknown")
  echo "${OK} Maestro installed: $ver"
  ok_count=$((ok_count + 1))
else
  echo "${ERR} Maestro CLI not installed (required for both platforms)"
  echo "    Fix (curl): curl -fsSL 'https://get.maestro.mobile.dev' | bash"
  echo "    Fix (brew): brew tap mobile-dev-inc/tap && brew install mobile-dev-inc/tap/maestro"
  echo "    Docs: https://docs.maestro.dev/getting-started/installing-maestro"
  err_count=$((err_count + 1))
  maestro_ok=false
fi

echo ""
if $ios_ok && $android_ok; then
  echo "Platforms usable: iOS + Android"
elif $ios_ok; then
  echo "Platforms usable: iOS only"
elif $android_ok; then
  echo "Platforms usable: Android only"
else
  echo "${ERR} No platforms usable — at least one of iOS or Android must be fully configured"
  err_count=$((err_count + 1))
fi

echo "Preflight: ${ok_count} ok, ${warn_count} warning(s), ${err_count} error(s)"

# Exit non-zero if maestro missing or no platform usable.
if ! $maestro_ok; then
  exit 1
fi
if ! $ios_ok && ! $android_ok; then
  exit 1
fi
exit 0
