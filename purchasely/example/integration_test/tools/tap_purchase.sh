#!/bin/bash
# Host-side UI driver for interceptor_trigger_test.dart.
#
# Polls the device UI for the Purchasely purchase button (content-desc contains
# "action:purchase") and taps its center. Run it concurrently with the test:
#   bash integration_test/tools/tap_purchase.sh emulator-5554 &
#   flutter test integration_test/interceptor_trigger_test.dart -d emulator-5554
#
# Verbose per-iteration logging + dump retry: `uiautomator dump` can transiently
# fail with "could not get idle state" while the paywall is still animating /
# loading (more common on the slow CI emulator), so we retry the dump and log
# every iteration's outcome to survive being killed when the test ends.
#
# Exits 0 after a successful tap, 1 on timeout.
set -uo pipefail

DEV="${1:-emulator-5554}"
DESC="action:purchase"
DUMP_DEV="/sdcard/uidump_tap.xml"
DUMP_LOCAL="/tmp/uidump_tap_${DEV//[^a-zA-Z0-9]/_}.xml"

dump_ui() {
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
    echo "[tap_purchase] $pkg is ANR'd and stealing focus, force-stopping it"
    adb -s "$DEV" shell am force-stop "$pkg" 2>/dev/null
    sleep 1
  fi
}

for i in $(seq 1 90); do
  clear_stuck_anr
  if dump_ui; then
    coords=$(python3 - "$DESC" "$DUMP_LOCAL" <<'PY'
import sys, re
desc, path = sys.argv[1], sys.argv[2]
try:
    xml = open(path, encoding='utf-8').read()
except Exception:
    sys.exit(0)
for m in re.finditer(r'<node\b[^>]*>', xml):
    tag = m.group(0)
    cd = re.search(r'content-desc="([^"]*)"', tag)
    if cd and desc in cd.group(1):
        b = re.search(r'bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"', tag)
        if b:
            x1, y1, x2, y2 = map(int, b.groups())
            print((x1 + x2) // 2, (y1 + y2) // 2)
            break
PY
)
    if [ -n "$coords" ]; then
      echo "[tap_purchase] found '$DESC' at $coords (iter $i), tapping…"
      # coords is emitted as two validated integers by the parser above.
      # shellcheck disable=SC2086
      adb -s "$DEV" shell input tap $coords
      echo "[tap_purchase] tapped ✓"
      exit 0
    else
      n=$(grep -c '<node' "$DUMP_LOCAL" 2>/dev/null || echo 0)
      echo "[tap_purchase] iter $i: dump ok ($n nodes), no '$DESC' yet"
      if [ "$i" = "5" ]; then
        echo "    [diag] focus: $(adb -s "$DEV" shell dumpsys window 2>/dev/null | grep -E 'mCurrentFocus|mFocusedApp' | tr -d '\r')"
        echo "    [diag] dump head: $(head -c 1200 "$DUMP_LOCAL" 2>/dev/null | tr -d '\n')"
      fi
    fi
  else
    echo "[tap_purchase] iter $i: dump unavailable, retrying"
  fi
  sleep 1
done
echo "[tap_purchase] button '$DESC' not found after polling"
exit 1
