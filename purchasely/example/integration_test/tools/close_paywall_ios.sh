#!/bin/bash
# Host-side UI driver for default_dismiss_handler_ios_test.dart.
#
# The Purchasely iOS paywall is custom-rendered: its accessibility tree exposes
# only StaticText (no close button / no accessibility identifier). So instead of
# tapping a close affordance (as Android's press_back.sh does), we dismiss the
# SDK-opened (deeplink) presentation with a downward swipe — the gesture that
# dismisses a modally-presented sheet on iOS.
#
# Uses `idb` (pip install fb-idb) + idb-companion (brew install idb-companion).
# A wrapper sets up an asyncio event loop before idb's main(), fixing Python
# 3.12+. The AX JSON is passed to the parser via an env var (NOT stdin), since
# `python3 - <<HEREDOC` already consumes stdin to read its own script.
#
# Run concurrently with the test:
#   bash integration_test/tools/close_paywall_ios.sh <sim-udid> &
#   flutter test integration_test/default_dismiss_handler_ios_test.dart -d <sim-udid>
#
# Exits 0 after swiping to dismiss, 1 on timeout.
set -uo pipefail

UDID="${1:?usage: $0 <simulator-udid>}"
# Labels that prove a Purchasely paywall is on screen (locale-independent
# marker first). Once detected, we swipe to dismiss.
PAYWALL_MARKERS="Powered by Purchasely|Restore purchase|Continue"

run_idb() {
  python3 - "$@" <<'__PYEOF__'
import asyncio, sys
loop = asyncio.new_event_loop()
asyncio.set_event_loop(loop)
from idb.cli.main import main
sys.exit(main())
__PYEOF__
}

paywall_geometry() {
  # Prints "W H" (screen size) if a paywall marker is present, else nothing.
  local raw
  raw=$(run_idb ui describe-all --json --udid "$UDID" 2>/dev/null) || return 1
  AXJSON="$raw" MARKERS="$PAYWALL_MARKERS" python3 <<'PY'
import os, json
markers = [m.strip().lower() for m in os.environ["MARKERS"].split("|")]
try:
    data = json.loads(os.environ["AXJSON"])
except Exception:
    raise SystemExit(0)
labels = [(el.get("AXLabel") or "").strip().lower() for el in data]
if any(m in labels for m in markers):
    # The application element carries the full-screen frame.
    for el in data:
        if el.get("type") == "Application":
            f = el.get("frame", {})
            print(f"{int(round(f.get('width', 390)))} {int(round(f.get('height', 844)))}")
            break
    else:
        print("390 844")
PY
}

swipes=0
for i in $(seq 1 60); do
  geom=$(paywall_geometry)
  if [ -n "$geom" ]; then
    w=$(echo "$geom" | awk '{print $1}')
    h=$(echo "$geom" | awk '{print $2}')
    cx=$((w / 2))
    y_start=$((h / 5))
    y_end=$((h - 20))
    # Let the paywall settle, then swipe down to dismiss the modal sheet. A single
    # swipe occasionally doesn't dismiss (gesture starts mid-content), so repeat a
    # few times until the paywall is gone or we've tried enough.
    sleep 1
    echo "[close_paywall_ios] paywall detected (${w}x${h}); swiping down ($cx,$y_start)->($cx,$y_end)…"
    run_idb ui swipe "$cx" "$y_start" "$cx" "$y_end" --duration 0.25 --udid "$UDID" 2>&1
    swipes=$((swipes + 1))
    echo "[close_paywall_ios] swipe $swipes sent ✓"
    [ "$swipes" -ge 5 ] && exit 0
    sleep 2
  else
    # Paywall not present: either not up yet, or already dismissed by our swipe.
    [ "$swipes" -gt 0 ] && { echo "[close_paywall_ios] paywall gone after $swipes swipe(s)"; exit 0; }
    echo "[close_paywall_ios] paywall not detected yet (iter $i/60), retrying…"
    sleep 1
  fi
done

[ "$swipes" -gt 0 ] && exit 0
echo "[close_paywall_ios] paywall not detected after 60 s"
exit 1
