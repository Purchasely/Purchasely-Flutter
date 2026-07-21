#!/bin/bash
# CI entrypoint for the iOS E2E suite. Runs the E2E test files on the
# booted simulator passed as $1. Tees logs to integration_test/ci-logs/.
#
# Usage: bash ci_run_e2e_ios.sh <simulator-udid>
#
# Gating model: ALL suites are HARD gates, with exactly ONE exception: the
# StoreKit transaction/restore suite (last, see bottom of this file) — non-
# gating ONLY IF every failed attempt (across all 3 retries) matches the
# known, currently-open Apple/Xcode platform bug signature
# (SKInternalErrorDomain Code=3 / "Error saving configuration file",
# FB22237318, see task-6-report.md); it then prints a loud "S7-iOS BLOCKED
# (Apple FB22237318)" marker and does NOT gate. If even ONE failed attempt
# does not match that signature (e.g. a mixed run — one attempt hits the
# Apple bug, another fails for a real regression), the suite gates normally,
# same as every other suite — a real regression must never be masked by an
# unrelated attempt's known-bug match. The previous best-effort /
# silent-::warning:: model for the idb-driven suites is forbidden by the
# mission — a suite that never fails a build is not a test.
#
# Per-attempt timeout: Flutter batches are bounded to $TIMEOUT seconds (default
# 300); StoreKit uses $STOREKIT_TIMEOUT (default 600) because its XCTest host
# has a separate 420-second bound. macOS runners do NOT ship GNU `timeout` by
# default, so this uses a portable bash watchdog (see run_with_timeout()
# below) instead of depending on `gtimeout`/coreutils being installed. The
# existing 3x retry loop applies to a timed-out attempt exactly like any
# other failure.
set -uo pipefail

DEV="${1:?usage: $0 <simulator-udid>}"
TIMEOUT="${TIMEOUT:-300}" # seconds per Flutter batch attempt
STOREKIT_TIMEOUT="${STOREKIT_TIMEOUT:-600}"
E2E_IOS_SUITE="${E2E_IOS_SUITE:-all}"
HERE="$(cd "$(dirname "$0")" && pwd)"
EXAMPLE_DIR="$(cd "$HERE/../.." && pwd)" # → purchasely/example
cd "$EXAMPLE_DIR" || exit 1

LOGS="integration_test/ci-logs"
mkdir -p "$LOGS"

flutter pub get

