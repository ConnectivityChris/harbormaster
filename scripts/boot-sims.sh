#!/bin/bash
# Boot iOS simulator and/or Android emulator and wait until each is ready.
# Usage: boot-sims.sh {ios|android|both} [--ios-udid <udid>] [--avd <name>]

# `set -u` (not -eu): when PLATFORM=both, an iOS failure must NOT abort the
# Android boot — both must execute so the final exit code reflects the union.
# Mirrors the design choice in run-flows.sh.
set -u

PLATFORM="${1:-both}"
shift || true

IOS_UDID=""
AVD_NAME=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --ios-udid) IOS_UDID="$2"; shift 2 ;;
    --avd) AVD_NAME="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

boot_ios() {
  local udid="$IOS_UDID"
  if [[ -z "$udid" ]]; then
    udid=$(xcrun simctl list devices available 2>/dev/null \
      | grep -E "iPhone [0-9]+" \
      | head -n1 \
      | grep -oE '\([A-F0-9-]{36}\)' \
      | tr -d '()' || true)
    if [[ -n "$udid" ]]; then
      echo "[warn] No --ios-udid passed; falling back to first available iPhone simulator ($udid)"
    fi
  fi
  if [[ -z "$udid" ]]; then
    echo "[err] No iPhone simulator available" >&2
    return 1
  fi
  echo "[*] Booting iOS simulator $udid..."
  xcrun simctl boot "$udid" 2>/dev/null || true
  open -a Simulator
  if ! xcrun simctl bootstatus "$udid" -b; then
    echo "[err] iOS simulator $udid did not reach booted state" >&2
    return 1
  fi
  echo "[ok] iOS simulator ready: $udid"
}

boot_android() {
  if ! command -v emulator &>/dev/null; then
    echo "[err] emulator binary not on PATH — cannot boot Android" >&2
    return 1
  fi
  local avd="$AVD_NAME"
  if [[ -z "$avd" ]]; then
    avd=$(emulator -list-avds 2>/dev/null | head -n1 || true)
    if [[ -n "$avd" ]]; then
      echo "[warn] No --avd passed; falling back to first listed AVD ($avd)"
    fi
  fi
  if [[ -z "$avd" ]]; then
    echo "[err] No AVD configured" >&2
    return 1
  fi

  if adb devices 2>/dev/null | grep -q "emulator-"; then
    echo "[ok] Android emulator already running"
    return 0
  fi

  echo "[*] Booting Android emulator $avd..."
  nohup emulator @"$avd" -no-snapshot-save >/dev/null 2>&1 &
  local emu_pid=$!

  if ! adb wait-for-device; then
    echo "[err] adb wait-for-device failed" >&2
    return 1
  fi

  # Bound the boot-completed wait so a crashed emulator can't hang the script.
  # 180s matches typical cold-boot for Pixel-class AVDs; bump if your AVD is slow.
  local waited=0
  local timeout=180
  while [[ "$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" != "1" ]]; do
    if ! kill -0 "$emu_pid" 2>/dev/null; then
      echo "[err] emulator process exited before boot completed" >&2
      return 1
    fi
    if (( waited >= timeout )); then
      echo "[err] Android emulator did not boot within ${timeout}s" >&2
      return 1
    fi
    sleep 2
    waited=$((waited + 2))
  done
  echo "[ok] Android emulator ready"
}

exit_code=0
case "$PLATFORM" in
  ios) boot_ios || exit_code=$? ;;
  android) boot_android || exit_code=$? ;;
  both)
    boot_ios || exit_code=$?
    boot_android || exit_code=$?
    ;;
  *) echo "Usage: $0 {ios|android|both} [--ios-udid <udid>] [--avd <name>]" >&2; exit 1 ;;
esac
exit $exit_code
