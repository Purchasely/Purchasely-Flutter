// E2E (Android + iOS): inline paywall rendered via PLYPresentationView.
//
// Unlike the modal display() suites, the inline path MOUNTS the widget so the
// native platform view embeds inside the Flutter surface (hybrid composition on
// Android, UiKitView on iOS). This test verifies the inline view renders end to
// end against the real backend: it preloads, mounts, and fires onPresented with
// a valid screenId.
//
// NOTE on the close (✕) flow: tapping the native close button cannot be driven
// from inside `integration_test` — the harness does not deliver adb/idb taps to
// the embedded platform view. The close → onCloseRequested → pop flow is
// therefore verified in the REAL app (flutter run) on both platforms; see
// INLINE_PAYWALL_CLOSE.md. This test guards the render path, which IS testable.
//
// Parametric via --dart-define so it can target any key/placement:
//   flutter test integration_test/inline_paywall_test.dart -d <device> \
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

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final configured = await startWithRetry(() => Purchasely.apiKey(kApiKey)
        .runningMode(PLYRunningMode.full)
        .logLevel(PLYLogLevel.debug)
        .allowDeeplink(true)
        .stores([PLYStore.google]).start());
    expect(configured, isTrue);
  });

  testWidgets('inline PLYPresentationView preloads, mounts and presents',
      (tester) async {
    await tester.runAsync(() async {
      final presented = Completer<PLYPresentation>();

      final request = PLYPresentationBuilder.placement(kPlacement)
          .onPresented((presentation, error) {
        if (presentation != null && !presented.isCompleted) {
          presented.complete(presentation);
        }
      }).build();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                const SizedBox(height: 60, child: Center(child: Text('ABOVE'))),
                Expanded(child: PLYPresentationView(request: request)),
                const SizedBox(height: 60, child: Center(child: Text('BELOW'))),
              ],
            ),
          ),
        ),
      );

      // Let the platform view mount + preload + render.
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 250));
        if (presented.isCompleted) break;
      }

      final presentation = await presented.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw StateError(
            'inline onPresented never fired — the embedded view did not render'),
      );

      expect(presentation.screenId, isNotNull);
      debugPrint('inline rendered screenId=${presentation.screenId}');

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  });
}
