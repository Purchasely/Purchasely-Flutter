#!/bin/bash
# CI entrypoint for the Android E2E suite, invoked by the emulator-runner once the
# emulator has booted (see .github/workflows/e2e-android.yml). Runs the three test
# files, launching the concurrent uiautomator drivers for the suites that need a
# native interaction (interceptor tap, system BACK). Tees per-suite logs to
# integration_test/ci-logs/ for artifact upload. Exits non-zero if any suite fails.
set -uo pipefail

DEV="${1:-emulator-5554}"
HERE="$(cd "$(dirname "$0")" && pwd)"
EXAMPLE_DIR="$(cd "$HERE/../.." && pwd)"   # → purchasely/example
cd "$EXAMPLE_DIR"

LOGS="integration_test/ci-logs"
mkdir -p "$LOGS"

adb -s "$DEV" wait-for-device
flutter pub get

fail=0

# Driver-based suites are inherently flaky on the CI emulator: uiautomator
# sometimes can't see the (custom-rendered) paywall, or the app momentarily
# loses foreground. Retry such a suite a few times; pass if any attempt passes.
# $1 = label, $2 = test file, $3 = driver script, $4 = log basename
run_driver_suite_with_retry() {
  local label="$1" testfile="$2" driver="$3" logbase="$4"
  local attempts=3
  for a in $(seq 1 "$attempts"); do
    echo "=== $label (attempt $a/$attempts) ==="
    bash "$HERE/$driver" "$DEV" > "$LOGS/${logbase}_driver_$a.log" 2>&1 &
    local dpid=$!
    if flutter test "$testfile" -d "$DEV" 2>&1 | tee "$LOGS/${logbase}_$a.log"; then
      cp "$LOGS/${logbase}_$a.log" "$LOGS/${logbase}.log" 2>/dev/null || true
      kill "$dpid" 2>/dev/null || true
      echo "=== $label passed on attempt $a ==="
      return 0
    fi
    kill "$dpid" 2>/dev/null || true
    echo "=== $label failed attempt $a ==="
    adb -s "$DEV" shell am force-stop com.purchasely.demo 2>/dev/null || true
    sleep 3
  done
  cp "$LOGS/${logbase}_${attempts}.log" "$LOGS/${logbase}.log" 2>/dev/null || true
  return 1
}

echo "=== Suite 1/3: Dart↔Android bridge (T1–T20, no native interaction) ==="
flutter test integration_test/dart_android_bridge_test.dart -d "$DEV" 2>&1 \
  | tee "$LOGS/bridge.log" || fail=1

echo "=== Suite 2/3: interceptor trigger (taps action:purchase) ==="
run_driver_suite_with_retry "interceptor" \
  integration_test/interceptor_trigger_test.dart tap_purchase.sh interceptor || fail=1

echo "=== Suite 3/3: default dismiss handler (presses system BACK) ==="
run_driver_suite_with_retry "dismiss" \
  integration_test/default_dismiss_handler_test.dart press_back.sh dismiss || fail=1

echo "=== E2E suite finished (fail=$fail) ==="
exit $fail
