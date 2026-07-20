#!/bin/bash
# Driver wrapper for re_display_test.dart (Android). The suite drives TWO
# display() cycles on the SAME preloaded handle (see that file's header) and
# needs press_back.sh invoked twice, chained: each invocation waits for its
# own fresh paywall render (press_back.sh's own polling loop) before pressing
# BACK, so a straight sequential chain (no extra sleep) is safe.
#
# Usage: re_display_driver.sh <serial>
set -uo pipefail
DEV="${1:-emulator-5554}"
HERE="$(cd "$(dirname "$0")" && pwd)"

echo "[re_display_driver] cycle 1/2…"
bash "$HERE/press_back.sh" "$DEV"
echo "[re_display_driver] cycle 2/2…"
bash "$HERE/press_back.sh" "$DEV"
