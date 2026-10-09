// E2E: Purchasely.emit() reaches the native bridge and the bridge accepts the format.
//
// The native SDK owns what happens to the event. This suite only checks the bridge:
// the plugin answers the `emit` call with a result on iOS and Android, so a completed
// future means the native side knew the method and the argument shape. An unknown
// method or a bad argument would throw.
//
// Run:
//   flutter test integration_test/emit_test.dart -d <device>

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:purchasely_flutter/purchasely_flutter.dart';

import 'helpers/e2e_start.dart';

const String kApiKey = '0ad0594b-3b3d-4fea-8ee1-4b5df91efe87';
const String kEmitName = 'e2e_emit_probe';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final configured = await startWithRetry(() => Purchasely.apiKey(kApiKey)
        .runningMode(PLYRunningMode.full)
        .logLevel(PLYLogLevel.debug)
        .stores([PLYStore.google]).start());
    expect(configured, isTrue,
        reason: 'SDK should configure against the real backend');
  });

  testWidgets('emit with every property type is accepted by the bridge',
      (tester) async {
    await tester.runAsync(() async {
      await Purchasely.emit(kEmitName, {
        'e2e_string': 'text',
        'e2e_int': 42,
        'e2e_double': 1.5,
        'e2e_bool': true,
        'e2e_list': [1, 'two', false],
        'e2e_map': {'nested': 'value'},
        'e2e_null': null,
      });
    });
  });

  testWidgets('emit without properties is accepted by the bridge',
      (tester) async {
    await tester.runAsync(() async {
      await Purchasely.emit(kEmitName);
    });
  });

  testWidgets('emit with a DateTime property throws on the Dart side',
      (tester) async {
    await tester.runAsync(() async {
      await expectLater(
          Purchasely.emit(kEmitName, {'e2e_date': DateTime.now()}),
          throwsA(anything));
    });
  });
}
