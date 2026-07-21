#!/bin/bash
# Host-side UI driver for ios_transition_batch_test.dart.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
UDID="${1:?usage: $0 <simulator-udid>}"

"$HERE/modal_dismissible_driver_ios.sh" "$UDID"
"$HERE/re_display_driver_ios.sh" "$UDID"
