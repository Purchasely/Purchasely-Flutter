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
def attr(tag, k):
    m = re.search(k + r'="([^"]*)"', tag)
    return m.group(1) if m else ''

def bounds(tag):
    b = re.search(r'bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"', tag)
    return tuple(map(int, b.groups())) if b else None

nodes = [m.group(0) for m in re.finditer(r'<node\b[^>]*>', xml)]
for tag in nodes:
    b = bounds(tag)
    if b and desc in attr(tag, 'content-desc'):
        print((b[0] + b[2]) // 2, (b[1] + b[3]) // 2)
        sys.exit(0)

# Android SDK >= 6.1.1 (MOB-471) moved the action metadata out of content-desc
# into a view tag uiautomator cannot read. Fallback (same as React Native): the
# smallest clickable SDK node with no label of its own that holds a price text
# ("... per ..."). The smallest: a full-screen clickable container holds the
# prices too.
prices = [bounds(t) for t in nodes if re.search(r'\bper\b', attr(t, 'text')) and bounds(t)]
best = None
for tag in nodes:
    b = bounds(tag)
    if not b or attr(tag, 'package') != 'com.purchasely.demo' or attr(tag, 'clickable') != 'true':
        continue
    if attr(tag, 'text') or attr(tag, 'content-desc'):
        continue
    if any(b[0] <= p[0] and b[1] <= p[1] and p[2] <= b[2] and p[3] <= b[3] for p in prices):
        area = (b[2] - b[0]) * (b[3] - b[1])
        if best is None or area < best[0]:
            best = (area, b)
if best:
    b = best[1]
    sys.stderr.write(f"[tap_purchase] fallback: unlabelled price button {b}\n")
    print((b[0] + b[2]) // 2, (b[1] + b[3]) // 2)
PY
)
    if [ -n "$coords" ]; then
      echo "[tap_purchase] found a purchase button at $coords (iter $i), tapping…"
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
