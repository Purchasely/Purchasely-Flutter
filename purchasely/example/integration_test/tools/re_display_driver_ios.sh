#!/bin/bash
# Driver wrapper for re_display_ios_test.dart. iOS mirror of
# re_display_driver.sh: the suite drives TWO display() cycles on the SAME
# preloaded handle and needs close_paywall_ios.sh invoked twice, chained
# (each invocation polls for its own fresh paywall before swiping to
# dismiss).
#
# Usage: re_display_driver_ios.sh <sim-udid>
set -uo pipefail
UDID="${1:?usage: $0 <sim-udid>}"
HERE="$(cd "$(dirname "$0")" && pwd)"

"$HERE/swipe_after_marker_ios.sh" "$UDID" REDISPLAY-CYCLE-1-READY
"$HERE/swipe_after_marker_ios.sh" "$UDID" REDISPLAY-CYCLE-2-READY
