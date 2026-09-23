import 'package:flutter_test/flutter_test.dart';

import 'drawer_close_ios_test.dart' as drawer_close;
import 'modal_dismissible_ios_test.dart' as modal_dismissible;
import 're_display_ios_test.dart' as re_display;

/// Runs the transition regressions in a single app installation.
void main() {
  group('modal dismissible transition', modal_dismissible.main);
  group('re-display transition', re_display.main);
  // Last: on a broken iOS SDK its leftover window would swallow later taps.
  group('Console drawer closed by a real tap', drawer_close.main);
}
