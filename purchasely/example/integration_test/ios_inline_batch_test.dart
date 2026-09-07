import 'package:flutter_test/flutter_test.dart';

import 'inline_events_test.dart' as inline_events;
import 'inline_paywall_test.dart' as inline_paywall;

/// Runs inline scenarios sharing the same Purchasely project and installation.
void main() {
  group('inline event stream', inline_events.main);
  group('inline paywall', inline_paywall.main);
}
