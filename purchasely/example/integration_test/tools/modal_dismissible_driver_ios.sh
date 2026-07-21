#!/bin/bash
# Driver wrapper for modal_dismissible_ios_test.dart: two independent
# display() cycles (dismissible:false, then dismissible:true), each needing
# its own `swipe_dismiss_ios.sh <udid> 2` invocation — see that Dart file's
# header ("one invocation per test... chained so the second waits for the
# first to finish").
#
# Usage: modal_dismissible_driver_ios.sh <sim-udid>
set -euo pipefail
UDID="${1:?usage: $0 <sim-udid>}"
HERE="$(cd "$(dirname "$0")" && pwd)"

wait_for_suite_marker() {
  local marker="$1"
  if [ -z "${SUITE_LOG:-}" ]; then
    echo "[modal_dismissible_driver_ios] SUITE_LOG not set; manual mode"
    return 0
  fi
  for _ in $(seq 1 120); do
    if [ -f "$SUITE_LOG" ] && grep -q "$marker" "$SUITE_LOG"; then
      echo "[modal_dismissible_driver_ios] observed $marker"
      return 0
    fi
    sleep 1
  done
  echo "[modal_dismissible_driver_ios] missing $marker after 120s"
  return 1
}

echo "[modal_dismissible_driver_ios] test 1/2 (dismissible:false, swipe must be a no-op)…"
wait_for_suite_marker "M1-NONDISMISSIBLE-READY"
MAX_WAIT_SECONDS=60 bash "$HERE/swipe_dismiss_ios.sh" "$UDID" 2
echo "[modal_dismissible_driver_ios] test 2/2 (dismissible:true, swipe must dismiss)…"
wait_for_suite_marker "M1-DISMISSIBLE-READY"
MAX_WAIT_SECONDS=60 bash "$HERE/swipe_dismiss_ios.sh" "$UDID" 2
