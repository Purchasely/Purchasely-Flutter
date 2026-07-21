#!/bin/bash
# CI entrypoint for the Android E2E suite, invoked by the emulator-runner once the
# emulator has booted (see .github/workflows/e2e-android.yml). Tees per-suite logs
# to integration_test/ci-logs/ for artifact upload.
#
# Gating model: ALL suites are HARD gates. (The previous best-effort /
# silent-::warning:: model for the uiautomator-driven suites is forbidden by
# the mission — a suite that never fails a build is not a test. The green
# baseline run analyzed in the Task 7 CI-hang diagnosis showed these suites
# already pass within the existing 3-attempt retry budget, consuming at most
# one retry for normal emulator flakiness — promoting them to hard gates does
# not require any suite-level redesign.)
#
# Per-attempt timeout: each `flutter test` invocation is bounded to $TIMEOUT
# seconds (default 600, override via env e.g. `TIMEOUT=5 ...` for local
# debugging of the watchdog itself). GNU `timeout` is not assumed to be
# present (this script also runs, unmodified in structure, as the model for
# ci_run_e2e_ios.sh on the macOS runner, which has no `timeout` at all) — see
# run_with_timeout() below for the portable bash implementation. The
# existing 3x retry loop applies to a timed-out attempt exactly like any
# other failure.
#
# Root cause addressed by this file (see Task 7 diagnosis,
# scratchpad ci-hang-diagnosis.md): this script's retry/loop logic was never
# the bug. The hang was `.github/workflows/e2e-android.yml` pinning
# flutter-version 3.24.x post-AGP9 (#130), which broke `compileGroovy` on
# Gradle 9 in ~7s but only surfaced 12 minutes later via flutter_tools'
# generic per-test timeout. That's fixed in the workflow file itself
# (flutter-version bumped to 3.44.0). The watchdog here is the safety net so
# the NEXT such regression fails fast and loud instead of silently eating the
# 60-minute job budget one 12-minute TimeoutException at a time.
set -uo pipefail

DEV="${1:-emulator-5554}"
TIMEOUT="${TIMEOUT:-600}" # seconds per suite ATTEMPT (not per suite overall)
HERE="$(cd "$(dirname "$0")" && pwd)"
EXAMPLE_DIR="$(cd "$HERE/../.." && pwd)" # → purchasely/example
cd "$EXAMPLE_DIR"

LOGS="integration_test/ci-logs"
mkdir -p "$LOGS"

adb -s "$DEV" wait-for-device
# Suppress the one-time "Immersive mode confirmation" system dialog a fresh
# AVD shows the first time any app goes fullscreen — one less window
# contending for focus alongside the launcher-ANR condition diagnosed in
# task-9-android-report.md (identical mCurrentFocus window IDs for this
# dialog were observed pinned across 5 different failing suites in one CI
# run). Best-effort: harmless if the setting doesn't exist on this API level.
adb -s "$DEV" shell settings put secure immersive_mode_confirmations confirmed 2>/dev/null || true
flutter pub get

# Runs "$@" with a hard $TIMEOUT-second ceiling. Portable (no dependency on
# GNU coreutils' `timeout`, which the macOS E2E-iOS runner lacks by default):
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
# under it (gradle/dart/xcodebuild, background taps) are reached too, not
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
# (invoked as `driver <serial>`; the per-attempt suite log path is exported as
# $SUITE_LOG for drivers that need to synchronize against it, e.g. a
# multi-tap driver polling for a marker line — see interceptor_actions_driver_ios.sh
# on the iOS side for the pattern this generalizes).
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
    run_with_timeout flutter test "$testfile" -d "$DEV" --reporter expanded 2>&1 | tee "$LOGS/${logbase}_$a.log"
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
    if ! adb -s "$DEV" shell am force-stop com.purchasely.demo 2>/dev/null; then
      echo "[cleanup] force-stop failed (non-fatal)"
    fi
    sleep 3
  done
  if ! cp "$LOGS/${logbase}_${attempts}.log" "$LOGS/${logbase}.log" 2>/dev/null; then
    echo "[cleanup] failed to copy ${logbase}_${attempts}.log (non-fatal)"
  fi
  return 1
}

