#!/bin/bash
# Run Maestro flows against booted simulators and capture artifacts.
# Usage:
#   run-flows.sh --flows <path> --platform <ios|android|both> [--output <dir>] \
#                [--include-tags T,T] [--exclude-tags T,T] \
#                [--env KEY=VAL ...]

set -u

FLOWS=""
PLATFORM="both"
OUTPUT_DIR=""
INCLUDE_TAGS=""
EXCLUDE_TAGS=""
ENV_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --flows) FLOWS="$2"; shift 2 ;;
    --platform) PLATFORM="$2"; shift 2 ;;
    --output) OUTPUT_DIR="$2"; shift 2 ;;
    --include-tags) INCLUDE_TAGS="$2"; shift 2 ;;
    --exclude-tags) EXCLUDE_TAGS="$2"; shift 2 ;;
    --env) ENV_ARGS+=("--env" "$2"); shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$FLOWS" ]]; then
  echo "Usage: $0 --flows <path> --platform <ios|android|both> [--output <dir>] [--include-tags T,T] [--exclude-tags T,T] [--env KEY=VAL ...]" >&2
  exit 1
fi

if [[ ! -e "$FLOWS" ]]; then
  echo "[err] Flows path not found: $FLOWS" >&2
  exit 1
fi

RUN_ID=$(date +%Y%m%d-%H%M%S)
if [[ -z "$OUTPUT_DIR" ]]; then
  OUTPUT_DIR=".maestro/artifacts/$RUN_ID"
fi
mkdir -p "$OUTPUT_DIR"

TAG_ARGS=()
[[ -n "$INCLUDE_TAGS" ]] && TAG_ARGS+=("--include-tags" "$INCLUDE_TAGS")
[[ -n "$EXCLUDE_TAGS" ]] && TAG_ARGS+=("--exclude-tags" "$EXCLUDE_TAGS")

run_one() {
  local label="$1"
  local device_arg="$2"
  local out="$OUTPUT_DIR/$label"
  mkdir -p "$out"

  echo "[*] Running flows on $label..."
  if [[ -n "$device_arg" ]]; then
    maestro --device "$device_arg" test \
      "${ENV_ARGS[@]}" \
      "${TAG_ARGS[@]}" \
      --output "$out/report.xml" \
      --format JUNIT \
      --test-suite-name "mobile-flow-runner-$RUN_ID-$label" \
      --debug-output "$out" \
      --flatten-debug-output \
      "$FLOWS" 2>&1 | tee "$out/run.log"
  else
    maestro test \
      "${ENV_ARGS[@]}" \
      "${TAG_ARGS[@]}" \
      --output "$out/report.xml" \
      --format JUNIT \
      --test-suite-name "mobile-flow-runner-$RUN_ID-$label" \
      --debug-output "$out" \
      --flatten-debug-output \
      "$FLOWS" 2>&1 | tee "$out/run.log"
  fi
  local rc=${PIPESTATUS[0]}
  if [[ $rc -eq 0 ]]; then
    echo "[ok] $label: PASS"
  else
    echo "[err] $label: FAIL (see $out/run.log)"
  fi
  return $rc
}

ios_udid=""
android_serial=""
if [[ "$PLATFORM" == "ios" || "$PLATFORM" == "both" ]]; then
  ios_udid=$(xcrun simctl list devices booted 2>/dev/null \
    | grep -oE '\([A-F0-9-]{36}\)' | tr -d '()' | head -n1 || true)
fi
if [[ "$PLATFORM" == "android" || "$PLATFORM" == "both" ]]; then
  if command -v adb &>/dev/null; then
    android_serial=$(adb devices 2>/dev/null | awk '/emulator-/ {print $1}' | head -n1)
  fi
fi

exit_code=0
case "$PLATFORM" in
  ios)
    [[ -z "$ios_udid" ]] && { echo "[err] No iOS simulator booted. Run boot-sims.sh ios first." >&2; exit 1; }
    run_one "ios" "$ios_udid" || exit_code=$?
    ;;
  android)
    [[ -z "$android_serial" ]] && { echo "[err] No Android emulator running. Run boot-sims.sh android first." >&2; exit 1; }
    run_one "android" "$android_serial" || exit_code=$?
    ;;
  both)
    if [[ -n "$ios_udid" ]]; then
      run_one "ios" "$ios_udid" || exit_code=$?
    else
      echo "[warn] No iOS simulator booted, skipping iOS"
    fi
    if [[ -n "$android_serial" ]]; then
      run_one "android" "$android_serial" || exit_code=$?
    else
      echo "[warn] No Android emulator running, skipping Android"
    fi
    ;;
  *)
    echo "[err] Unknown platform: $PLATFORM" >&2
    exit 1
    ;;
esac

echo ""
echo "Artifacts: $OUTPUT_DIR"
exit $exit_code
