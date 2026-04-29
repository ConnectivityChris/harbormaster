#!/bin/bash
# Install an app onto the booted iOS sim or Android emulator, or deep-link into Expo Go.
# Usage:
#   install-app.sh --platform ios --source dev-build --path <path-to-.app>
#   install-app.sh --platform ios --source expo-go --url exp://192.168.x.x:8081
#   install-app.sh --platform android --source dev-build --path <path-to-.apk>
#   install-app.sh --platform android --source expo-go --url exp://192.168.x.x:8081

set -eu

PLATFORM=""
SOURCE=""
APP_PATH=""
DEV_URL=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --platform) PLATFORM="$2"; shift 2 ;;
    --source) SOURCE="$2"; shift 2 ;;
    --path) APP_PATH="$2"; shift 2 ;;
    --url) DEV_URL="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$PLATFORM" || -z "$SOURCE" ]]; then
  echo "Usage: $0 --platform <ios|android> --source <dev-build|expo-go> [--path <p>] [--url <u>]" >&2
  exit 1
fi

case "${PLATFORM}-${SOURCE}" in
  ios-dev-build)
    [[ -z "$APP_PATH" ]] && { echo "✗ --path required for dev-build" >&2; exit 1; }
    [[ ! -d "$APP_PATH" && ! -f "$APP_PATH" ]] && { echo "✗ App not found: $APP_PATH" >&2; exit 1; }
    xcrun simctl install booted "$APP_PATH"
    echo "✓ Installed iOS app from $APP_PATH"
    ;;
  ios-expo-go)
    [[ -z "$DEV_URL" ]] && { echo "✗ --url required for expo-go (e.g. exp://192.168.1.10:8081)" >&2; exit 1; }
    xcrun simctl openurl booted "$DEV_URL"
    echo "✓ Opened Expo Go (iOS) with $DEV_URL"
    ;;
  android-dev-build)
    [[ -z "$APP_PATH" ]] && { echo "✗ --path required for dev-build" >&2; exit 1; }
    [[ ! -f "$APP_PATH" ]] && { echo "✗ APK not found: $APP_PATH" >&2; exit 1; }
    adb install -r "$APP_PATH"
    echo "✓ Installed Android APK from $APP_PATH"
    ;;
  android-expo-go)
    [[ -z "$DEV_URL" ]] && { echo "✗ --url required for expo-go" >&2; exit 1; }
    adb shell am start -W -a android.intent.action.VIEW -d "$DEV_URL"
    echo "✓ Opened Expo Go (Android) with $DEV_URL"
    ;;
  *)
    echo "✗ Unsupported combination: platform=$PLATFORM source=$SOURCE" >&2
    echo "   Valid: (ios|android) × (dev-build|expo-go)" >&2
    exit 1
    ;;
esac
