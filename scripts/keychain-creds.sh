#!/bin/bash
# Manage stored credentials in the macOS Keychain for mobile-flow-runner.
# Usage:
#   keychain-creds.sh get <account>
#   keychain-creds.sh set <account> <username> <password>
#   keychain-creds.sh clear <account>
#
# `get` prints two lines: USERNAME=... and PASSWORD=...
# Exits non-zero if creds are not found, so callers can detect first-run.

set -eu

SERVICE="mobile-flow-runner"
ACTION="${1:-}"
ACCOUNT="${2:-}"

if [[ -z "$ACTION" || -z "$ACCOUNT" ]]; then
  echo "Usage: $0 {get|set|clear} <account> [<username> <password>]" >&2
  exit 2
fi

USER_KEY="$ACCOUNT/username"
PASS_KEY="$ACCOUNT/password"

case "$ACTION" in
  get)
    user=$(security find-generic-password -s "$SERVICE" -a "$USER_KEY" -w 2>/dev/null) || exit 1
    pass=$(security find-generic-password -s "$SERVICE" -a "$PASS_KEY" -w 2>/dev/null) || exit 1
    echo "USERNAME=$user"
    echo "PASSWORD=$pass"
    ;;
  set)
    USERNAME="${3:-}"
    PASSWORD="${4:-}"
    if [[ -z "$USERNAME" || -z "$PASSWORD" ]]; then
      echo "set requires <username> <password>" >&2
      exit 2
    fi
    security add-generic-password -U -s "$SERVICE" -a "$USER_KEY" -w "$USERNAME"
    security add-generic-password -U -s "$SERVICE" -a "$PASS_KEY" -w "$PASSWORD"
    echo "✓ Stored credentials for '$ACCOUNT' in Keychain (service: $SERVICE)"
    ;;
  clear)
    security delete-generic-password -s "$SERVICE" -a "$USER_KEY" 2>/dev/null || true
    security delete-generic-password -s "$SERVICE" -a "$PASS_KEY" 2>/dev/null || true
    echo "✓ Cleared credentials for '$ACCOUNT'"
    ;;
  *)
    echo "Unknown action: $ACTION" >&2
    exit 2
    ;;
esac
