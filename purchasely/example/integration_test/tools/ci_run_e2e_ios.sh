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

echo "=== Suite 1/10: Dart↔iOS bridge (T1–T20) — HARD gate ==="
run_suite "bridge-ios" integration_test/dart_ios_bridge_test.dart "" bridge || fail=1

echo "=== Suite 2/10: cold-start deeplink (builder.handleDeeplink → auto-open) — HARD gate ==="
# Deterministic: the SDK opens the paywall itself from the cold-start deeplink and
# the test only asserts on analytics events (no flaky idb driver).
run_suite "deeplink-cold-start-ios" integration_test/deeplink_cold_start_test.dart "" deeplink_cold_start_ios || fail=1

echo "=== Suite 3/10: user-attribute listener (set/removed events) — HARD gate ==="
# Deterministic: setting/clearing an attribute makes the native SDK emit a change
# event the listener must receive (no UI interaction, no driver).
run_suite "user-attribute-listener-ios" integration_test/user_attribute_listener_test.dart "" user_attribute_listener_ios || fail=1

echo "=== Suite 4/10: interceptor trigger (idb tap) — best-effort ==="
run_suite "interceptor-ios" integration_test/interceptor_trigger_ios_test.dart \
  tap_purchase_ios.sh interceptor_ios \
  || echo "::warning::E2E iOS interceptor suite failed after retries (non-blocking)"

echo "=== Suite 5/10: default dismiss handler via deeplink (idb tap close) — best-effort ==="
run_suite "dismiss-ios" integration_test/default_dismiss_handler_ios_test.dart \
  close_paywall_ios.sh dismiss_ios \
  || echo "::warning::E2E iOS dismiss suite failed after retries (non-blocking)"

echo "=== Suite 6/10: default dismiss handler via fire-and-forget display() (idb tap close) — best-effort ==="
run_suite "dismiss-via-display-ios" integration_test/default_dismiss_via_display_ios_test.dart \
  close_paywall_ios.sh dismiss_via_display_ios \
  || echo "::warning::E2E iOS dismiss-via-display suite failed after retries (non-blocking)"

echo "=== Suite 7/10: local dismiss handler wins over default (idb tap close) — best-effort ==="
run_suite "local-dismiss-ios" integration_test/local_dismiss_handler_ios_test.dart \
  close_paywall_ios.sh local_dismiss_ios \
  || echo "::warning::E2E iOS local-dismiss suite failed after retries (non-blocking)"

echo "=== Suite 8/10: inline view keeps the global event stream flowing (FLT-W-12) — best-effort ==="
# No idb driver — deterministic once the inline platform view renders. This is
# the iOS-specific regression (setEventCallback clobber); kept non-blocking
# until the inline-render path is proven reliable on the CI simulator, then
# promote to a HARD gate (|| fail=1).
run_suite "inline-events-ios" integration_test/inline_events_test.dart "" inline_events_ios \
  || echo "::warning::E2E iOS inline-events suite failed after retries (non-blocking)"

echo "=== Suite 9/10: 6.1.0 identity + cleared proxy + redemption listener — HARD gate ==="
# Deterministic: no UI interaction. Asserts the pinned anonymousUserId round-trips, that
# an explicit proxy(null) clear leaves the SDK on production, that the chain listener
# subscribed before start(), and that a bogus `ply/redeem` token settles as a Failure.
run_suite "redemption_identity" integration_test/redemption_identity_test.dart "" redemption_identity || fail=1

echo "=== Suite 10/10: 6.1.0 unconvertible proxy is skipped, not fatal — HARD gate ==="
# Its own app process: the SDK starts once, and this suite needs a different proxy state
# than suite 9. Asserts a typo neither clears the proxy nor breaks start().
run_suite "proxy_invalid" integration_test/proxy_invalid_test.dart "" proxy_invalid || fail=1

echo "=== E2E iOS finished (gating fail=$fail) ==="
exit $fail
