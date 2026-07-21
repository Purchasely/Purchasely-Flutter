#!/bin/bash
# Scripted runner for the S7 iOS StoreKit restore-degradation suite
# (purchase_restore_ios_test.dart / RunnerIntegrationTests). See that Dart
# file's header comment for the full execution-path rationale.
#
# RunnerIntegrationTests is a hostless XCUITest bundle (no TEST_HOST): it
# cannot propagate the Dart test's own pass/fail into xcodebuild's result; it
# only proves the app launched and the UI-test host completed. The actual
# proof is the Dart suite's debugPrint()/print() output, which reaches the
# simulator's unified log regardless of which mechanism launched the app —
# this script captures that concurrently and greps it for the outcome.
#
# GATING (Greptile P1, PR #138 review — CI run 29778281515 was a confirmed
# false green: xcodebuild exited 0 while the Dart suite had actually failed
# `expect(capturedPayload, isA<PLYPurchasePayload>())`; the old `exit $STATUS`
# below never looked at the Dart output at all). xcodebuild exit 0 is
# necessary but NOT sufficient: purchase_restore_ios_test.dart's
# `tearDownAll` prints exactly one marker line, `S7-IOS-RESULT: PASS` or
# `S7-IOS-RESULT: FAIL (completed=N/M)`, once every test in the file has run
# its body to completion. This script now exits 0 ONLY IF xcodebuild exited 0
# AND that PASS marker landed in $FLUTTER_LOG — anything else (xcodebuild
# failure, missing marker, or an explicit FAIL marker) exits 1.
#
# Usage: bash run_storekit_suite_ios.sh <sim-udid>
set -uo pipefail

UDID="${1:?usage: $0 <simulator-udid>}"
HERE="$(cd "$(dirname "$0")" && pwd)"
EXAMPLE_DIR="$(cd "$HERE/../.." && pwd)" # → purchasely/example
cd "$EXAMPLE_DIR" || exit 1

LOGS="integration_test/ci-logs"
mkdir -p "$LOGS"
FLUTTER_LOG="$LOGS/storekit_ios_flutter.log"
: >"$FLUTTER_LOG"

flutter pub get
flutter build ios --config-only --simulator \
  integration_test/purchase_restore_ios_test.dart
(cd ios && pod install)

xcrun simctl terminate "$UDID" com.purchasely.demo >/dev/null 2>&1

# Capture the Dart suite's print()/debugPrint() lines from the simulator's
# unified log in the background — independent of xcodebuild's own result.
xcrun simctl spawn "$UDID" log stream \
  --predicate 'eventMessage CONTAINS "flutter:"' \
  >"$FLUTTER_LOG" 2>&1 &
LOG_PID=$!

# No background UI driver here: RunnerIntegrationTests owns testmanagerd's
# automation channel while xcodebuild is active. The separate interceptor
# suite covers the real CTA; this StoreKit suite focuses on the bounded Flutter
# restore-degradation contract for a local receipt against the real backend.
#
# Flutter's in-app integration-test binding does not terminate this hostless
# launch when the Dart tests finish. Watch the authoritative Dart marker and
# terminate the app so the XCUITest host can finish immediately instead of
# waiting its full 420s hang timeout. PASS vs FAIL is still decided below.
(
  while kill -0 "$LOG_PID" 2>/dev/null; do
    if grep -q "S7-IOS-RESULT:" "$FLUTTER_LOG"; then
      echo "[storekit marker watcher] Dart result observed; terminating app"
      if ! xcrun simctl terminate "$UDID" com.purchasely.demo 2>/dev/null; then
        echo "[storekit marker watcher] app already stopped (non-fatal)"
      fi
      exit 0
    fi
    sleep 1
  done
) &
MARKER_WATCH_PID=$!

xcodebuild test -workspace ios/Runner.xcworkspace -scheme Runner \
  -only-testing:RunnerIntegrationTests -destination "id=$UDID"
STATUS=$?

kill "$MARKER_WATCH_PID" >/dev/null 2>&1
wait "$MARKER_WATCH_PID" 2>/dev/null

# Drain: `log stream` buffers internally and the Dart process's final
# tearDownAll print can race xcodebuild's own teardown — give it a few
# seconds before killing the stream so the marker line isn't lost.
sleep 5
kill "$LOG_PID" >/dev/null 2>&1
wait "$LOG_PID" 2>/dev/null

# Fallback: `log stream` is a live tail and can in principle miss/truncate
# output around a fast process exit. `log show` is a point-in-time query of
# the same unified log store, not a race with the kill above — append it as
# a second, more reliable source before grepping for the marker.
if ! xcrun simctl spawn "$UDID" log show \
  --predicate 'eventMessage CONTAINS "flutter:"' --last 5m \
  >>"$FLUTTER_LOG" 2>&1; then
  echo "[cleanup] simulator log fallback failed (non-fatal)"
fi

echo "=== Dart suite output ($FLUTTER_LOG, last 40 lines) ==="
tail -n 40 "$FLUTTER_LOG" 2>/dev/null || echo "(log file empty/unreadable)"

if [ "$STATUS" -eq 0 ] && grep -q "S7-IOS-RESULT: PASS" "$FLUTTER_LOG"; then
  echo "storekit-ios: PASS (xcodebuild exit=0, Dart marker=S7-IOS-RESULT: PASS)"
  exit 0
fi

echo "################################################################"
echo "# storekit-ios FAILED — xcodebuild exit=$STATUS"
if grep -q "S7-IOS-RESULT:" "$FLUTTER_LOG"; then
  echo "# Dart marker: $(grep "S7-IOS-RESULT:" "$FLUTTER_LOG" | tail -1)"
else
  echo "# Dart marker: MISSING — the Dart suite likely never reached"
  echo "# tearDownAll (crash or hang; RunnerIntegrationTests.m XCTFails"
  echo "# on its own 420s poll timeout instead of exiting 0 silently)."
fi
echo "################################################################"
exit 1