# Runs "$@" with a hard $TIMEOUT-second ceiling. Portable (no dependency on
# GNU coreutils' `timeout`, absent by default on this macOS runner):
# backgrounds "$@", races it against a `sleep $TIMEOUT` watchdog, and kills
# whichever loses. Returns 124 on timeout (matches GNU timeout's convention),
# else "$@"'s own exit code.
#
# TREE KILL: "$@" is backgrounded with job control (`set -m`) enabled so bash
# gives it its own process group (PGID == its own PID) — standard POSIX job
# control, identical on GNU bash 3.2/macOS and bash 5.x/Linux (unlike
# `setsid`/GNU `timeout`, this isn't a coreutils-only feature, so it needs no
# per-runner branching). On timeout we kill the *group*
# (`kill -TERM -- "-$cmd_pid"`), not just $cmd_pid, so children reparented
# under it (dart/xcodebuild/gradle, background taps) are reached too, not
# just the immediate `flutter test` process. `set -m` is scoped to only the
# backgrounding line so it doesn't change job-control semantics anywhere
# else in this function (incl. the pipe-hang fix below). LIMITATION: a
# Gradle daemon detaches into its own session by design (so it survives its
# launching process) and therefore escapes this process group — that daemon
# is shared/pre-existing across attempts, not per-attempt state, so it isn't
# something this kill needs to reach.
#
# NOTE (found via local testing, see task-7-report.md): when this whole
# function is used as the left side of a pipe (`run_with_timeout ... | tee
# log`, exactly how it's called below), killing ONLY the watchdog subshell's
# own PID leaves its `sleep $TIMEOUT` child orphaned (reparented, not
# reaped) — and since that orphan still holds the pipe's write end open, the
# downstream `tee` never sees EOF and the whole pipeline hangs for the
# remainder of $TIMEOUT even on a perfectly healthy, fast-passing attempt.
# `pkill -P "$watchdog_pid"` (kill its child by parent-pid) BEFORE killing
# the subshell itself avoids this — verified with an isolated repro. (An
# earlier attempt to also `disown` the backgrounded "$@" job, to silence
# bash's cosmetic job-control "Terminated" notice, reintroduced this exact
# class of race on the fast/no-timeout path — dropped; the notice is
# harmless log noise, left as-is.)
run_with_timeout() {
  local marker
  marker="$(mktemp)"
  set -m
  "$@" &
  local cmd_pid=$!
  set +m
  (
    sleep "$TIMEOUT"
    if kill -0 "$cmd_pid" 2>/dev/null; then
      echo "::warning::watchdog: attempt exceeded ${TIMEOUT}s, killing PGID $cmd_pid"
      echo 1 >"$marker"
      kill -TERM -- "-$cmd_pid" 2>/dev/null
      sleep 5
      kill -KILL -- "-$cmd_pid" 2>/dev/null
    fi
  ) &
  local watchdog_pid=$!
  local status=0
  wait "$cmd_pid" 2>/dev/null || status=$?
  pkill -P "$watchdog_pid" 2>/dev/null # reap the watchdog's sleep child first (see NOTE above)
  kill "$watchdog_pid" 2>/dev/null
  wait "$watchdog_pid" 2>/dev/null
  if [ -s "$marker" ]; then
    status=124
  fi
  rm -f "$marker"
  return "$status"
}

# Run a suite up to 3x; pass if any attempt passes. $3 = optional driver script
# (invoked as `driver <udid>`; the per-attempt suite log path is exported as
# $SUITE_LOG for drivers that need to synchronize against it — e.g.
# interceptor_actions_driver_ios.sh polls it for a marker line instead of
# using a fixed, racy sleep between its two taps).
run_suite() {
  local label="$1" testfile="$2" driver="$3" logbase="$4"
  local attempts=3 dpid=""
  for a in $(seq 1 "$attempts"); do
    echo "::group::SUITE $label attempt $a"
    local start_ts end_ts duration status
    start_ts=$(date +%s)
    dpid=""
    if [ -n "$driver" ]; then
      export SUITE_LOG="$LOGS/${logbase}_$a.log"
      bash "$HERE/$driver" "$DEV" >"$LOGS/${logbase}_driver_$a.log" 2>&1 &
      dpid=$!
    fi
    status=0
    run_with_timeout flutter test "$testfile" -d "$DEV" --no-pub --reporter expanded 2>&1 | tee "$LOGS/${logbase}_$a.log"
    status=$?
    end_ts=$(date +%s)
    duration=$((end_ts - start_ts))
    if [ "$status" -eq 124 ]; then
      echo "SUITE $label attempt $a: exit=124 (TIMEOUT after ${TIMEOUT}s) duration=${duration}s"
    else
      echo "SUITE $label attempt $a: exit=$status duration=${duration}s"
    fi
    echo "::endgroup::"
    if [ "$status" -eq 0 ]; then
      if ! cp "$LOGS/${logbase}_$a.log" "$LOGS/${logbase}.log" 2>/dev/null; then
        echo "[cleanup] failed to copy ${logbase}_$a.log (non-fatal)"
      fi
      if [ -n "$dpid" ]; then
        kill "$dpid" 2>/dev/null || echo "[cleanup] driver pid $dpid already exited (non-fatal)"
      fi
      echo "=== $label passed on attempt $a ==="
      return 0
    fi
    if [ -n "$dpid" ]; then
      kill "$dpid" 2>/dev/null || echo "[cleanup] driver pid $dpid already exited (non-fatal)"
    fi
    echo "=== $label failed attempt $a (exit=$status) ==="
    if ! xcrun simctl terminate "$DEV" com.purchasely.demo 2>/dev/null; then
      echo "[cleanup] simctl terminate failed (non-fatal, app likely already stopped)"
    fi
    sleep 3
  done
  if ! cp "$LOGS/${logbase}_${attempts}.log" "$LOGS/${logbase}.log" 2>/dev/null; then
    echo "[cleanup] failed to copy ${logbase}_${attempts}.log (non-fatal)"
  fi
  return 1
}

