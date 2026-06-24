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

echo "=== Suite 1/3: Dart↔Android bridge (T1–T8, no native interaction) ==="
flutter test integration_test/dart_android_bridge_test.dart -d "$DEV" 2>&1 \
  | tee "$LOGS/bridge.log" || fail=1

echo "=== Suite 2/3: interceptor trigger (T9, taps action:purchase) ==="
bash "$HERE/tap_purchase.sh" "$DEV" > "$LOGS/tap_driver.log" 2>&1 &
flutter test integration_test/interceptor_trigger_test.dart -d "$DEV" 2>&1 \
  | tee "$LOGS/interceptor.log" || fail=1

echo "=== Suite 3/3: default dismiss handler (T10, presses system BACK) ==="
bash "$HERE/press_back.sh" "$DEV" > "$LOGS/back_driver.log" 2>&1 &
flutter test integration_test/default_dismiss_handler_test.dart -d "$DEV" 2>&1 \
  | tee "$LOGS/dismiss.log" || fail=1

echo "=== E2E suite finished (fail=$fail) ==="
exit $fail
