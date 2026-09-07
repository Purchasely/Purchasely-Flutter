#!/bin/bash
# Host-side UI driver for ios_dismiss_batch_test.dart.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
UDID="${1:?usage: $0 <simulator-udid>}"

for marker in DISMISS-DEFAULT-READY DISMISS-DISPLAY-READY DISMISS-LOCAL-READY; do
  "$HERE/swipe_after_marker_ios.sh" "$UDID" "$marker"
done
