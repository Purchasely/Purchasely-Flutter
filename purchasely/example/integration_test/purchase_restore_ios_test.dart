// E2E (S7 — StoreKit purchase + restore, iOS): the purchase action interceptor
// fires on a real tap, is allowed to PROCEED (PLYInterceptResult.notHandled,
// the v6 equivalent of the pre-v6 `onProcessAction(true)`) instead of being
// blocked like interceptor_trigger_ios_test.dart does, and the resulting
// PLYPresentationOutcome.purchaseResult is asserted to be `.purchased` — a
// real local StoreKit2 transaction, then `Purchasely.restoreAllProducts()` is
// asserted to return `true`.
//
// --- Execution path (read before running) ---------------------------------
//
// StoreKit Testing configuration files (`Configuration.storekit`, wired into
// the shared `Runner.xcscheme`'s LaunchAction) ONLY apply when the app is
// actually LAUNCHED via that Xcode scheme. Plain `flutter test
// integration_test/x_test.dart -d <sim>` installs and launches the app
// through `flutter_tools`' own device control (`xcrun simctl launch`
// directly), which never touches the Xcode scheme — so the local StoreKit
// config never attaches and any purchase attempt would hit the real
// (sandbox) App Store, which has no `com.purchasely.plus.*` products and no
// signed-in tester on this machine.
//
// The only path that launches the app through the scheme — and therefore
// actually applies Configuration.storekit — is `xcodebuild test`. Flutter
// does not run its own `integration_test` widget tests that way by default;
// the officially documented bridge (see the `integration_test` pub package
// README, "iOS Device Testing" / Firebase Test Lab section) is a **Unit
// Testing Bundle Xcode target with `TEST_HOST` set to the Runner app**,
// hosting the Flutter engine in-process, plus the `INTEGRATION_TEST_IOS_RUNNER`
// macro that turns each Dart test into a native XCTest method. This repo's
// existing `RunnerTests` target is deliberately HOSTLESS (see its own header
// comment + ci.yml: launching the Flutter engine that way previously
// SIGSEGV'd on headless CI simulators), so a SEPARATE target —
// `RunnerIntegrationTests` (purchasely/example/ios/RunnerIntegrationTests/) —
// was added specifically for this suite, additive and untouched otherwise.
//
// Run (see tools/run_storekit_suite_ios.sh for the scripted version):
//
//   cd purchasely/example
//   flutter build ios --config-only --simulator \
//     integration_test/purchase_restore_ios_test.dart
//   cd ios && pod install
//   (bash ../integration_test/tools/tap_purchase_ios.sh <sim-udid> &)
//   xcodebuild test -workspace Runner.xcworkspace -scheme Runner \
//     -only-testing:RunnerIntegrationTests -destination id=<sim-udid>
//
// No separate driver taps the StoreKit purchase-confirmation sheet:
// RunnerIntegrationTests.m sets `SKTestSession.disableDialogs = YES`, which
// auto-confirms the purchase locally. That sheet is a SpringBoard-level
// system UI outside the app process anyway — idb's app-scoped
// `ui describe-all` targets the app under test, not SpringBoard, so driving
// it would need a different (and flakier) mechanism for no additional signal
// here: this suite is proving the SDK's purchase/restore flow, not Apple's
// confirmation dialog.
//
// CI implication (for Task 7): RunnerIntegrationTests is a hostless UI-test
// bundle that launches the app via XCUIApplication().launch(). Unlike the
// TEST_HOST-based RunnerTests (which SIGSEGV'd on headless CI simulators),
// this mechanism may behave differently on CI; CI behavior must be observed
// before trusting it. Task 7 should treat it as best-effort/non-blocking
// (like the other idb-driven suites in ci_run_e2e_ios.sh) until proven
// stable on the actual CI runner image.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:purchasely_flutter/purchasely_flutter.dart';

import 'helpers/e2e_start.dart';

const String kApiKey = '0ad0594b-3b3d-4fea-8ee1-4b5df91efe87';
const String kPlacementAudiences = 'integration_test_audiences';

