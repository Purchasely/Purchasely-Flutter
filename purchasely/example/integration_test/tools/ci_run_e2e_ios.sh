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
#          tap_purchase_ios.sh uses idb to tap the purchase CTA)
#   3/3 — default_dismiss_handler_ios_test.dart (deeplink + default dismiss;
#          driver: close_paywall_ios.sh uses idb to swipe-dismiss)
set -uo pipefail

DEV="${1:?usage: $0 <simulator-udid>}"
HERE="$(cd "$(dirname "$0")" && pwd)"
EXAMPLE_DIR="$(cd "$HERE/../.." && pwd)"   # → purchasely/example
cd "$EXAMPLE_DIR"

LOGS="integration_test/ci-logs"
mkdir -p "$LOGS"

flutter pub get

fail=0

# Driver-based suites are inherently flaky on the CI simulator (idb timing /
# paywall foregrounding). Retry such a suite a few times; pass if any passes.
# $1 = label, $2 = test file, $3 = driver script, $4 = log basename
run_driver_suite_with_retry() {
  local label="$1" testfile="$2" driver="$3" logbase="$4"
  local attempts=3
  for a in $(seq 1 "$attempts"); do
    echo "=== $label (attempt $a/$attempts) ==="
    bash "$HERE/$driver" "$DEV" > "$LOGS/${logbase}_driver_$a.log" 2>&1 &
    local dpid=$!
    if flutter test "$testfile" -d "$DEV" --reporter expanded 2>&1 | tee "$LOGS/${logbase}_$a.log"; then
      cp "$LOGS/${logbase}_$a.log" "$LOGS/${logbase}.log" 2>/dev/null || true
      kill "$dpid" 2>/dev/null || true
      echo "=== $label passed on attempt $a ==="
      return 0
    fi
    kill "$dpid" 2>/dev/null || true
    echo "=== $label failed attempt $a ==="
    xcrun simctl terminate "$DEV" com.purchasely.demo 2>/dev/null || true
    sleep 3
  done
  cp "$LOGS/${logbase}_${attempts}.log" "$LOGS/${logbase}.log" 2>/dev/null || true
  return 1
}

echo "=== Suite 1/3: Dart↔iOS bridge (T1–T20, no native interaction) ==="
flutter test integration_test/dart_ios_bridge_test.dart -d "$DEV" --reporter expanded 2>&1 \
  | tee "$LOGS/bridge.log" || fail=1

echo "=== Suite 2/3: interceptor trigger (purchase tap via idb) ==="
run_driver_suite_with_retry "interceptor-ios" \
  integration_test/interceptor_trigger_ios_test.dart tap_purchase_ios.sh interceptor_ios || fail=1

echo "=== Suite 3/3: default dismiss handler (swipe via idb) ==="
run_driver_suite_with_retry "dismiss-ios" \
  integration_test/default_dismiss_handler_ios_test.dart close_paywall_ios.sh dismiss_ios || fail=1

echo "=== E2E iOS suite finished (fail=$fail) ==="
exit $fail
