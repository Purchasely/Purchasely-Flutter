// E2E: iOS action interceptor "failed" / "notHandled" completions on a real
// tap — S5/S6 in the Go/No-Go audit.
//
// DISCOVERY #1 (runtime, see task-5-report.md for the full trail): the
// integration_test_audiences PLACEMENT only serves its "Login"/"Restore"
// Navigate screen ("DailyMail+ Pill Landing") to an audience gated on
// `store_name == GOOGLE_PLAY_STORE` — i.e. Android only (confirmed via the
// purchasely admin MCP's get_placement/get_screen on
// app_hIOwu3kgCVv5fupBjZSDcEbx1ohYb, "Test run Purchasely"). On iOS the
// placement always falls through to its default_presentable
// ("072524_exp_magic_cut"), which has no Login button at all — confirmed by
// an `idb ui describe-all` dump against a live run of the existing, CI-green
// interceptor_trigger_ios_test.dart (same placement): AXLabels were exactly
// Continue / Privacy Policy / Terms of Use / Restore purchase / Powered by
// Purchasely, no "Login". So this suite loads "DailyMail+ Pill Landing"
// DIRECTLY via `PLYPresentationBuilder.screen(id)` (a first-class,
// already-precedented SDK entry point — see dart_ios_bridge_test.dart's
// "PLYPresentationBuilder.screen(id) fonctionne" test) instead of
// `.placement(kPlacementAudiences)`. This is the exact same screen content
// Android's INTERCEPTOR.md scenarios (ACT-03..06/09) exercise: a "Login" text
// label wired to `action.type: "deeplink"`, `value: "https://show_login"` —
// surfaced to Dart as `PLYPresentationActionKind.navigate`, NOT the built-in
// `login` kind. NOTE: `.screen(id)` takes the screen's VENDOR_ID
// (`pres_Yzzy4U8bkPAzByL0QS8KJDj6mBWKd6a`), not its admin/console public_id
// (`pres_MnZEWiJ2VDy80A3JwWqsWeh2pKQgQXQ`) — passing the public_id silently
// loads an unrelated bundled screen instead of erroring.
//
// DISCOVERY #2 (runtime): `PLYEventName.LINK_OPENED` fires on EVERY real tap
// of a navigate action regardless of what the interceptor resolves with
// (`success`, `failed`, and `notHandled` all fired it in isolated probes) —
// it is an "action was triggered" analytics event, NOT a signal that the SDK
// actually performed its default open-link handling. So it is NOT usable to
// distinguish S5 (failed) from S6 (notHandled).
//
// The signal that DOES distinguish them, observed directly: resolving
// `notHandled` makes the SDK actually open `https://show_login` — the
// simulator hands off to Safari, which backgrounds the Flutter app. That is
// visible purely in Dart via `WidgetsBindingObserver.didChangeAppLifecycleState`
// (`AppLifecycleState.inactive` → `.hidden` → `.paused`), with NO such
// transition for `failed` (the paywall stays foregrounded and interactive).
// This is still proof via a Dart-in-memory callback, never a screenshot.
//
// CAUTION (see task-5-report.md): once iOS backgrounds the app for real, the
// Flutter engine's own isolate is suspended by the OS — any further
// `await`'d native round-trip (event channel, method channel) in THIS test
// process can hang indefinitely until something brings the app back to the
// foreground. So S6 does NOT attempt a programmatic `presentation.close()`
// after observing the backgrounding — it asserts and returns. Bringing the
// app back to the foreground (so `tearDown`'s interceptor cleanup can
// complete, and Safari doesn't bleed into the next suite) is a host-side
// step run alongside the tap driver, e.g.:
//   xcrun simctl launch <sim-udid> com.purchasely.demo
//
// Both tests share one real tap on "Login" after a Dart readiness marker.
// The host driver scales the control coordinates to the active simulator and
// the tests diverge only in what the interceptor resolves with:
//   A. PLYInterceptResult.failed     — the SDK must NOT fall back to its own
//      default "open the link" handling; the paywall stays up.
//   B. PLYInterceptResult.notHandled — the SDK proceeds with its own default
//      handling of the Navigate action, backgrounding the app to Safari.
//
// Run together with the driver — one tap per test, chained (each test opens
// its own paywall instance) — and a re-foreground step after the second tap:
//   (SUITE_LOG=/tmp/interceptors.log \
//    bash .../interceptor_actions_driver_ios.sh <sim-udid>) &
//   flutter test integration_test/interceptor_actions_ios_test.dart -d <sim-udid>

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:purchasely_flutter/purchasely_flutter.dart';

