#!/bin/bash
# Scripted runner for the S7 iOS StoreKit purchase/restore suite
# (purchase_restore_ios_test.dart / RunnerIntegrationTests). See that Dart
# file's header comment for the full execution-path rationale.
#
# RunnerIntegrationTests is a hostless XCUITest bundle (no TEST_HOST): it
# cannot propagate the Dart test's own pass/fail into xcodebuild's result, it
# only proves the app launched and eventually exited/timed out. The actual
# proof is the Dart suite's debugPrint()/print() output, which reaches the
# simulator's unified log regardless of which mechanism launched the app —
# this script captures that concurrently and greps it for the outcome.
#
# Usage: bash run_storekit_suite_ios.sh <sim-udid>
set -uo pipefail

UDID="${1:?usage: $0 <simulator-udid>}"
HERE="$(cd "$(dirname "$0")" && pwd)"
EXAMPLE_DIR="$(cd "$HERE/../.." && pwd)" # → purchasely/example
cd "$EXAMPLE_DIR"

LOGS="integration_test/ci-logs"
mkdir -p "$LOGS"
FLUTTER_LOG="$LOGS/storekit_ios_flutter.log"
: >"$FLUTTER_LOG"

flutter pub get
flutter build ios --config-only --simulator \
  integration_test/purchase_restore_ios_test.dart
(cd ios && pod install)

xcrun simctl terminate "$UDID" com.purchasely.demo >/dev/null 2>&1 || true

# Capture the Dart suite's print()/debugPrint() lines from the simulator's
# unified log in the background — independent of xcodebuild's own result.
xcrun simctl spawn "$UDID" log stream \
  --predicate 'eventMessage CONTAINS "flutter:"' \
  >"$FLUTTER_LOG" 2>&1 &
LOG_PID=$!

# Concurrent driver: taps the purchase CTA once the paywall is on screen.
bash "$HERE/tap_purchase_ios.sh" "$UDID" >"$LOGS/storekit_ios_driver.log" 2>&1 &
DRIVER_PID=$!

xcodebuild test -workspace ios/Runner.xcworkspace -scheme Runner \
  -only-testing:RunnerIntegrationTests -destination "id=$UDID"
STATUS=$?

kill "$DRIVER_PID" >/dev/null 2>&1 || true
sleep 2
kill "$LOG_PID" >/dev/null 2>&1 || true

echo "=== Dart suite output (flutter: log lines matching S7/SETUP) ==="
grep -E "S7 iOS|SETUP" "$FLUTTER_LOG" || echo "(no matching flutter: log lines captured)"

exit $STATUS
