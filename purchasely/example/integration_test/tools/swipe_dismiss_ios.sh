#!/bin/bash
# Host-side UI driver: interactive swipe-dismiss for iOS modal paywalls.
#
# Factored from close_paywall_ios.sh. That script keeps swiping until the
# paywall is gone (best-effort "make it close" driver). This one instead
# sends an EXACT number of swipe-down gestures and exits 0 once they've been
# emitted — it deliberately does NOT assert whether the paywall actually
# closed. Whether a swipe should have dismissed the paywall (dismissible
# modal) or been ignored (non-dismissible modal, PR #136 regression guard) is
# the Dart test's call, not this script's.
#
# Prints `PAYWALL_PRESENT=true|false` after the swipes (re-checking the same
# markers) so the CI log stays diagnosticable even though this script itself
# doesn't assert on it.
#
# Uses `idb` (pip install fb-idb) + idb-companion (brew install idb-companion).
# A wrapper sets up an asyncio event loop before idb's main(), fixing Python
# 3.12+. The AX JSON is passed to the parser via an env var (NOT stdin), since
# `python3 - <<HEREDOC` already consumes stdin to read its own script.
#
# Usage: swipe_dismiss_ios.sh <simulator-udid> [n_swipes]
#   n_swipes defaults to 2.
#   MAX_WAIT_SECONDS controls the pre-swipe paywall poll (default 60).
#
# Run concurrently with the test:
#   bash integration_test/tools/swipe_dismiss_ios.sh <sim-udid> 2 &
#   flutter test integration_test/modal_dismissible_ios_test.dart -d <sim-udid>
#
# Exits 0 once n_swipes gesture(s) have been sent, 1 if the paywall never
# appeared within the poll window.
set -uo pipefail

UDID="${1:?usage: $0 <simulator-udid> [n_swipes]}"
N_SWIPES="${2:-2}"
MAX_WAIT_SECONDS="${MAX_WAIT_SECONDS:-60}"
# Labels that prove a Purchasely paywall is on screen (locale-independent
# marker first).
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
        # Fallback: iPhone-15-class default is safer than iPhone-SE-era 390x844
        # across modern simulators (Pro Max is 430x932; 390x852 is a safe mid-point).
        print("390 852")
PY
}

paywall_present() {
  [ -n "$(paywall_geometry)" ]
}

# Wait for the paywall to appear before swiping.
geom=""
for i in $(seq 1 "$MAX_WAIT_SECONDS"); do
  geom=$(paywall_geometry)
  if [ -n "$geom" ]; then
    break
  fi
  echo "[swipe_dismiss_ios] paywall not detected yet (iter $i/$MAX_WAIT_SECONDS), retrying…"
  sleep 1
done

if [ -z "$geom" ]; then
  echo "[swipe_dismiss_ios] paywall not detected after $MAX_WAIT_SECONDS s"
  echo "PAYWALL_PRESENT=false"
  exit 1
fi

w=$(echo "$geom" | awk '{print $1}')
h=$(echo "$geom" | awk '{print $2}')
cx=$((w / 2))
y_start=$((h / 5))
y_end=$((h - 20))

echo "[swipe_dismiss_ios] paywall detected (${w}x${h}); sending $N_SWIPES swipe-down gesture(s) ($cx,$y_start)->($cx,$y_end)…"
sleep 1
for n in $(seq 1 "$N_SWIPES"); do
  run_idb ui swipe "$cx" "$y_start" "$cx" "$y_end" --duration 0.25 --udid "$UDID" 2>&1
  echo "[swipe_dismiss_ios] swipe $n/$N_SWIPES sent ✓"
  sleep 2
done

if paywall_present; then
  echo "PAYWALL_PRESENT=true"
else
  echo "PAYWALL_PRESENT=false"
fi

exit 0
