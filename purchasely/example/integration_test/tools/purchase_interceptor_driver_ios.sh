#!/bin/bash
# Host-side driver for interceptor_trigger_ios_test.dart.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
UDID="${1:?usage: $0 <simulator-udid>}"

"$HERE/tap_after_marker_ios.sh" \
  "$UDID" INTERCEPTOR-PURCHASE-READY 195 648
