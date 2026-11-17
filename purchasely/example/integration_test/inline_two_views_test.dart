// E2E (Android): two inline PLYPresentationView widgets created in the same
// frame each report their OWN dismissal.
//
// The native SDK view reads its outcome callback from a global request when it
// attaches, and each `buildView` replaces that request. Hybrid composition
// creates every platform view of a frame (`NativeView.init`) before it attaches
// any of them. When the plugin built the SDK view in `init`, view A took the
// callback of view B, so A's dismissal reached Dart with B's requestId.
//
// The SDK sends the outcome of an embedded view only when it is the LAST
// attached Purchasely view (`PLYPresentationView.isRootView()`). So the test
// removes B first (no event expected: A is still attached), then A (A is
// now the root view and sends its outcome).
//   - With the fix: request A's onDismissed fires, request B's does not.
//   - Before the fix: request B's onDismissed fires, request A's never does.
//
// Same frame: the live test binding draws only pumped frames
// (`LiveTestWidgetsFlutterBindingFramePolicy.onlyPumps`). The test waits until
// both preloads are done WITHOUT pumping, then pumps ONE frame, which builds
// both PlatformViewLinks and sends both `create` messages before any attach.
//
// No native UI interaction (no uiautomator driver).
//
// Run:
//   flutter test integration_test/inline_two_views_test.dart -d <device> \
//     --dart-define=PLY_KEY=... --dart-define=PLY_PLACEMENT=...

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:purchasely_flutter/native_view_widget.dart';
import 'package:purchasely_flutter/purchasely_flutter.dart';

import 'helpers/e2e_start.dart';

const String kApiKey = String.fromEnvironment('PLY_KEY',
    defaultValue: 'fcb39be4-2ba4-4db7-bde3-2a5a1e20745d');
const String kPlacement =
    String.fromEnvironment('PLY_PLACEMENT', defaultValue: 'promo_offers');

class _Probe {
  final loaded = Completer<void>();
  final presented = Completer<void>();
  PLYPresentationOutcome? dismissed;
  late final PLYPresentationRequest request;

  _Probe() {
    request = PLYPresentationBuilder.placement(kPlacement)
        .onLoaded((presentation, error) {
      if (!loaded.isCompleted) loaded.complete();
    }).onPresented((presentation, error) {
      if (presentation != null && !presented.isCompleted) presented.complete();
    }).onDismissed((outcome) {
      dismissed = outcome;
    }).build();
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.onlyPumps;

  setUpAll(() async {
    final configured = await startWithRetry(() => Purchasely.apiKey(kApiKey)
        .runningMode(PLYRunningMode.full)
        .logLevel(PLYLogLevel.debug)
        .allowDeeplink(true)
        .stores([PLYStore.google]).start());
    expect(configured, isTrue);
  });

  testWidgets(
      'two inline views created in the same frame each report their own '
      'onDismissed', (tester) async {
    await tester.runAsync(() async {
      final a = _Probe();
      final b = _Probe();
      final showA = ValueNotifier<bool>(true);
      final showB = ValueNotifier<bool>(true);

      Widget slot(ValueNotifier<bool> show, _Probe probe) => Expanded(
            child: ValueListenableBuilder<bool>(
              valueListenable: show,
              builder: (_, visible, __) => visible
                  ? PLYPresentationView(request: probe.request)
                  : const SizedBox.shrink(),
            ),
          );

      // Both widgets mount and start their preload in this frame.
      await tester.pumpWidget(MaterialApp(
        home:
            Scaffold(body: Column(children: [slot(showA, a), slot(showB, b)])),
      ));

      // Wait for both preloads without pumping: no frame builds a platform
      // view until both are ready.
      await Future.wait([a.loaded.future, b.loaded.future]).timeout(
          const Duration(seconds: 30),
          onTimeout: () => throw StateError('a preload never finished'));
      // The preload reply follows its onLoaded event; let both resolve.
      await Future<void>.delayed(const Duration(seconds: 1));

      // ONE frame: both PlatformViewLinks are built, both `create` calls go out.
      await tester.pump();
      for (var i = 0; i < 80; i++) {
        await tester.pump(const Duration(milliseconds: 250));
        if (a.presented.isCompleted && b.presented.isCompleted) break;
      }
      expect(a.presented.isCompleted && b.presented.isCompleted, isTrue,
          reason: 'both inline views must render before the dismiss checks');

      // Remove B first: A stays attached, so the SDK sends no outcome for B.
      showB.value = false;
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }

      // Remove A: it is now the last Purchasely view and sends its outcome.
      showA.value = false;
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 250));
        if (a.dismissed != null || b.dismissed != null) break;
      }
      // Leave time for a stray event to arrive.
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }

      debugPrint('two inline views: dismissedA=${a.dismissed?.closeReason} '
          'dismissedB=${b.dismissed?.closeReason}');
      expect(a.dismissed, isNotNull,
          reason: 'view A was removed: request A must receive onDismissed. '
              'If null, view A took the outcome callback of view B.');
      expect(b.dismissed, isNull,
          reason: "request B must not receive view A's dismissal");

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  });
}
