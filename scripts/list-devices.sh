#!/bin/bash
# List available iOS simulators and Android AVDs in a human-readable format.
# The skill consumes this output to present a device picker to the user.
#
# Usage: list-devices.sh [ios|android|both]   (default: both)

# `set -u` (not -eu): empty xcrun/emulator output and missing AVDs are normal
# states the script must continue past so it can report (none available) cleanly.
set -u

PLATFORM="${1:-both}"

list_ios() {
  echo "== iOS simulators =="
  if ! command -v xcrun &>/dev/null; then
    echo "  (xcrun unavailable)"
    return
  fi
  local runtime=""
  local found=0
  while IFS= read -r line; do
    if [[ $line =~ ^--\ (.+)\ --$ ]]; then
      runtime="${BASH_REMATCH[1]}"
    elif [[ -n "$runtime" && $line =~ ^\ +(.+)\ \(([A-F0-9-]{36})\)\ \(([^\)]+)\)[[:space:]]*$ ]]; then
      local name="${BASH_REMATCH[1]}"
      local udid="${BASH_REMATCH[2]}"
      local state="${BASH_REMATCH[3]}"
      printf "  %-32s  %-18s  %-9s  %s\n" "$name" "$runtime" "$state" "$udid"
      found=$((found + 1))
    fi
  done < <(xcrun simctl list devices available 2>/dev/null)
  [[ $found -eq 0 ]] && echo "  (none available)"
}

list_android() {
  echo ""
  echo "== Android AVDs =="
  if ! command -v emulator &>/dev/null; then
    echo "  (emulator binary unavailable)"
    return
  fi
  local found=0
  while IFS= read -r avd; do
    [[ -z "$avd" ]] && continue
    printf "  %s\n" "$avd"
    found=$((found + 1))
  done < <(emulator -list-avds 2>/dev/null)
  [[ $found -eq 0 ]] && echo "  (none configured)"

  if command -v adb &>/dev/null; then
    local running
    running=$(adb devices 2>/dev/null | awk '/emulator-/ {print $1}')
    if [[ -n "$running" ]]; then
      echo ""
      echo "  Currently running:"
      echo "$running" | sed 's/^/    /'
    fi
  fi
}

case "$PLATFORM" in
  ios) list_ios ;;
  android) list_android ;;
  both) list_ios; list_android ;;
  *) echo "Usage: $0 {ios|android|both}" >&2; exit 1 ;;
esac
