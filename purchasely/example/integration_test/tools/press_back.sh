#!/bin/bash
# Host-side UI driver for default_dismiss_handler_test.dart.
#
# Waits for a Purchasely paywall to render (any content-desc containing "action:")
# then presses the system BACK button to dismiss it. Run it concurrently:
#   bash integration_test/tools/press_back.sh emulator-5554 &
#   flutter test integration_test/default_dismiss_handler_test.dart -d emulator-5554
#
# Verbose per-iteration logging + dump retry: `uiautomator dump` can transiently
# fail with "could not get idle state" while the paywall is still animating /
# loading (more common on the slow CI emulator), so we retry the dump and log
# every iteration's outcome to survive being killed when the test ends.
#
# Exits 0 after pressing BACK, 1 on timeout.
set -uo pipefail

DEV="${1:-emulator-5554}"
DUMP_DEV="/sdcard/uidump_back.xml"
DUMP_LOCAL="/tmp/uidump_back_${DEV//[^a-zA-Z0-9]/_}.xml"

dump_ui() {
  # Try a few times; uiautomator needs the UI to be idle.
  local out
  for _ in 1 2 3; do
    out=$(adb -s "$DEV" exec-out uiautomator dump "$DUMP_DEV" 2>&1)
    if echo "$out" | grep -q "dumped to"; then
      adb -s "$DEV" pull "$DUMP_DEV" "$DUMP_LOCAL" >/dev/null 2>&1 && return 0
    fi
    sleep 1
  done
  echo "    dump failed: $out"
  return 1
}

# CI-only recovery: on a resource-starved cold AVD some OTHER package (the
# launcher, in every run analyzed for task-9) can ANR mid-suite. Its "App Not
# Responding" system dialog then owns window focus for the REST of the job —
# every BACK/tap this driver sends lands on that dialog, not the app under
# test, forever (see task-9-android-report.md: identical mCurrentFocus window
# IDs across 5 different suites in one CI run). force-stop the ANR'd package
# (never our own app) so the dialog is torn down and focus returns to the
# foreground app; a no-op when nothing is stuck.
clear_stuck_anr() {
  local pkg
  pkg=$(adb -s "$DEV" shell dumpsys window 2>/dev/null |
    grep -o 'Application Not Responding: [^}]*' | head -1 |
    sed 's/Application Not Responding: //' | tr -d '\r ')
  if [ -n "$pkg" ] && [ "$pkg" != "com.purchasely.demo" ]; then
    echo "[press_back] $pkg is ANR'd and stealing focus, force-stopping it"
    adb -s "$DEV" shell am force-stop "$pkg" 2>/dev/null
    sleep 1
  fi
}

for i in $(seq 1 90); do
  clear_stuck_anr
  if dump_ui; then
    if grep -q 'action:' "$DUMP_LOCAL" 2>/dev/null; then
      echo "[press_back] paywall detected (iter $i), pressing BACK"
      sleep 1
      adb -s "$DEV" shell input keyevent 4
      echo "[press_back] BACK pressed ✓"
      exit 0
    else
      n=$(grep -c '<node' "$DUMP_LOCAL" 2>/dev/null || echo 0)
      echo "[press_back] iter $i: dump ok ($n nodes), no 'action:' yet"
      if [ "$i" = "5" ]; then
        echo "    [diag] focus: $(adb -s "$DEV" shell dumpsys window 2>/dev/null | grep -E 'mCurrentFocus|mFocusedApp' | tr -d '\r')"
        echo "    [diag] dump head: $(head -c 1200 "$DUMP_LOCAL" 2>/dev/null | tr -d '\n')"
      fi
    fi
  else
    echo "[press_back] iter $i: dump unavailable, retrying"
  fi
  sleep 1
done
echo "[press_back] paywall not detected after polling"
exit 1