fail=0

echo "=== Suite 1/12: Dart<->Android bridge (T1-T20) — HARD gate ==="
run_suite "bridge" integration_test/dart_android_bridge_test.dart "" bridge || fail=1

echo "=== Suite 2/12: cold-start deeplink (builder.handleDeeplink -> auto-open) — HARD gate ==="
# Deterministic: the SDK opens the paywall itself from the cold-start deeplink and
# the test only asserts on analytics events (no flaky uiautomator driver).
run_suite "deeplink_cold_start" integration_test/deeplink_cold_start_test.dart "" deeplink_cold_start || fail=1

echo "=== Suite 3/12: user-attribute listener (set/removed events) — HARD gate ==="
# Deterministic: setting/clearing an attribute makes the native SDK emit a change
# event the listener must receive (no UI interaction, no driver).
run_suite "user_attribute_listener" integration_test/user_attribute_listener_test.dart "" user_attribute_listener || fail=1

echo "=== Suite 4/12: interceptor trigger (uiautomator tap) — HARD gate ==="
run_suite "interceptor" integration_test/interceptor_trigger_test.dart \
  tap_purchase.sh interceptor || fail=1

echo "=== Suite 5/12: default dismiss handler via deeplink (system BACK) — HARD gate ==="
run_suite "dismiss" integration_test/default_dismiss_handler_test.dart \
  press_back.sh dismiss || fail=1

echo "=== Suite 6/12: default dismiss handler via fire-and-forget display() (system BACK) — HARD gate ==="
run_suite "dismiss_via_display" integration_test/default_dismiss_via_display_test.dart \
  press_back.sh dismiss_via_display || fail=1

echo "=== Suite 7/12: local dismiss handler wins over default (system BACK) — HARD gate ==="
run_suite "local_dismiss" integration_test/local_dismiss_handler_test.dart \
  press_back.sh local_dismiss || fail=1

echo "=== Suite 8/12: inline view keeps the global event stream flowing (FLT-W-12) — HARD gate ==="
run_suite "inline_events" integration_test/inline_events_test.dart "" inline_events || fail=1

echo "=== Suite 9/12: inline PLYPresentationView render path (preload/mount/present) — HARD gate ==="
# No native driver — deterministic once the inline platform view renders (see
# inline_paywall_test.dart's own header for why the close/x flow is verified
# separately, in the real app, not here).
run_suite "inline_paywall" integration_test/inline_paywall_test.dart "" inline_paywall || fail=1

echo "=== Suite 10/12: re-display of the same handle keeps the ORIGINAL source (PR #136 M2) — HARD gate ==="
# Driver must run TWICE, chained (two display cycles on the same handle) —
# see re_display_test.dart's header. re_display_driver.sh does the chaining.
run_suite "re_display" integration_test/re_display_test.dart \
  re_display_driver.sh re_display || fail=1

echo "=== Suite 11/12: Flow display + dismiss (S2, integration_test_flow) — HARD gate ==="
# flow_close_all.sh drives pattern (A) (direct action:close_all tap from
# "calm"); the Dart suite self-recovers via Purchasely.closeAllScreens() if
# navigation happens first or the tap isn't observed — see that file's
# header/body for why a single driver call is sufficient here.
run_suite "flow_dismiss" integration_test/flow_dismiss_test.dart \
  flow_close_all.sh flow_dismiss || fail=1

echo "=== Suite 12/12: S7 purchase interceptor + restore, honest degradation (no Play Billing) — HARD gate ==="
# Structurally cannot complete a real purchase on this emulator (no Play
# Store); proves the interceptor fires on a real tap and restoreAllProducts
# degrades cleanly within its own bound — see purchase_restore_android_test.dart
# header and task-6-report.md. Deterministic, ~70s wall time.
run_suite "purchase_restore_android" integration_test/purchase_restore_android_test.dart \
  tap_purchase.sh purchase_restore_android || fail=1

echo "=== E2E Android finished (gating fail=$fail) ==="
exit $fail
