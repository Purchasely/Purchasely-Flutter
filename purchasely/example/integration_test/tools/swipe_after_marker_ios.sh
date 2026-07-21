#!/bin/bash
# Waits for a Dart readiness marker, then sends a deterministic swipe-down.
set -euo pipefail

UDID="${1:?usage: $0 <simulator-udid> <suite-log-marker>}"
MARKER="${2:?usage: $0 <simulator-udid> <suite-log-marker>}"
HERE="$(cd "$(dirname "$0")" && pwd)"
SUITE_LOG="${SUITE_LOG:?SUITE_LOG must point to the active Flutter test log}"

for _ in $(seq 1 120); do
  if [ -f "$SUITE_LOG" ] && grep -q "$MARKER" "$SUITE_LOG"; then
    echo "[swipe_after_marker_ios] observed $MARKER"
    SKIP_PAYWALL_DETECTION=1 bash "$HERE/swipe_dismiss_ios.sh" "$UDID" 2
    exit $?
  fi
  sleep 1
done

echo "[swipe_after_marker_ios] missing $MARKER after 120s"
exit 1
