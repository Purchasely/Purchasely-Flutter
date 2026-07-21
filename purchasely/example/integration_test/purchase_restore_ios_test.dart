// E2E (S7 — StoreKit purchase + restore, iOS): performs a real local StoreKit2
// transaction through Purchasely.purchase(plan:), then asserts that
// Purchasely.restoreAllProducts() finds it. The separate
// interceptor_trigger_ios_test.dart suite owns the real-paywall-tap → typed
// purchase-interceptor contract; duplicating that UI layer here is not viable
// because this hostless XCUITest must own testmanagerd in order to keep the
// SKTestSession alive, and neither a competing idb client nor XCTest's
// synthetic event activates the custom-rendered CTA on CI.
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
const String kMonthlyPlan = 'monthly';
const String kMonthlyProduct = 'com.purchasely.plus.monthly';

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
      'S7 — direct purchase completes a local StoreKit2 transaction → restore',
      (tester) async {
    await tester.runAsync(() async {
      // RunnerIntegrationTests.m created the SKTestSession before launching
      // this app and disables StoreKit dialogs, so this bridge call completes
      // against Configuration.storekit without UI automation.
      final purchasedPlan = await Purchasely.purchaseWithPlanVendorId(
        vendorId: kMonthlyPlan,
      ).timeout(const Duration(seconds: 180));
      expect(purchasedPlan['vendorId'], kMonthlyPlan);
      expect(purchasedPlan['productId'], kMonthlyProduct,
          reason: 'the completed purchase must be the local StoreKit product');
      debugPrint('S7 iOS → local StoreKit2 purchase completed '
          'plan.vendorId=${purchasedPlan['vendorId']} '
          'plan.productId=${purchasedPlan['productId']}');

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
