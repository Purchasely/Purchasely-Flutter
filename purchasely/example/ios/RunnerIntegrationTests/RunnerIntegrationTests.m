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

  // Drive the purchase CTA from INSIDE this XCUITest session. A parallel idb
  // client uses the same testmanagerd automation channel; while xcodebuild
  // owns that channel, idb can report successful taps that never reach the
  // app (CI run 29814073898: eight reported taps, zero interceptor callback).
  NSArray<NSString *> *ctaLabels =
      @[ @"Continue", @"Continuer", @"Subscribe", @"S'abonner", @"Unlock now" ];
  NSMutableArray<NSPredicate *> *labelPredicates = [NSMutableArray array];
  for (NSString *label in ctaLabels) {
    [labelPredicates
        addObject:[NSPredicate predicateWithFormat:@"label ==[c] %@", label]];
  }
  XCUIElementQuery *accessibleElements =
      [app descendantsMatchingType:XCUIElementTypeAny];
  XCUIElement *cta = [accessibleElements
      elementMatchingPredicate:[NSCompoundPredicate
                                    orPredicateWithSubpredicates:labelPredicates]];
  XCTAssertTrue([cta waitForExistenceWithTimeout:120.0],
                @"Purchase CTA did not appear within 120s");

  NSDate *hittableDeadline = [NSDate dateWithTimeIntervalSinceNow:15.0];
  while (!cta.isHittable && [hittableDeadline timeIntervalSinceNow] > 0) {
    [NSThread sleepForTimeInterval:0.5];
  }
  XCTAssertTrue(cta.isHittable, @"Purchase CTA exists but is not hittable");
  [cta tap];
  NSLog(@"[RunnerIntegrationTests] purchase CTA tapped through XCUITest");

  // tools/run_storekit_suite_ios.sh watches the Dart PASS/FAIL marker and
  // terminates the app as soon as the Dart suite finishes. Poll for that
  // bounded termination. If no marker is ever emitted (setup crash/hang),
  // retain this independent timeout so xcodebuild cannot false-green.
  NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:420.0];
  while (app.exists && [deadline timeIntervalSinceNow] > 0) {
    [NSThread sleepForTimeInterval:1.0];
  }

  if (app.exists) {
    XCTFail(@"App did not exit within the 420s poll window — the Dart suite "
            @"never emitted a result marker or the marker watcher could not "
            @"terminate it. Check storekit_ios_flutter.log.");
  }
}

@end
