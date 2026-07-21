import 'package:flutter_test/flutter_test.dart';

import 'dart_ios_bridge_test.dart' as bridge;
import 'deeplink_cold_start_test.dart' as deeplink;
import 'flow_dismiss_ios_test.dart' as flow_dismiss;
import 'user_attribute_listener_test.dart' as user_attributes;

/// Runs compatible driver-free iOS scenarios in a single app installation.
void main() {
  // This scenario owns the first SDK start because it supplies a launch-time
  // deeplink. All following scenarios use the same Purchasely project.
  group('cold-start deeplink', deeplink.main);
  group('flow dismiss', flow_dismiss.main);
  group('Dart iOS bridge', bridge.main);
  group('user-attribute listener', user_attributes.main);
}
