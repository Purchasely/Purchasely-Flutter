#!/bin/bash
# Host-side UI driver for interceptor_trigger_ios_test.dart.
#
# Polls the simulator accessibility tree for the Purchasely purchase button
# (accessibility ID prefix: ply_action_purchase_) and taps its center.
# Uses `idb` (pip install fb-idb) + idb-companion (brew install idb-companion).
# Includes an asyncio fix for Python 3.12+ where get_event_loop() raises.
#
# Run concurrently with the test:
#   bash integration_test/tools/tap_purchase_ios.sh <sim-udid> &
#   flutter test integration_test/interceptor_trigger_ios_test.dart -d <sim-udid>
#
# Exits 0 after a successful tap, 1 on timeout.
set -uo pipefail

UDID="${1:?usage: $0 <simulator-udid>}"
TARGET_PREFIX="ply_action_purchase_"

# idb wrapper: sets up an event loop before idb's main() runs, fixing the
# RuntimeError("There is no current event loop") on Python 3.12+.
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
  raw=$(run_idb --json ui describe-all --udid "$UDID" 2>/dev/null) || return 1

  # Parse JSON tree, find first element whose AXIdentifier starts with the
  # target prefix, compute its center, then tap.
  coords=$(python3 - "$TARGET_PREFIX" <<'PY'
import sys, json

prefix = sys.argv[1]

def find(node):
    aid = node.get("AXIdentifier", "")
    if aid.startswith(prefix):
        frame = node.get("AXFrame", {})
        x = frame.get("x", 0) + frame.get("width", 0) / 2
        y = frame.get("y", 0) + frame.get("height", 0) / 2
        print(f"{x:.1f} {y:.1f}")
        return True
    for child in node.get("children", []):
        if find(child):
            return True
    return False

try:
    data = json.loads(sys.stdin.read())
    # describe-all returns a list at the root
    roots = data if isinstance(data, list) else [data]
    for root in roots:
        if find(root):
            break
except Exception as e:
    print(f"parse error: {e}", file=sys.stderr)
PY
  <<< "$raw")

  if [ -z "$coords" ]; then
    return 1
  fi

  local x y
  x=$(echo "$coords" | awk '{print $1}')
  y=$(echo "$coords" | awk '{print $2}')
  echo "[tap_purchase_ios] found '$TARGET_PREFIX' at ($x, $y), tapping…"
  run_idb ui tap "$x" "$y" --udid "$UDID" 2>&1
  echo "[tap_purchase_ios] tapped ✓"
  return 0
}

for i in $(seq 1 90); do
  if find_and_tap; then
    exit 0
  fi
  echo "[tap_purchase_ios] button not found yet (iter $i/90), retrying…"
  sleep 1
done

echo "[tap_purchase_ios] button '$TARGET_PREFIX' not found after 90 s"
exit 1
