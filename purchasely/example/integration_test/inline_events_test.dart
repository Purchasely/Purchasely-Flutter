// E2E (Android + iOS): the global Purchasely event stream keeps flowing while an
// inline PLYPresentationView is mounted (regression guard for FLT-W-12).
//
// The inline view registers itself for SDK `.presentationClosed` events. If it
// does so by taking over the single global `setEventCallback` slot (the pre-fix
// iOS behaviour), it CLOBBERS the callback `SwiftEventHandler` uses to forward
// EVERY event to Dart — so a `listenToEvents` listener registered *before* the
// view mounts silently stops receiving events (purchases, plan selections,
// presentation analytics…) for the whole lifetime of the inline view. The fix
// routes the inline view through the independent `PLYEventDelegate` slot, which
// does not conflict with the callback slot.
//
// This test registers a global listener, mounts the inline view, and asserts a
// paywall analytics event STILL reaches that global listener after the view has
// rendered. It fails on the clobber regression and passes with the fix — which
// also empirically validates the assumption that the delegate and callback
// event sinks are independent in the native SDK.
//
// No native UI interaction (no uiautomator/idb driver) — deterministic once the
// inline view renders against the real backend.
//
// Run:
//   flutter test integration_test/inline_events_test.dart -d <device> \
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

  testWidgets(
      'global listenToEvents still receives paywall events while an inline '
      'PLYPresentationView is mounted (FLT-W-12)', (tester) async {
    await tester.runAsync(() async {
      // Register the global listener FIRST — this is the callback the inline
      // view would clobber if it stole the global event slot.
      PLYEvent? globalPaywallEvent;
      Purchasely.listenToEvents((event) {
        if (event.name == PLYEventName.PRESENTATION_VIEWED ||
            event.name == PLYEventName.PRESENTATION_LOADED) {
          globalPaywallEvent ??= event;
        }
      });
      // Let the EventChannel handshake (which arms the native event sink) settle
      // before the inline view mounts.
      await Future<void>.delayed(const Duration(seconds: 1));

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
              ],
            ),
          ),
        ),
      );

      // Pump until the inline view renders AND a paywall event reaches the
      // global listener (or time out).
      for (var i = 0; i < 80; i++) {
        await tester.pump(const Duration(milliseconds: 250));
        if (presented.isCompleted && globalPaywallEvent != null) break;
      }

      final presentation = await presented.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw StateError(
            'inline onPresented never fired — the embedded view did not render'),
      );
      expect(presentation.screenId, isNotNull);

      expect(globalPaywallEvent, isNotNull,
          reason:
              'A paywall event (PRESENTATION_VIEWED/LOADED) must still reach the '
              'global listenToEvents listener while the inline view is mounted. '
              'If null, the inline view clobbered the global event stream '
              '(FLT-W-12 regression).');
      debugPrint('inline event flow OK → ${globalPaywallEvent!.name}');

      Purchasely.stopListeningToEvents();
    });
  });
}
