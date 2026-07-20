#!/bin/bash
# Driver for interceptor_actions_ios_test.dart (S5/S6): ONE real tap on
# "Login" per test, LOG-DRIVEN synchronization between them (see
# task-5-report.md: a fixed sleep is racy — S5's own post-tap cleanup
# observed 9s-24s+ variance across runs), then a re-foreground step after S6
# backgrounds the app to Safari (otherwise tearDown's native
# interceptor-cleanup calls, and any following CI suite, risk hanging /
# bleeding into a backgrounded Safari state).
#
# Reads the suite's own per-attempt log file from $SUITE_LOG (exported by
# ci_run_e2e_ios.sh's run_suite() before backgrounding this driver — the
# very file `flutter test`'s output is concurrently being `tee`'d into) and
# polls it for the "[S5/failed] callback order:" line the Dart test prints
# once S5 resolves, before triggering S6's tap. Falls back to a fixed wait
# if $SUITE_LOG isn't set (e.g. manual invocation outside ci_run_e2e_ios.sh).
#
# Usage: interceptor_actions_driver_ios.sh <sim-udid>
set -uo pipefail
UDID="${1:?usage: $0 <sim-udid>}"
HERE="$(cd "$(dirname "$0")" && pwd)"

echo "[interceptor_actions_driver_ios] tap 1/2 (S5/failed)…"
bash "$HERE/tap_label_ios.sh" "$UDID" "Login"

if [ -n "${SUITE_LOG:-}" ]; then
  echo "[interceptor_actions_driver_ios] waiting for S5 callback-order marker in $SUITE_LOG…"
  found=0
  for _ in $(seq 1 60); do
    if [ -f "$SUITE_LOG" ] && grep -q '\[S5/failed\] callback order:' "$SUITE_LOG"; then
      echo "[interceptor_actions_driver_ios] S5 marker observed, proceeding to tap 2/2"
      found=1
      break
    fi
    sleep 1
  done
  [ "$found" -eq 0 ] && echo "[interceptor_actions_driver_ios] S5 marker not observed after 60s, proceeding anyway"
else
  echo "[interceptor_actions_driver_ios] SUITE_LOG not set — falling back to a fixed 20s wait (best-effort)"
  sleep 20
fi

echo "[interceptor_actions_driver_ios] tap 2/2 (S6/notHandled)…"
bash "$HERE/tap_label_ios.sh" "$UDID" "Login"

echo "[interceptor_actions_driver_ios] re-foregrounding app after S6 backgrounds it to Safari…"
if ! xcrun simctl launch "$UDID" com.purchasely.demo 2>&1; then
  echo "[interceptor_actions_driver_ios] re-foreground failed (non-fatal)"
fi
