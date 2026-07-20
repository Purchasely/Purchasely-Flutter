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

echo "[re_display_driver_ios] cycle 1/2…"
bash "$HERE/close_paywall_ios.sh" "$UDID"
echo "[re_display_driver_ios] cycle 2/2…"
bash "$HERE/close_paywall_ios.sh" "$UDID"
