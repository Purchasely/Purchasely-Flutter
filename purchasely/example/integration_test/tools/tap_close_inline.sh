#!/bin/bash
# Host-side UI driver: taps the inline paywall's close (✕) button. Detects the
# smallest standalone close node (content-desc exactly "action:close" or
# "action:close_all"), logs it, taps it, then reports if the paywall is gone.
set -uo pipefail
DEVICE="${1:-emulator-5554}"
OUT="${2:-/tmp/inline_tap}"
ADB="adb -s $DEVICE"
mkdir -p "$OUT"

find_close() {
  python3 - "$1" <<'PY'
import re, sys
xml = sys.argv[1] if len(sys.argv) > 1 else ""
best = None
for m in re.finditer(r'content-desc="([^"]*)"[^>]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"', xml):
    desc = m.group(1).strip()
    x1, y1, x2, y2 = map(int, m.groups()[1:])
    if desc in ("action:close", "action:close_all"):
        area = (x2 - x1) * (y2 - y1)
        if best is None or area < best[0]:
            best = (area, (x1 + x2) // 2, (y1 + y2) // 2, desc)
if best:
    print(f"{best[1]} {best[2]} {best[3]}")
PY
}

for i in $(seq 1 60); do
  raw=$($ADB exec-out uiautomator dump /dev/tty 2>/dev/null)
  if echo "$raw" | grep -q 'action:'; then
    echo "$raw" | tr '>' '>\n' | grep -oE 'content-desc="[^"]*"' | sort -u > "$OUT/descs.txt"
    res=$(find_close "$raw" || true)
    if [ -n "$res" ]; then
      cx=$(echo "$res" | awk '{print $1}'); cy=$(echo "$res" | awk '{print $2}'); act=$(echo "$res" | awk '{print $3}')
      $ADB shell screencap -p /sdcard/t.png 2>/dev/null; $ADB pull /sdcard/t.png "$OUT/before.png" 2>/dev/null
      echo "[tap] close button = '$act' at ($cx,$cy); tapping…"
      $ADB shell input tap "$cx" "$cy"
      sleep 3
      if $ADB exec-out uiautomator dump /dev/tty 2>/dev/null | grep -q 'action:'; then
        echo "[tap] paywall STILL present"
      else
        echo "[tap] paywall GONE"
      fi
      exit 0
    fi
    echo "[tap] no standalone close node yet (iter $i); descs:"; cat "$OUT/descs.txt"
  else
    echo "[tap] paywall not detected (iter $i)"
  fi
  sleep 1
done
echo "[tap] close never found"; exit 1
