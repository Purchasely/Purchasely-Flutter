#!/bin/bash
# Host-side UI driver for ios_dismiss_batch_test.dart.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
UDID="${1:?usage: $0 <simulator-udid>}"

for scenario in default-handler display-handler local-handler; do
  echo "[dismiss_batch_driver_ios] closing paywall for $scenario"
  "$HERE/close_paywall_ios.sh" "$UDID"
done