if [ "$E2E_IOS_SUITE" != "all" ] && [ "$E2E_IOS_SUITE" != "storekit" ]; then
  echo "::error::Unsupported E2E_IOS_SUITE=$E2E_IOS_SUITE (expected all or storekit)"
  exit 2
fi

fail=0

if [ "$E2E_IOS_SUITE" = "all" ]; then
  echo "=== Batch 1/7: core bridge/deeplink/listener/flow suites — HARD gate ==="
  run_suite "core-ios" integration_test/ios_core_batch_test.dart "" core_ios || fail=1

  echo "=== Batch 2/7: inline presentation suites — HARD gate ==="
  run_suite "inline-ios" integration_test/ios_inline_batch_test.dart "" inline_ios || fail=1

  echo "=== Batch 3/7: purchase interceptor suite — HARD gate ==="
  run_suite "purchase-interceptor-ios" integration_test/interceptor_trigger_ios_test.dart \
    purchase_interceptor_driver_ios.sh purchase_interceptor_ios || fail=1

  echo "=== Batch 4/7: navigate interceptor suites — HARD gate ==="
  run_suite "navigate-interceptors-ios" integration_test/interceptor_actions_ios_test.dart \
    interceptor_actions_driver_ios.sh navigate_interceptors_ios || fail=1

  echo "=== Batch 5/7: default/local dismiss handler suites — HARD gate ==="
  run_suite "dismiss-ios" integration_test/ios_dismiss_batch_test.dart \
    dismiss_batch_driver_ios.sh dismiss_ios || fail=1

  echo "=== Batch 6/7: modal and re-display transition regressions — HARD gate ==="
  run_suite "transitions-ios" integration_test/ios_transition_batch_test.dart \
    transition_batch_driver_ios.sh transitions_ios || fail=1
else
  echo "=== Targeted manual run: skipping batches 1-6; running StoreKit only ==="
fi