// Greptile P1 (PR #138): RunnerIntegrationTests.m is a hostless XCTest bundle
// (see its own header) — xcodebuild's exit code only proves the app launched
// and exited/timed out, never whether the `expect()`s below actually passed.
// So this suite reports its own result explicitly: `_completedTests` is
// bumped as the LAST line of each test body (if a test throws — an
// `expect()` failure or anything else — before reaching that line, it never
// counts), and `tearDownAll` below prints exactly one grep'able marker line
// that tools/run_storekit_suite_ios.sh gates the build on.
int _completedTests = 0;
// ponytail: hardcoded to the single testWidgets() below; bump this (and add
// a matching `_completedTests++` as the new test's last line) if a second
// test is ever added to this file.
const int _kTotalTests = 1;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  tearDownAll(() {
    if (_completedTests == _kTotalTests) {
      debugPrint('S7-IOS-RESULT: PASS');
    } else {
      debugPrint(
          'S7-IOS-RESULT: FAIL (completed=$_completedTests/$_kTotalTests)');
    }
  });

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
    expect(configured, isTrue,
        reason: 'SDK should configure against the real backend');
  });

  testWidgets(
      'S7 — purchase interceptor lets the flow proceed → purchased outcome → restore',
      (tester) async {
    await tester.runAsync(() async {
      PLYInterceptorInfo? capturedInfo;
      PLYActionPayload? capturedPayload;
      var presented = false;

      // notHandled = the v6 equivalent of the removed `onProcessAction(true)`:
      // the interceptor observes the action but does NOT short-circuit it, so
      // the native SDK proceeds with its own default purchase flow (a real
      // StoreKit2 transaction against the local Configuration.storekit).
      await Purchasely.interceptAction(
        PLYPresentationActionKind.purchase,
        (info, payload) async {
          capturedInfo = info;
          capturedPayload = payload;
          return PLYInterceptResult.notHandled;
        },
      );

      final request = PLYPresentationBuilder.placement(kPlacementAudiences)
          .onPresented((p, e) => presented = true)
          .build();
      final displayFuture = request.display(const PLYTransition.fullScreen());

      // Wait for the paywall to present.
      final presentSw = Stopwatch()..start();
      while (!presented && presentSw.elapsed < const Duration(seconds: 60)) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      expect(presented, isTrue, reason: 'paywall should present');

      // The concurrent driver (tap_purchase_ios.sh) taps the purchase CTA.
      // Poll for the interceptor to fire with the typed purchase payload.
      final fireSw = Stopwatch()..start();
      while (capturedPayload == null &&
          fireSw.elapsed < const Duration(seconds: 120)) {
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }
      expect(capturedPayload, isA<PLYPurchasePayload>(),
          reason: 'purchase interceptor should fire on the native tap');
      final purchase = capturedPayload as PLYPurchasePayload;
      debugPrint('S7 iOS → interceptor fired (notHandled → proceeding) '
          'plan.vendorId=${purchase.plan.vendorId} '
          'plan.productId=${purchase.plan.productId} '
          'contentId=${capturedInfo?.contentId}');

      // RunnerIntegrationTests.m sets SKTestSession.disableDialogs = YES, so
      // the purchase confirmation is auto-accepted (no separate driver needed).
      // Await the final outcome — the SDK auto-dismisses the paywall once the purchase completes.
      final outcome = await displayFuture.timeout(const Duration(seconds: 180));

      expect(outcome, isA<PLYPresentationOutcome>());
      expect(outcome.error, isNull,
          reason: 'a completed purchase must not carry a display error');
      expect(outcome.purchaseResult, PLYPurchaseResult.purchased,
          reason: 'the local StoreKit2 transaction should be reported as '
              'purchased, not cancelled/restored/none');
      debugPrint('S7 iOS → PLYPresentationOutcome purchaseResult='
          '${outcome.purchaseResult} plan=${outcome.plan?.vendorId} '
          'closeReason=${outcome.closeReason}');

      await Purchasely.removeAllActionInterceptors();

      // restoreAllProducts(): the just-purchased subscription should be found
      // on restore. Bounded timeout — never hang indefinitely.
      final restored = await Purchasely.restoreAllProducts(
          timeout: const Duration(seconds: 60));
      expect(restored, isTrue,
          reason: 'restoreAllProducts should find the just-purchased plan');
      debugPrint('S7 iOS → restoreAllProducts=$restored');

      // Last line of the test body, deliberately: see the module-level
      // comment on `_completedTests` above.
      _completedTests++;
    });
  });
}
