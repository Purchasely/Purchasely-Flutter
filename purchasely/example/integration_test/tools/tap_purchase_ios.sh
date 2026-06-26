#!/bin/bash
# Host-side UI driver for interceptor_trigger_ios_test.dart.
#
# The Purchasely iOS paywall is custom-rendered: its accessibility tree exposes
# only StaticText elements (AXLabel + frame), NOT interactive elements with
# accessibility identifiers. So — unlike Android where uiautomator sees the
# content-desc "action:purchase" — on iOS we locate the purchase CTA by its
# visible label and tap the centre of its frame (the label overlays the button).
#
# Uses `idb` (pip install fb-idb) + idb-companion (brew install idb-companion).
# `ui describe-all --json` returns a FLAT array; a wrapper sets up an asyncio
# event loop before idb's main() runs, fixing the RuntimeError on Python 3.12+.
#
# Run concurrently with the test:
#   bash integration_test/tools/tap_purchase_ios.sh <sim-udid> &
#   flutter test integration_test/interceptor_trigger_ios_test.dart -d <sim-udid>
#
# Exits 0 after a successful tap, 1 on timeout.
set -uo pipefail

UDID="${1:?usage: $0 <simulator-udid>}"
# Purchase CTA labels for the integration_test_audiences placement (exact match,
# case-insensitive). The paywall's purchase button is labelled "Continue".
CTA_LABELS="Continue|Continuer|Subscribe|S'abonner|Unlock now"

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
  coords=$(AXJSON="$raw" CTA="$CTA_LABELS" python3 <<'PY'
import os, json

labels = [l.strip().lower() for l in os.environ["CTA"].split("|")]
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
  echo "[tap_purchase_ios] found purchase CTA at ($x, $y), tapping…"
  run_idb ui tap "$x" "$y" --udid "$UDID" 2>&1
  echo "[tap_purchase_ios] tapped ✓"
  return 0
}

for i in $(seq 1 90); do
  if find_and_tap; then
    exit 0
  fi
  echo "[tap_purchase_ios] purchase CTA not found yet (iter $i/90), retrying…"
  sleep 1
done

echo "[tap_purchase_ios] purchase CTA ($CTA_LABELS) not found after 90 s"
exit 1
