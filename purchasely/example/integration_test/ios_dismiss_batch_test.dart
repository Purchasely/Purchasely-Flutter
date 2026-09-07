import 'package:flutter_test/flutter_test.dart';

import 'default_dismiss_handler_ios_test.dart' as default_dismiss;
import 'default_dismiss_via_display_ios_test.dart' as display_dismiss;
import 'local_dismiss_handler_ios_test.dart' as local_dismiss;

/// Runs the three dismiss scenarios in a single app installation.
void main() {
  group('default dismiss handler', default_dismiss.main);
  group('default dismiss via display', display_dismiss.main);
  group('local dismiss handler', local_dismiss.main);
}
