// Host for the S7 iOS StoreKit purchase/restore suite
// (purchase_restore_ios_test.dart) — see that file's header comment for the
// full investigation writeup. Short version:
//
// StoreKit Testing configuration (Configuration.storekit) wired into the
// scheme's LaunchAction (Apple's own scheme editor calls this concept
// `IDEStoreKitLaunchActionOptionViewController` — a GUI/Debug convenience)
// is NOT honored by `xcodebuild test` run from the command line — confirmed
// empirically across three attempts (hosted unit test + LaunchAction-only +
// LaunchAction-and-TestAction identifiers): every run hit REAL StoreKit
// sandbox auth (`storekitd: ... Sandbox ... No account for TransactionQuery`)
// and the system "Sign in to your Apple Account" sheet, never local test
// products. The scheme wiring only takes effect via Xcode's own GUI Run/Test
// action (a private XPC connection Xcode.app itself establishes) — it is a
// documented gap for CLI-only CI.
//
// The CI-compatible mechanism is Apple's public `StoreKitTest` framework:
// create an `SKTestSession` programmatically, from INSIDE the test process,
// before launching the app under test. This does not depend on Xcode's GUI
// at all and is exactly what this target does in `-setUp`. The scheme's
// LaunchAction StoreKitConfigurationFileReference stays wired too (harmless,
// matches the brief's literal instruction, and covers the interactive
// Xcode GUI path for anyone debugging this suite by hand).
//
// This is also a genuine UI Testing Bundle (`XCUIApplication().launch()`),
// not the Flutter-official `TEST_HOST`-hosted Unit Testing Bundle pattern
// (`integration_test`'s own README / Firebase Test Lab recipe) — that
// pattern launches the host app via XCTest injecting into the binary
// directly, bypassing the app-launch path a `SKTestSession` needs to
// intercept. Trade-off: this target loses Flutter's in-process pass/fail
// propagation (the `INTEGRATION_TEST_IOS_RUNNER` macro needs to share a
// process with the Flutter engine); this XCTest itself only proves the app
// launched and eventually exited/timed out. The real evidence is the Dart
// suite's own debugPrint()/print() output — it reaches this same process's
// stdout regardless of which mechanism launched it, and lands in the
// simulator's unified log (`Runner: (Flutter) flutter: ...`), NOT directly
// in xcodebuild's own captured console for a UI-tested app-under-test.
// Capture it with (see tools/run_storekit_suite_ios.sh):
//   xcrun simctl spawn <udid> log stream --predicate 'eventMessage CONTAINS "flutter:"'
//
// Run:
//   flutter build ios --config-only --simulator \
//     integration_test/purchase_restore_ios_test.dart
//   xcodebuild test -workspace Runner.xcworkspace -scheme Runner \
//     -only-testing:RunnerIntegrationTests -destination id=<sim-udid>
#import <XCTest/XCTest.h>
@import StoreKitTest;

@interface RunnerIntegrationTests : XCTestCase
@property(nonatomic, strong) SKTestSession *storeKitSession;
@end

@implementation RunnerIntegrationTests

- (void)setUp {
  [super setUp];
  self.continueAfterFailure = NO;

  NSError *error = nil;
  self.storeKitSession =
      [[SKTestSession alloc] initWithConfigurationFileNamed:@"Configuration"
                                                       error:&error];
  if (error != nil) {
    XCTFail(@"Failed to start SKTestSession from Configuration.storekit: %@",
            error);
    return;
  }
  // Auto-confirm the purchase (no system confirmation sheet): the test is
  // proving the SDK's purchase/restore flow, not Apple's own confirmation UI,
  // and that sheet lives outside the app process (SpringBoard), which idb's
  // app-scoped `ui describe-all` cannot reliably reach. This is exactly what
  // disableDialogs exists for — unattended StoreKit testing.
  self.storeKitSession.disableDialogs = YES;
  [self.storeKitSession resetToDefaultState];
  [self.storeKitSession clearTransactions];
}

- (void)tearDown {
  [self.storeKitSession clearTransactions];
  self.storeKitSession = nil;
  [super tearDown];
}

- (void)testS7StorekitPurchaseRestoreEntrypointRuns {
  XCUIApplication *app = [[XCUIApplication alloc] init];
  [app launch];

  // Flutter's IntegrationTestWidgetsFlutterBinding terminates the process
  // once the Dart test(s) finish running in this "native, no VM service
  // attached" mode. Poll for that rather than a blind fixed sleep — bounded,
  // generous enough for setUpAll (SDK start) + the purchase/restore flow.
  NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:180.0];
  while (app.exists && [deadline timeIntervalSinceNow] > 0) {
    [NSThread sleepForTimeInterval:1.0];
  }

  // Greptile P1 (PR #138): a timeout used to fall through here silently,
  // which is exactly the "eventually exited/timed out" case this class'
  // header warns proves nothing about the Dart suite's own result — but it
  // still must not report xcodebuild exit 0. If the app is still running,
  // the Dart suite hung (setUpAll, the purchase flow, or restore never
  // returned); fail loud so tools/run_storekit_suite_ios.sh's xcodebuild
  // exit-code check can't be green on a hang. A suite that completes
  // (pass OR fail) exits the app on its own and never reaches this branch —
  // that outcome is reported via the S7-IOS-RESULT marker instead (see
  // purchase_restore_ios_test.dart), which this XCTest still can't see.
  if (app.exists) {
    XCTFail(@"App did not exit within the 180s poll window — the Dart suite "
            @"likely hung. Check storekit_ios_flutter.log for the last "
            @"flutter: lines and the S7-IOS-RESULT marker.");
  }
}

@end
