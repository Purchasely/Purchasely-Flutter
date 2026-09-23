#!/bin/bash
# Host-side UI driver for drawer_close_ios_test.dart (T31, Purchasely-iOS#790).
#
# All taps go by coordinates, in tap_after_marker_ios.sh's 390x852 base:
#   button   the drawer's close ✕. The iOS a11y tree exposes only StaticText,
#            so there is no label to find; the fixture is a 70% drawer with
#            the ✕ at its top-right corner.
#   outside  the scrim above the drawer, at 12% of the screen height.
#   probe    the centre of the screen, where the test shows a full-screen
#            Flutter probe after each close. NOT by a11y label on purpose:
#            with the bug, the tree is the leftover SDK window's, and the point
#            is to see whether an OS tap still reaches the app.
#
# Usage: SUITE_LOG=<flutter test log> drawer_close_driver_ios.sh <sim-udid>
set -euo pipefail
UDID="${1:?usage: $0 <sim-udid>}"
HERE="$(cd "$(dirname "$0")" && pwd)"

# ponytail: fixed corner of the 70% drawer fixture; re-measure if the Console screen changes.
bash "$HERE/tap_after_marker_ios.sh" "$UDID" "T31-DRAWER-READY:button" 357 292
bash "$HERE/tap_after_marker_ios.sh" "$UDID" "T31-PROBE-READY:1" 195 426
bash "$HERE/tap_after_marker_ios.sh" "$UDID" "T31-DRAWER-READY:outside" 195 102
bash "$HERE/tap_after_marker_ios.sh" "$UDID" "T31-PROBE-READY:2" 195 426