# --- Batch 7/7: S7 StoreKit transaction + restore -------------------------
# SPECIAL CASE, not run via run_suite(): purchase_restore_ios_test.dart can
# only exercise a real local StoreKit2 transaction if the app is launched
# through the Xcode scheme (Configuration.storekit is wired into the
# scheme's LaunchAction, not into plain `flutter test`'s own `xcrun simctl
# launch`) — see that file's header and task-6-report.md. That means
# `xcodebuild test` via tools/run_storekit_suite_ios.sh, not `flutter test`.
#
# KNOWN BLOCKER (task-6-report.md): as of this writing, `SKTestSession`
# reproducibly fails to start outside Xcode's own GUI Run/Test action on
# iOS/Xcode 26.5/26.6 simulators — a confirmed, currently-open Apple
# platform bug (FB22237318; matches flutter/flutter#184678, still broken on
# 26.5 per that thread). Gating a build on an external, unfixed platform bug
# would make every CI run red for a reason nobody here can act on — so,
# and ONLY when EVERY failed attempt matches this documented signature, we
# print a loud non-gating marker instead of failing the job. If any attempt
# fails for a DIFFERENT reason (wiring regression, wrong product ids, a real
# purchase/restore assertion failure, etc.) the suite gates, even if other
# attempts in the same run also matched the Apple signature — a mixed run
# must not let a real regression hide behind an unrelated known-bug match.
echo "=== Batch 7/7: S7 StoreKit transaction + restore (xcodebuild, RunnerIntegrationTests) — HARD gate (Apple-bug exception) ==="
TIMEOUT="$STOREKIT_TIMEOUT"
storekit_logbase="storekit-ios"
storekit_ok=0
storekit_apple_sig=0
storekit_other_failure=0
storekit_fail_count=0
storekit_last_attempt=0
for a in 1 2 3; do
  storekit_last_attempt="$a"
  echo "::group::SUITE $storekit_logbase attempt $a"
  start_ts=$(date +%s)
  status=0
  run_with_timeout bash "$HERE/run_storekit_suite_ios.sh" "$DEV" 2>&1 | tee "$LOGS/${storekit_logbase}_$a.log"
  status=$?
  end_ts=$(date +%s)
  duration=$((end_ts - start_ts))
  if [ "$status" -eq 124 ]; then
    echo "SUITE $storekit_logbase attempt $a: exit=124 (TIMEOUT after ${TIMEOUT}s) duration=${duration}s"
  else
    echo "SUITE $storekit_logbase attempt $a: exit=$status duration=${duration}s"
  fi
  echo "::endgroup::"
  if [ "$status" -eq 0 ]; then
    storekit_ok=1
    if ! cp "$LOGS/${storekit_logbase}_$a.log" "$LOGS/${storekit_logbase}.log" 2>/dev/null; then
      echo "[cleanup] failed to copy ${storekit_logbase}_$a.log (non-fatal)"
    fi
    echo "=== $storekit_logbase passed on attempt $a ==="
    break
  fi
  storekit_fail_count=$((storekit_fail_count + 1))
  # A Dart result marker proves the app got past SKTestSession setup, so this
  # is never an Apple-only blocker — even if the verbose xcodebuild log also
  # happens to contain the known signature. Explicit Dart evidence wins.
  if grep -q 'S7-IOS-RESULT: FAIL' "$LOGS/${storekit_logbase}_$a.log"; then
    storekit_other_failure=1
    echo "=== $storekit_logbase emitted an explicit Dart FAIL; not retrying a deterministic assertion failure ==="
    break
  elif grep -q 'S7-IOS-RESULT:' "$LOGS/${storekit_logbase}_$a.log"; then
    storekit_other_failure=1
  elif grep -qE 'SKInternalErrorDomain Code=3|Error saving configuration file' "$LOGS/${storekit_logbase}_$a.log"; then
    storekit_apple_sig=1
  else
    storekit_other_failure=1
  fi
  echo "=== $storekit_logbase failed attempt $a (exit=$status) ==="
  if ! xcrun simctl terminate "$DEV" com.purchasely.demo 2>/dev/null; then
    echo "[cleanup] simctl terminate failed (non-fatal, app likely already stopped)"
  fi
  sleep 3
done

if [ "$storekit_ok" -ne 1 ]; then
  if ! cp "$LOGS/${storekit_logbase}_${storekit_last_attempt}.log" "$LOGS/${storekit_logbase}.log" 2>/dev/null; then
    echo "[cleanup] failed to copy ${storekit_logbase}_${storekit_last_attempt}.log (non-fatal)"
  fi
  if [ "$storekit_apple_sig" -eq 1 ] && [ "$storekit_other_failure" -eq 0 ]; then
    echo "################################################################"
    echo "# S7-iOS BLOCKED (Apple FB22237318)"
    echo "# SKInternalErrorDomain Code=3 / 'Error saving configuration file'"
    echo "# — all $storekit_fail_count failed attempts matched this signature —"
    echo "# confirmed, currently-open Apple/Xcode platform bug (see"
    echo "# task-6-report.md). NOT gating this build."
    echo "################################################################"
    echo "::warning::S7-iOS BLOCKED (Apple FB22237318) — not gating (known external platform bug)"
  else
    echo "::error::S7-iOS (storekit) failed after retries for a reason OTHER than the known FB22237318 signature on at least one attempt — gating"
    fail=1
  fi
fi

echo "=== E2E iOS finished (gating fail=$fail) ==="
exit $fail
