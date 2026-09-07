#!/bin/bash
# Driver wrapper for flow_dismiss_test.dart (Android): taps action:close_all
# directly from the flow's initial "calm" screen (pattern (A) in that file's
# header). The Dart suite self-recovers via Purchasely.closeAllScreens() if
# this tap isn't observed within its own timeout (see the suite's "Close:"
# section), so a single content-desc tap is sufficient CI wiring — no need
# to also drive the chained navigate-then-validate pattern (B).
#
# Thin adapter: ci_run_e2e.sh's run_suite() only ever passes the device
# serial to a driver script; tap_content_desc.sh additionally needs the
# content-desc substring to search for.
#
# Usage: flow_close_all.sh <serial>
set -uo pipefail
DEV="${1:-emulator-5554}"
HERE="$(cd "$(dirname "$0")" && pwd)"
exec bash "$HERE/tap_content_desc.sh" "$DEV" "action:close_all"
