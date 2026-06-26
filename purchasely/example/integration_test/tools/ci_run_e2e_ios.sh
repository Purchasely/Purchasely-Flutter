#!/bin/bash
# CI entrypoint for the iOS E2E suite. Runs dart_ios_bridge_test.dart on the
# booted simulator passed as $1. Tees the log to integration_test/ci-logs/ for
# artifact upload. Exits non-zero if the suite fails.
#
# Usage: bash ci_run_e2e_ios.sh <simulator-udid>
#
# The interceptor_trigger_test and default_dismiss_handler_test are Android-only
# (uiautomator / system BACK); they are intentionally omitted here.
set -uo pipefail

DEV="${1:?usage: $0 <simulator-udid>}"
HERE="$(cd "$(dirname "$0")" && pwd)"
EXAMPLE_DIR="$(cd "$HERE/../.." && pwd)"   # → purchasely/example
cd "$EXAMPLE_DIR"

LOGS="integration_test/ci-logs"
mkdir -p "$LOGS"

flutter pub get

fail=0

echo "=== Suite 1/1: Dart↔iOS bridge (T1–T20) ==="
flutter test integration_test/dart_ios_bridge_test.dart -d "$DEV" 2>&1 \
  | tee "$LOGS/bridge.log" || fail=1

echo "=== E2E iOS suite finished (fail=$fail) ==="
exit $fail
