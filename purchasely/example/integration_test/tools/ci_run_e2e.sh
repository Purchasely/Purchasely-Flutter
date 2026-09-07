#!/bin/bash
# CI entrypoint for the Android E2E suite, invoked by the emulator-runner once the
# emulator has booted (see .github/workflows/e2e-android.yml). Tees per-suite logs
# to integration_test/ci-logs/ for artifact upload.
#
# Gating model:
#   * bridge (T1–T20, no native interaction) = HARD gate. Deterministic once the
#     SDK starts; retried for robustness.
#   * interceptor / dismiss = BEST-EFFORT (non-blocking). They drive a real
#     uiautomator tap / system BACK on the custom-rendered paywall, which is
#     inherently flaky on the CI emulator. Run for signal; a failure emits a
#     warning but does NOT fail the job.
set -uo pipefail

DEV="${1:-emulator-5554}"
HERE="$(cd "$(dirname "$0")" && pwd)"
EXAMPLE_DIR="$(cd "$HERE/../.." && pwd)"   # → purchasely/example
cd "$EXAMPLE_DIR"

LOGS="integration_test/ci-logs"
mkdir -p "$LOGS"

adb -s "$DEV" wait-for-device
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
    if flutter test "$testfile" -d "$DEV" 2>&1 | tee "$LOGS/${logbase}_$a.log"; then
      cp "$LOGS/${logbase}_$a.log" "$LOGS/${logbase}.log" 2>/dev/null || true
      [ -n "$dpid" ] && kill "$dpid" 2>/dev/null || true
      echo "=== $label passed on attempt $a ==="
      return 0
    fi
    [ -n "$dpid" ] && kill "$dpid" 2>/dev/null || true
    echo "=== $label failed attempt $a ==="
    adb -s "$DEV" shell am force-stop com.purchasely.demo 2>/dev/null || true
    sleep 3
  done
  cp "$LOGS/${logbase}_${attempts}.log" "$LOGS/${logbase}.log" 2>/dev/null || true
  return 1
}

fail=0

echo "=== Suite 1/10: Dart↔Android bridge (T1–T20) — HARD gate ==="
run_suite "bridge" integration_test/dart_android_bridge_test.dart "" bridge || fail=1

echo "=== Suite 2/10: cold-start deeplink (builder.handleDeeplink → auto-open) — HARD gate ==="
# Deterministic: the SDK opens the paywall itself from the cold-start deeplink and
# the test only asserts on analytics events (no flaky uiautomator driver).
run_suite "deeplink_cold_start" integration_test/deeplink_cold_start_test.dart "" deeplink_cold_start || fail=1

echo "=== Suite 3/10: user-attribute listener (set/removed events) — HARD gate ==="
# Deterministic: setting/clearing an attribute makes the native SDK emit a change
# event the listener must receive (no UI interaction, no driver).
run_suite "user_attribute_listener" integration_test/user_attribute_listener_test.dart "" user_attribute_listener || fail=1

echo "=== Suite 4/10: interceptor trigger (uiautomator tap) — best-effort ==="
run_suite "interceptor" integration_test/interceptor_trigger_test.dart \
  tap_purchase.sh interceptor \
  || echo "::warning::E2E Android interceptor suite failed after retries (non-blocking)"

echo "=== Suite 5/10: default dismiss handler via deeplink (system BACK) — best-effort ==="
run_suite "dismiss" integration_test/default_dismiss_handler_test.dart \
  press_back.sh dismiss \
  || echo "::warning::E2E Android dismiss suite failed after retries (non-blocking)"

echo "=== Suite 6/10: default dismiss handler via fire-and-forget display() (system BACK) — best-effort ==="
run_suite "dismiss_via_display" integration_test/default_dismiss_via_display_test.dart \
  press_back.sh dismiss_via_display \
  || echo "::warning::E2E Android dismiss-via-display suite failed after retries (non-blocking)"

echo "=== Suite 7/10: local dismiss handler wins over default (system BACK) — best-effort ==="
run_suite "local_dismiss" integration_test/local_dismiss_handler_test.dart \
  press_back.sh local_dismiss \
  || echo "::warning::E2E Android local-dismiss suite failed after retries (non-blocking)"

echo "=== Suite 8/10: inline view keeps the global event stream flowing (FLT-W-12) — best-effort ==="
# No native driver — deterministic once the inline platform view renders. Kept
# non-blocking until the inline-render path is proven reliable on the CI
# emulator; promote to a HARD gate (|| fail=1) once it is consistently green.
run_suite "inline_events" integration_test/inline_events_test.dart "" inline_events \
  || echo "::warning::E2E Android inline-events suite failed after retries (non-blocking)"

echo "=== Suite 9/10: 6.1.0 identity + cleared proxy + redemption listener — HARD gate ==="
# Deterministic: no UI interaction. Asserts the pinned anonymousUserId round-trips, that
# an explicit proxy(null) clear leaves the SDK on production, that the chain listener
# subscribed before start(), and that a bogus `ply/redeem` token settles as a Failure.
run_suite "redemption_identity" integration_test/redemption_identity_test.dart "" redemption_identity || fail=1

echo "=== Suite 10/10: 6.1.0 unconvertible proxy is skipped, not fatal — HARD gate ==="
# Its own app process: the SDK starts once, and this suite needs a different proxy state
# than suite 9. Asserts a typo neither clears the proxy nor breaks start().
run_suite "proxy_invalid" integration_test/proxy_invalid_test.dart "" proxy_invalid || fail=1

echo "=== E2E Android finished (gating fail=$fail) ==="
exit $fail
