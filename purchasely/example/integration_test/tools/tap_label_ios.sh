#!/bin/bash
# Host-side UI driver: taps the first element whose AXLabel exactly matches
# (case-insensitive) one of a pipe-separated list of labels. Generalization
# of tap_purchase_ios.sh (hardcoded to the purchase CTA's labels) for
# flow_dismiss_ios_test.dart and any other suite that needs to tap a
# specific iOS control by its (runtime-discovered) accessibility label.
#
# The Purchasely iOS paywall/flow screens are custom-rendered: their
# accessibility tree exposes only StaticText elements (AXLabel + frame), not
# interactive elements with accessibility identifiers — so we locate a
# control by its visible label and tap the centre of its frame (the label
# overlays the control).
#
# Uses `idb` (pip install fb-idb) + idb-companion (brew install idb-companion).
# `ui describe-all --json` returns a FLAT array; a wrapper sets up an asyncio
# event loop before idb's main() runs, fixing the RuntimeError on Python 3.12+.
#
# Usage: tap_label_ios.sh <simulator-udid> <label1|label2|...> [max-taps]
#   max-taps defaults to 1 (tap once and exit 0). Pass a higher number for
#   controls where a single tap occasionally doesn't register (mirrors
#   tap_purchase_ios.sh's retry behavior).
#
# Run concurrently with the test:
#   bash integration_test/tools/tap_label_ios.sh <sim-udid> "Close|Fermer" &
#   flutter test integration_test/flow_dismiss_ios_test.dart -d <sim-udid>
#
# Exits 0 after (at least one) successful tap, 1 on timeout.
set -uo pipefail

UDID="${1:?usage: $0 <simulator-udid> <label1|label2|...> [max-taps]}"
LABELS="${2:?usage: $0 <simulator-udid> <label1|label2|...> [max-taps]}"
MAX_TAPS="${3:-1}"

run_idb() {
  python3 - "$@" <<'__PYEOF__'
import asyncio, sys
loop = asyncio.new_event_loop()
asyncio.set_event_loop(loop)
from idb.cli.main import main
sys.exit(main())
__PYEOF__
}

find_and_tap() {
  local raw
  raw=$(run_idb ui describe-all --json --udid "$UDID" 2>/dev/null) || return 1

  # Pass the JSON via an env var, NOT stdin: `python3 - <<HEREDOC` already uses
  # stdin to read the script, so sys.stdin.read() inside would get nothing.
  coords=$(AXJSON="$raw" LBL="$LABELS" python3 <<'PY'
import os, json

labels = [l.strip().lower() for l in os.environ["LBL"].split("|")]
try:
    data = json.loads(os.environ["AXJSON"])
except Exception:
    raise SystemExit(0)

for el in data:
    lab = (el.get("AXLabel") or "").strip().lower()
    if lab in labels:
        f = el.get("frame", {})
        x = f.get("x", 0) + f.get("width", 0) / 2
        y = f.get("y", 0) + f.get("height", 0) / 2
        print(f"{int(round(x))} {int(round(y))}")
        break
PY
)

  if [ -z "$coords" ]; then
    return 1
  fi

  local x y
  x=$(echo "$coords" | awk '{print $1}')
  y=$(echo "$coords" | awk '{print $2}')
  echo "[tap_label_ios] found '$LABELS' at ($x, $y), tapping…"
  run_idb ui tap "$x" "$y" --udid "$UDID" 2>&1
  echo "[tap_label_ios] tapped ✓"
  return 0
}

taps=0
for i in $(seq 1 90); do
  if find_and_tap; then
    taps=$((taps + 1))
    [ "$taps" -ge "$MAX_TAPS" ] && exit 0
    sleep 2
  else
    echo "[tap_label_ios] label ($LABELS) not found yet (iter $i/90), retrying…"
    sleep 1
  fi
done

if [ "$taps" -gt 0 ]; then exit 0; fi
echo "[tap_label_ios] label ($LABELS) not found after 90 s"
exit 1
