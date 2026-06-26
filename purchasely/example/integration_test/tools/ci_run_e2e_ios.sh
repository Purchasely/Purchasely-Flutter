#!/bin/bash
# CI entrypoint for the iOS E2E suite. Runs the three iOS test files on the
# booted simulator passed as $1. Tees logs to integration_test/ci-logs/.
#
# Usage: bash ci_run_e2e_ios.sh <simulator-udid>
#
# Gating model:
#   * bridge (T1–T20, no native interaction) = HARD gate. Deterministic once the
#     SDK starts; retried because Purchasely.start() occasionally times out on
#     the CI simulator (slow backend round-trip).
#   * interceptor / dismiss = BEST-EFFORT (non-blocking). They drive a real
#     native tap/swipe on the custom-rendered paywall via idb, which is
#     inherently flaky on the CI simulator. Run for signal; a failure emits a
#     warning but does NOT fail the job.
set -uo pipefail

DEV="${1:?usage: $0 <simulator-udid>}"
HERE="$(cd "$(dirname "$0")" && pwd)"
EXAMPLE_DIR="$(cd "$HERE/../.." && pwd)"   # → purchasely/example
cd "$EXAMPLE_DIR"

LOGS="integration_test/ci-logs"
mkdir -p "$LOGS"

flutter pub get

# Run a suite up to 3×; pass if any attempt passes. $3 = optional driver script.
run_suite() {
  local label="$1" testfile="$2" driver="$3" logbase="$4"
  local attempts=3 dpid=""
  for a in $(seq 1 "$attempts"); do
    echo "=== $label (attempt $a/$attempts) ==="
    dpid=""
    if [ -n "$driver" ]; then
      bash "$HERE/$driver" "$DEV" > "$LOGS/${logbase}_driver_$a.log" 2>&1 &
      dpid=$!
    fi
    if flutter test "$testfile" -d "$DEV" --reporter expanded 2>&1 | tee "$LOGS/${logbase}_$a.log"; then
      cp "$LOGS/${logbase}_$a.log" "$LOGS/${logbase}.log" 2>/dev/null || true
      [ -n "$dpid" ] && kill "$dpid" 2>/dev/null || true
      echo "=== $label passed on attempt $a ==="
      return 0
    fi
    [ -n "$dpid" ] && kill "$dpid" 2>/dev/null || true
    echo "=== $label failed attempt $a ==="
    xcrun simctl terminate "$DEV" com.purchasely.demo 2>/dev/null || true
    sleep 3
  done
  cp "$LOGS/${logbase}_${attempts}.log" "$LOGS/${logbase}.log" 2>/dev/null || true
  return 1
}

fail=0

echo "=== Suite 1/3: Dart↔iOS bridge (T1–T20) — HARD gate ==="
run_suite "bridge-ios" integration_test/dart_ios_bridge_test.dart "" bridge || fail=1

echo "=== Suite 2/3: interceptor trigger (idb tap) — best-effort ==="
run_suite "interceptor-ios" integration_test/interceptor_trigger_ios_test.dart \
  tap_purchase_ios.sh interceptor_ios \
  || echo "::warning::E2E iOS interceptor suite failed after retries (non-blocking)"

echo "=== Suite 3/5: default dismiss handler via deeplink (idb tap close) — best-effort ==="
run_suite "dismiss-ios" integration_test/default_dismiss_handler_ios_test.dart \
  close_paywall_ios.sh dismiss_ios \
  || echo "::warning::E2E iOS dismiss suite failed after retries (non-blocking)"

echo "=== Suite 4/5: default dismiss handler via fire-and-forget display() (idb tap close) — best-effort ==="
run_suite "dismiss-via-display-ios" integration_test/default_dismiss_via_display_ios_test.dart \
  close_paywall_ios.sh dismiss_via_display_ios \
  || echo "::warning::E2E iOS dismiss-via-display suite failed after retries (non-blocking)"

echo "=== Suite 5/5: local dismiss handler wins over default (idb tap close) — best-effort ==="
run_suite "local-dismiss-ios" integration_test/local_dismiss_handler_ios_test.dart \
  close_paywall_ios.sh local_dismiss_ios \
  || echo "::warning::E2E iOS local-dismiss suite failed after retries (non-blocking)"

echo "=== E2E iOS finished (gating fail=$fail) ==="
exit $fail
