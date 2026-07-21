#!/bin/bash
# Host-side UI driver for ios_interceptor_batch_test.dart.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
UDID="${1:?usage: $0 <simulator-udid>}"

"$HERE/tap_purchase_ios.sh" "$UDID"
"$HERE/interceptor_actions_driver_ios.sh" "$UDID"
