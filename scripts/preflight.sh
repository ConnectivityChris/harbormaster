#!/bin/bash
# Verify all required tools for harbormaster are installed.
# Outputs a structured status report. Exits 0 if iOS works (Android optional), 1 otherwise.

set -u

OK="[ok]"
WARN="[warn]"
ERR="[err]"
ok_count=0
warn_count=0
err_count=0

if [[ "$(uname)" != "Darwin" ]]; then
  echo "${ERR} harbormaster requires macOS (iOS simulator unavailable elsewhere)"
  exit 1
fi
echo "${OK} macOS detected"
ok_count=$((ok_count + 1))

if ! xcode-select -p &>/dev/null; then
  echo "${ERR} Xcode CLI tools not installed"
  echo "    Fix: xcode-select --install"
  err_count=$((err_count + 1))
else
  XCODE_PATH=$(xcode-select -p)
  if [[ "$XCODE_PATH" == "/Library/Developer/CommandLineTools" ]]; then
    echo "${WARN} Only Xcode CLI tools found, not full Xcode. iOS simulator will not work."
    echo "    Fix: install Xcode.app from the App Store, then:"
    echo "         sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
    warn_count=$((warn_count + 1))
  else
    echo "${OK} Full Xcode at $XCODE_PATH"
    ok_count=$((ok_count + 1))
  fi
fi

if command -v xcrun &>/dev/null && xcrun simctl list devices available &>/dev/null; then
  ios_count=$(xcrun simctl list devices available | grep -cE "iPhone|iPad" || true)
  if [[ $ios_count -gt 0 ]]; then
    echo "${OK} $ios_count iOS simulator(s) available"
    ok_count=$((ok_count + 1))
  else
    echo "${ERR} No iOS simulators available"
    echo "    Fix: open Xcode [*] Settings [*] Platforms and download a simulator runtime"
    err_count=$((err_count + 1))
  fi
else
  echo "${ERR} xcrun simctl not working"
  err_count=$((err_count + 1))
fi

if command -v maestro &>/dev/null; then
  ver=$(maestro --version 2>&1 | head -n1 || echo "unknown")
  echo "${OK} Maestro installed: $ver"
  ok_count=$((ok_count + 1))
else
  echo "${ERR} Maestro CLI not installed"
  echo "    Fix (curl): curl -fsSL 'https://get.maestro.mobile.dev' | bash"
  echo "    Fix (brew): brew tap mobile-dev-inc/tap && brew install mobile-dev-inc/tap/maestro"
  err_count=$((err_count + 1))
fi

echo ""
echo "Android (optional):"
android_ok=true

if ! command -v adb &>/dev/null; then
  echo "${WARN} adb not on PATH — skill will run iOS-only"
  echo "    Fix: install Android SDK platform-tools and add to PATH"
  android_ok=false
  warn_count=$((warn_count + 1))
fi

if [[ -z "${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}" ]]; then
  echo "${WARN} ANDROID_HOME / ANDROID_SDK_ROOT not set — skill will run iOS-only"
  android_ok=false
  warn_count=$((warn_count + 1))
fi

if $android_ok; then
  if ! command -v emulator &>/dev/null; then
    echo "${WARN} emulator binary not on PATH"
    echo "    Fix: add \$ANDROID_HOME/emulator to PATH"
    warn_count=$((warn_count + 1))
  else
    avd_count=$(emulator -list-avds 2>/dev/null | grep -c . || true)
    if [[ $avd_count -gt 0 ]]; then
      echo "${OK} $avd_count AVD(s) configured"
      ok_count=$((ok_count + 1))
    else
      echo "${WARN} No AVDs configured"
      echo "    Fix: open Android Studio [*] Device Manager [*] Create Virtual Device"
      warn_count=$((warn_count + 1))
    fi
  fi
fi

echo ""
echo "Preflight: ${ok_count} ok, ${warn_count} warning(s), ${err_count} error(s)"
[[ $err_count -gt 0 ]] && exit 1
exit 0
