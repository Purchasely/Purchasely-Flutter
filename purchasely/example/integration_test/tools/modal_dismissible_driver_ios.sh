#!/bin/bash
# Driver wrapper for modal_dismissible_ios_test.dart: two independent
# display() cycles (dismissible:false, then dismissible:true), each needing
# its own `swipe_dismiss_ios.sh <udid> 2` invocation — see that Dart file's
# header ("one invocation per test... chained so the second waits for the
# first to finish").
#
# Usage: modal_dismissible_driver_ios.sh <sim-udid>
set -uo pipefail
UDID="${1:?usage: $0 <sim-udid>}"
HERE="$(cd "$(dirname "$0")" && pwd)"

echo "[modal_dismissible_driver_ios] test 1/2 (dismissible:false, swipe must be a no-op)…"
bash "$HERE/swipe_dismiss_ios.sh" "$UDID" 2
echo "[modal_dismissible_driver_ios] test 2/2 (dismissible:true, swipe must dismiss)…"
bash "$HERE/swipe_dismiss_ios.sh" "$UDID" 2
