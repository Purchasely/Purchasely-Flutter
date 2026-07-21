import 'package:flutter_test/flutter_test.dart';

import 'interceptor_actions_ios_test.dart' as interceptor_actions;
import 'interceptor_trigger_ios_test.dart' as interceptor_trigger;

/// Runs the purchase interceptor scenarios in a single app installation.
void main() {
  group('purchase interceptor trigger', interceptor_trigger.main);
  group('interceptor actions', interceptor_actions.main);
}
