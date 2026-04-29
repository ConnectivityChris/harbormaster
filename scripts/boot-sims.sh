#!/bin/bash
# Boot iOS simulator and/or Android emulator and wait until each is ready.
# Usage: boot-sims.sh {ios|android|both} [--ios-udid <udid>] [--avd <name>]

set -eu

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
  fi
  if [[ -z "$udid" ]]; then
    echo "[err] No iPhone simulator available" >&2
    return 1
  fi
  echo "[*] Booting iOS simulator $udid..."
  xcrun simctl boot "$udid" 2>/dev/null || true
  open -a Simulator
  xcrun simctl bootstatus "$udid" -b
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

  adb wait-for-device
  while [[ "$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" != "1" ]]; do
    sleep 2
  done
  echo "[ok] Android emulator ready"
}

case "$PLATFORM" in
  ios) boot_ios ;;
  android) boot_android ;;
  both) boot_ios && boot_android ;;
  *) echo "Usage: $0 {ios|android|both} [--ios-udid <udid>] [--avd <name>]" >&2; exit 1 ;;
esac