import 'helpers/e2e_start.dart';

const String kApiKey = '0ad0594b-3b3d-4fea-8ee1-4b5df91efe87';

// The "DailyMail+ Pill Landing" screen's VENDOR_ID — see DISCOVERY #1 above.
const String kLoginRestoreScreenId = 'pres_Yzzy4U8bkPAzByL0QS8KJDj6mBWKd6a';

// AXLabel discovered at runtime via `idb ui describe-all --json` against the
// "DailyMail+ Pill Landing" screen (get_screen: component_label text
// "en": "Login") — the visible button text is exactly "Login", matching the
// Navigate button documented in global-constraints.md (url
// https://show_login).
const String kLoginLabel = 'Login';

/// Records `AppLifecycleState` transitions into a shared log — the Dart-side
/// evidence that the SDK's default Navigate handling actually backgrounded
/// the app to open the link (see DISCOVERY #2 above).
class _LifecycleRecorder extends WidgetsBindingObserver {
  final void Function(AppLifecycleState) onChange;
  _LifecycleRecorder(this.onChange);
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => onChange(state);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    debugPrint('SETUP → calling Purchasely.start()…');
    final configured = await startWithRetry(() => Purchasely.apiKey(kApiKey)
        .runningMode(PLYRunningMode.full)
        .logLevel(PLYLogLevel.debug)
        .storekitVersion(PLYStorekitVersion.storeKit2)
        .start()
        .timeout(const Duration(seconds: 120),
            onTimeout: () =>
                throw StateError('Purchasely.start() timed out after 120s')));
    debugPrint('SETUP → configured=$configured');
    expect(configured, isTrue);
  });

  tearDown(() async {
    await Purchasely.removeAllActionInterceptors();
    Purchasely.stopListeningToEvents();
  });

  testWidgets(
      'S5: navigate interceptor resolved as failed — SDK must not open the link',
      (tester) async {
    await tester.runAsync(() async {
      final callbackOrder = <String>[];
      PLYInterceptorInfo? capturedInfo;
      PLYActionPayload? capturedPayload;
      var presented = false;
      var dismissed = false;

      final lifecycle =
          _LifecycleRecorder((state) => callbackOrder.add('lifecycle:$state'));
      WidgetsBinding.instance.addObserver(lifecycle);

      Purchasely.listenToEvents((event) {
        callbackOrder.add('event:${event.name}');
      });

      await Purchasely.interceptAction(
        PLYPresentationActionKind.navigate,
        (info, payload) async {
          callbackOrder.add('interceptor:triggered');
          capturedInfo = info;
          capturedPayload = payload;
          callbackOrder.add('interceptor:resolved(failed)');
          return PLYInterceptResult.failed;
        },
      );

      final request = PLYPresentationBuilder.screen(kLoginRestoreScreenId)
          .onPresented((p, e) {
        if (p != null) {
          presented = true;
          callbackOrder.add('presented');
        }
      }).onDismissed((o) {
        dismissed = true;
        callbackOrder.add('dismissed(${o.closeReason})');
      }).build();
      final presentation = await request.preload();

      // Load-proof: fail loud and clear if the SDK silently served its
      // bundled fallback instead of "DailyMail+ Pill Landing" (e.g. the
      // screen was renamed/deactivated) — otherwise S5 dies 40s+90s later as
      // an illegible driver timeout instead of a crisp assertion failure.
      expect(presentation.screenId, isNotNull);
      expect(
        presentation.type,
        isNot(anyOf(
            PLYPresentationType.fallback, PLYPresentationType.deactivated)),
        reason: 'screen $kLoginRestoreScreenId not served — renamed/'
            'deactivated? (S5/S6 would otherwise die as an illegible driver '
            'timeout)',
      );

      PLYPresentationOutcome? outcome;
      // Fire-and-forget: the whole point of test A is that this stays pending
      // (the paywall must remain displayed) until the programmatic close below.
      // ignore: unawaited_futures
      presentation
          .display(const PLYTransition.fullScreen())
          .then((o) => outcome = o);

      final presentSw = Stopwatch()..start();
      while (!presented && presentSw.elapsed < const Duration(seconds: 40)) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      expect(presented, isTrue, reason: 'paywall should present');
      debugPrint('INTERCEPTOR-S5-READY');

      // The concurrent driver taps "Login" (a Navigate action, not the
      // built-in `login` kind). Poll for the interceptor to fire.
      final fireSw = Stopwatch()..start();
      while (capturedPayload == null &&
          fireSw.elapsed < const Duration(seconds: 40)) {
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }

      expect(capturedPayload, isNotNull,
          reason: 'navigate interceptor should fire on a real tap on '
              '"$kLoginLabel" — driver: tools/tap_after_marker_ios.sh');
      expect(capturedPayload, isA<PLYNavigatePayload>(),
          reason: 'the "Login" button is a Navigate action, not built-in '
              'login');
      final navigate = capturedPayload! as PLYNavigatePayload;
      expect(navigate.kind, PLYPresentationActionKind.navigate);
      // PR #136 enriched the iOS interceptor payload for navigate actions —
      // url (and title, when the native screen carries one) must now be
      // present on the typed payload.
      expect(navigate.url, 'https://show_login');
      expect(capturedInfo, isNotNull);
      debugPrint('[S5/failed] captured payload → url=${navigate.url} '
          'title=${navigate.title} contentId=${capturedInfo!.contentId}');

      // Give the SDK a window to (not) act on the "failed" resolution before
      // asserting its absence — the app must stay foregrounded throughout.
      await Future<void>.delayed(const Duration(seconds: 8));

      expect(
        callbackOrder.any((e) => e.startsWith('lifecycle:')),
        isFalse,
        reason: 'PLYInterceptResult.failed must suppress the SDK\'s default '
            '"open link" handling — the app must never background (no '
            'AppLifecycleState transition), unlike S6/notHandled',
      );
      expect(dismissed, isFalse,
          reason: 'a failed navigate action must leave the paywall displayed '
              '(no dismissal)');
      expect(outcome, isNull,
          reason: 'display() must still be pending — the paywall stayed up');

      // Clean, programmatic close (siblings show both close_paywall_ios.sh
      // and programmatic close; this test already holds a presentation
      // handle, so programmatic close is the simplest option here). Safe
      // here — unlike S6, the app never backgrounded, so the native
      // round-trip can't hang.
      await presentation.close();
      final closeSw = Stopwatch()..start();
      while (outcome == null && closeSw.elapsed < const Duration(seconds: 15)) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      expect(outcome, isNotNull,
          reason: 'presentation.close() should resolve display()');

      debugPrint('[S5/failed] callback order: $callbackOrder');
      expect(
        callbackOrder.indexOf('interceptor:triggered') <
            callbackOrder.indexOf('interceptor:resolved(failed)'),
        isTrue,
        reason: 'the interceptor must be triggered before it resolves',
      );

      WidgetsBinding.instance.removeObserver(lifecycle);
    });
  });

  testWidgets(
      'S6: navigate interceptor resolved as notHandled — SDK opens the link',
      (tester) async {
    await tester.runAsync(() async {
      final callbackOrder = <String>[];
      PLYInterceptorInfo? capturedInfo;
      PLYActionPayload? capturedPayload;
      var presented = false;
      var backgrounded = false;

      final lifecycle = _LifecycleRecorder((state) {
        callbackOrder.add('lifecycle:$state');
        if (state == AppLifecycleState.paused ||
            state == AppLifecycleState.hidden ||
            state == AppLifecycleState.inactive) {
          backgrounded = true;
        }
      });
      WidgetsBinding.instance.addObserver(lifecycle);

      Purchasely.listenToEvents((event) {
        callbackOrder.add('event:${event.name}');
      });

      await Purchasely.interceptAction(
        PLYPresentationActionKind.navigate,
        (info, payload) async {
          callbackOrder.add('interceptor:triggered');
          capturedInfo = info;
          capturedPayload = payload;
          callbackOrder.add('interceptor:resolved(notHandled)');
          return PLYInterceptResult.notHandled;
        },
      );

      final request = PLYPresentationBuilder.screen(kLoginRestoreScreenId)
          .onPresented((p, e) {
        if (p != null) {
          presented = true;
          callbackOrder.add('presented');
        }
      }).build();
      final presentation = await request.preload();

      // Load-proof: fail loud and clear if the SDK silently served its
      // bundled fallback instead of "DailyMail+ Pill Landing" (e.g. the
      // screen was renamed/deactivated) — otherwise S6 dies 40s+90s later as
      // an illegible driver timeout instead of a crisp assertion failure.
      expect(presentation.screenId, isNotNull);
      expect(
        presentation.type,
        isNot(anyOf(
            PLYPresentationType.fallback, PLYPresentationType.deactivated)),
        reason: 'screen $kLoginRestoreScreenId not served — renamed/'
            'deactivated? (S5/S6 would otherwise die as an illegible driver '
            'timeout)',
      );

      // Fire-and-forget: NOT awaited, and no result is ever read. Once the
      // SDK backgrounds the app (see CAUTION above), this isolate may be
      // suspended before display()'s own future would resolve — this test
      // only needs the interceptor + lifecycle evidence, not the dismiss
      // outcome, so it deliberately never blocks on it.
      // ignore: unawaited_futures, unused_local_variable
      presentation.display(const PLYTransition.fullScreen());

      final presentSw = Stopwatch()..start();
      while (!presented && presentSw.elapsed < const Duration(seconds: 40)) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      expect(presented, isTrue, reason: 'paywall should present');
      debugPrint('INTERCEPTOR-S6-READY');

      // The concurrent driver taps "Login" again (this test's own paywall
      // instance). Poll for the interceptor to fire.
      final fireSw = Stopwatch()..start();
      while (capturedPayload == null &&
          fireSw.elapsed < const Duration(seconds: 40)) {
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }

      expect(capturedPayload, isNotNull,
          reason: 'navigate interceptor should fire on a real tap on '
              '"$kLoginLabel" — driver: tools/tap_after_marker_ios.sh');
      expect(capturedPayload, isA<PLYNavigatePayload>());
      final navigate = capturedPayload! as PLYNavigatePayload;
      expect(navigate.kind, PLYPresentationActionKind.navigate);
      expect(navigate.url, 'https://show_login');
      expect(capturedInfo, isNotNull);
      debugPrint('[S6/notHandled] captured payload → url=${navigate.url} '
          'title=${navigate.title} contentId=${capturedInfo!.contentId}');

      // notHandled → the SDK proceeds with its own default handling of the
      // Navigate action: it opens the link, backgrounding the app to Safari.
      // Poll briefly for the AppLifecycleState transition — once it fires,
      // this isolate may be suspended by iOS at any moment (see the CAUTION
      // note above), so nothing further is attempted after this.
      final bgSw = Stopwatch()..start();
      while (!backgrounded && bgSw.elapsed < const Duration(seconds: 10)) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }

      debugPrint('[S6/notHandled] callback order: $callbackOrder');
      expect(backgrounded, isTrue,
          reason: 'PLYInterceptResult.notHandled must let the SDK fall back '
              'to its default "open link" handling — the app should '
              'background (AppLifecycleState transition) as it hands off to '
              'Safari, unlike S5/failed where it never does');
      expect(
        callbackOrder.indexOf('interceptor:triggered') <
            callbackOrder.indexOf('interceptor:resolved(notHandled)'),
        isTrue,
        reason: 'the interceptor must be triggered before it resolves',
      );
      final resolvedIdx =
          callbackOrder.indexOf('interceptor:resolved(notHandled)');
      final lifecycleIdx =
          callbackOrder.indexWhere((e) => e.startsWith('lifecycle:'));
      expect(resolvedIdx < lifecycleIdx, isTrue,
          reason: 'the app must only background AFTER the interceptor '
              'resolves notHandled — distinct from S5, where it never '
              'backgrounds at all');

      // No presentation.close() here — see the CAUTION note at the top of
      // this file. Bringing the app back to the foreground (so tearDown's
      // native calls don't hang, and Safari doesn't bleed into the next
      // suite) is a host-side step run alongside the driver.
      WidgetsBinding.instance.removeObserver(lifecycle);
    });
  });
}
