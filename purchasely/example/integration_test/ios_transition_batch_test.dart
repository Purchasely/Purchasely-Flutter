import 'package:flutter_test/flutter_test.dart';

import 'modal_dismissible_ios_test.dart' as modal_dismissible;
import 're_display_ios_test.dart' as re_display;

/// Runs the transition regressions in a single app installation.
void main() {
  group('modal dismissible transition', modal_dismissible.main);
  group('re-display transition', re_display.main);
}
