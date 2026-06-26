#!/bin/bash
# CI entrypoint for the iOS E2E suite. Runs all three iOS test files on the
# booted simulator passed as $1. Tees logs to integration_test/ci-logs/ for
# artifact upload. Exits non-zero if any suite fails.
#
# Usage: bash ci_run_e2e_ios.sh <simulator-udid>
#
# Suites:
#   1/3 — dart_ios_bridge_test.dart (T1–T20, no native interaction)
#   2/3 — interceptor_trigger_ios_test.dart (purchase interceptor; driver:
#          tap_purchase_ios.sh uses idb to tap ply_action_purchase_*)
#   3/3 — default_dismiss_handler_ios_test.dart (deeplink + default dismiss;
#          driver: close_paywall_ios.sh uses idb to tap ply_action_close)
set -uo pipefail

DEV="${1:?usage: $0 <simulator-udid>}"
HERE="$(cd "$(dirname "$0")" && pwd)"
EXAMPLE_DIR="$(cd "$HERE/../.." && pwd)"   # → purchasely/example
cd "$EXAMPLE_DIR"

LOGS="integration_test/ci-logs"
mkdir -p "$LOGS"

flutter pub get

fail=0

echo "=== Suite 1/3: Dart↔iOS bridge (T1–T20, no native interaction) ==="
flutter test integration_test/dart_ios_bridge_test.dart -d "$DEV" --reporter expanded 2>&1 \
  | tee "$LOGS/bridge.log" || fail=1

echo "=== Suite 2/3: interceptor trigger (purchase tap via idb) ==="
bash "$HERE/tap_purchase_ios.sh" "$DEV" > "$LOGS/tap_driver_ios.log" 2>&1 &
flutter test integration_test/interceptor_trigger_ios_test.dart -d "$DEV" --reporter expanded 2>&1 \
  | tee "$LOGS/interceptor_ios.log" || fail=1

echo "=== Suite 3/3: default dismiss handler (close tap via idb) ==="
bash "$HERE/close_paywall_ios.sh" "$DEV" > "$LOGS/close_driver_ios.log" 2>&1 &
flutter test integration_test/default_dismiss_handler_ios_test.dart -d "$DEV" --reporter expanded 2>&1 \
  | tee "$LOGS/dismiss_ios.log" || fail=1

echo "=== E2E iOS suite finished (fail=$fail) ==="
exit $fail
