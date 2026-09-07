#!/bin/bash
# Waits for a Dart readiness marker, then taps deterministic screen coordinates.
set -euo pipefail

UDID="${1:?usage: $0 <simulator-udid> <suite-log-marker> <x> <y> [tap-count]}"
MARKER="${2:?usage: $0 <simulator-udid> <suite-log-marker> <x> <y> [tap-count]}"
X="${3:?usage: $0 <simulator-udid> <suite-log-marker> <x> <y> [tap-count]}"
Y="${4:?usage: $0 <simulator-udid> <suite-log-marker> <x> <y> [tap-count]}"
TAP_COUNT="${5:-1}"
SUITE_LOG="${SUITE_LOG:?SUITE_LOG must point to the active Flutter test log}"

run_idb() {
  python3 - "$@" <<'__PYEOF__'
import asyncio, sys
loop = asyncio.new_event_loop()
asyncio.set_event_loop(loop)
from idb.cli.main import main
sys.exit(main())
__PYEOF__
}

app_geometry() {
  local screenshot="/tmp/tap_after_marker_ios_$$.png"
  local pixel_width pixel_height scale width height
  if ! xcrun simctl io "$UDID" screenshot "$screenshot" >/dev/null 2>&1; then
    return 1
  fi
  pixel_width=$(sips -g pixelWidth "$screenshot" 2>/dev/null | awk '/pixelWidth:/ {print $2}')
  pixel_height=$(sips -g pixelHeight "$screenshot" 2>/dev/null | awk '/pixelHeight:/ {print $2}')
  rm -f "$screenshot"

  for scale in 3 2; do
    width=$((pixel_width / scale))
    height=$((pixel_height / scale))
    if [ "$width" -ge 320 ] && [ "$width" -le 500 ] &&
       [ "$height" -ge 568 ] && [ "$height" -le 1100 ]; then
      echo "$width $height"
      return 0
    fi
  done
  return 1
}

for _ in $(seq 1 120); do
  if [ -f "$SUITE_LOG" ] && grep -q "$MARKER" "$SUITE_LOG"; then
    geom=$(app_geometry)
    if [ -n "$geom" ]; then
      width=$(echo "$geom" | awk '{print $1}')
      height=$(echo "$geom" | awk '{print $2}')
    else
      width=390
      height=852
    fi
    scaled_x=$((X * width / 390))
    scaled_y=$((Y * height / 852))
    echo "[tap_after_marker_ios] observed $MARKER; app=${width}x${height}, tapping ($scaled_x,$scaled_y) $TAP_COUNT time(s)"
    for n in $(seq 1 "$TAP_COUNT"); do
      run_idb ui tap "$scaled_x" "$scaled_y" --udid "$UDID" 2>&1
      echo "[tap_after_marker_ios] tap $n/$TAP_COUNT sent ✓"
      sleep 1
    done
    exit 0
  fi
  sleep 1
done

echo "[tap_after_marker_ios] missing $MARKER after 120s"
exit 1
