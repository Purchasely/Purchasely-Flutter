#!/bin/bash
# Host-side UI driver for default_dismiss_handler_ios_test.dart.
#
# Waits for the Purchasely paywall close button to appear in the simulator
# accessibility tree (accessibility ID: ply_action_close) then taps it.
# Equivalent to pressing system BACK on Android (press_back.sh).
# Uses `idb` (pip install fb-idb) + idb-companion (brew install idb-companion).
# Includes an asyncio fix for Python 3.12+.
#
# Run concurrently with the test:
#   bash integration_test/tools/close_paywall_ios.sh <sim-udid> &
#   flutter test integration_test/default_dismiss_handler_ios_test.dart -d <sim-udid>
#
# Exits 0 after a successful tap, 1 on timeout.
set -uo pipefail

UDID="${1:?usage: $0 <simulator-udid>}"
CLOSE_ID="ply_action_close"

# idb wrapper: fixes Python 3.12+ asyncio.get_event_loop() RuntimeError.
run_idb() {
  python3 - "$@" <<'__PYEOF__'
import asyncio, sys
loop = asyncio.new_event_loop()
asyncio.set_event_loop(loop)
from idb.cli.main import main
sys.exit(main())
__PYEOF__
}

find_and_tap_close() {
  local raw
  raw=$(run_idb --json ui describe-all --udid "$UDID" 2>/dev/null) || return 1

  coords=$(python3 - "$CLOSE_ID" <<'PY'
import sys, json

target = sys.argv[1]

def find(node):
    if node.get("AXIdentifier", "") == target:
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
  # Small delay so the paywall is fully rendered before dismissal.
  sleep 1
  echo "[close_paywall_ios] found '$CLOSE_ID' at ($x, $y), tapping…"
  run_idb ui tap "$x" "$y" --udid "$UDID" 2>&1
  echo "[close_paywall_ios] close tapped ✓"
  return 0
}

for i in $(seq 1 60); do
  if find_and_tap_close; then
    exit 0
  fi
  echo "[close_paywall_ios] close button not found yet (iter $i/60), retrying…"
  sleep 1
done

echo "[close_paywall_ios] '$CLOSE_ID' not found after 60 s"
exit 1
