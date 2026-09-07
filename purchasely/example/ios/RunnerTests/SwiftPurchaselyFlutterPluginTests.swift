import XCTest
import Purchasely
@testable import purchasely_flutter

// Unit tests for the Purchasely Flutter iOS bridge against the 6.0 native SDK.
//
// These are intentionally focused on the v6 native API surface that
// `SwiftPurchaselyFlutterPlugin` depends on: the fluent init builder, the
// `PLYPresentationBuilder` factories, the `PLYPresentationOutcome` shape (incl.
// the v6 `closeReason`), the interceptor result/action enums and the display
// modes. If the native API drifts, this test target fails to COMPILE — which
// surfaces the break before runtime, mirroring the Dart/Android unit suites.
//
// CocoaPods test targets require `XCTestCase` (not Swift Testing).
class SwiftPurchaselyFlutterPluginTests: XCTestCase {

    // MARK: - Plugin type

    func testPluginTypeIsReachable() {
        // The public plugin entry point must exist and be referenceable.
        XCTAssertFalse(String(describing: SwiftPurchaselyFlutterPlugin.self).isEmpty)
    }

    // MARK: - Initialization builder (v6)

    func testInitBuilderChainCompilesAndReturnsBuilder() {
        // Mirrors the chain used by `SwiftPurchaselyFlutterPlugin.start(...)`.
        let builder = Purchasely.apiKey("test-api-key")
            .appTechnology(.flutter)
            .sdkBridgeVersion("6.1.0")
            .runningMode(.full)
            .logLevel(.debug)
            .storekitSettings(.storeKit2)
        XCTAssertNotNil(builder)
    }

    func testRunningModeCases() {
        // The bridge maps the Dart "full"/"observer" strings onto these.
        XCTAssertNotEqual(PLYRunningMode.full, PLYRunningMode.observer)
    }

    func testInitBuilderAcceptsColdStartDeeplink() {
        // Mirrors the exact call `SwiftPurchaselyFlutterPlugin.start(...)` makes
        // when the Dart builder chained `.handleDeeplink(url)`: the cold-start
        // deeplink is applied on the init builder so the SDK resolves it once
        // started. Compiling this proves the native cold-start API the bridge
        // depends on exists with this signature (URL? -> PurchaselyBuilder).
        let url = URL(string: "app://ply/presentations/onboarding")!
        let builder = Purchasely.apiKey("test-api-key")
            .appTechnology(.flutter)
            .handleDeeplink(url)
        XCTAssertNotNil(builder)
    }

    // MARK: - Web2App redemption + anonymous user id (6.1.0)

    func testInitBuilderAcceptsAnonymousUserIdAndOverride() {
        // Mirrors the exact call `SwiftPurchaselyFlutterPlugin.start(...)` makes
        // once it parsed the Dart string into a UUID. Compiling this proves the
        // native signature the bridge depends on (UUID, override: Bool).
        let id = UUID(uuidString: "3f2504e0-4f89-11d3-9a0c-0305e82c3301")!
        let builder = Purchasely.apiKey("test-api-key")
            .appTechnology(.flutter)
            .appAnonymousUserId(id, override: true)
        XCTAssertNotNil(builder)
    }

    func testInitBuilderAcceptsAProxyUrl() {
        // MOB-308 landed in iOS 6.1.0, so `proxy` is not Android-only. The native
        // parameter is a `URL?` where nil turns the proxy OFF, which is why the
        // bridge skips the modifier on an unparsable string instead of passing nil.
        let builder = Purchasely.apiKey("test-api-key")
            .appTechnology(.flutter)
            .proxy(api: URL(string: "https://svc.purchasely.io")!)
        XCTAssertNotNil(builder)
    }

    func testWebRedemptionHandlerConformsToTheDelegate() {
        // The bridge registers the handler on the start chain
        // (`webRedemptionDelegate(_:appHandlesRedemptionAlert:)`), so it must
        // conform — and the builder must accept it with that label.
        let handler = WebRedemptionHandler()
        let builder = Purchasely.apiKey("test-api-key")
            .appTechnology(.flutter)
            .webRedemptionDelegate(handler, appHandlesRedemptionAlert: true)
        XCTAssertNotNil(builder)
    }

    func testRedemptionEventsExistOnTheNativeSdk() {
        // The two 6.1.0 analytics events the Dart `PLYEventName` enum now declares.
        // A native rename breaks this at compile time, before it reaches Dart as an
        // `UNKNOWN` event.
        XCTAssertEqual(PLYEvent.redemptionConsumed.name, "REDEMPTION_CONSUMED")
        XCTAssertEqual(PLYEvent.redemptionFailed.name, "REDEMPTION_FAILED")
    }

    // MARK: - Presentation builder factories (v6)

    func testPresentationBuilderFactories() {
        XCTAssertNotNil(PLYPresentationBuilder.default())
        XCTAssertNotNil(PLYPresentationBuilder.from(placementId: "placement"))
        // `from(screenId:)` is the v6 replacement for the removed
        // `from(presentationId:)` the bridge used to call.
        XCTAssertNotNil(PLYPresentationBuilder.from(screenId: "screen"))
    }

    // MARK: - Outcome shape (v6)

    func testOutcomeDefaultInitIsEmpty() {
        // The bridge synthesises a "no purchase" outcome with the 0-arg init.
        let outcome = PLYPresentationOutcome()
        XCTAssertEqual(outcome.closeReason, .none)
        XCTAssertNil(outcome.plan)
        XCTAssertEqual(outcome.purchaseResult, .none)
    }

    func testCloseReasonWireStringsMatchAndroid() {
        // The bridge forwards `closeReason.rawDescription` to Dart; these must
        // stay aligned with Android's PLYCloseReason.value wire strings.
        XCTAssertEqual(PLYCloseReason.none.rawDescription, "none")
        XCTAssertEqual(PLYCloseReason.button.rawDescription, "button")
        XCTAssertEqual(PLYCloseReason.interactiveDismiss.rawDescription, "back_system")
        XCTAssertEqual(PLYCloseReason.programmatic.rawDescription, "programmatic")
    }

    // MARK: - Interceptor enums (v6)

    func testInterceptResultCases() {
        let all: [PLYInterceptResult] = [.success, .failed, .notHandled]
        XCTAssertEqual(Set(all).count, 3)
    }

    func testInterceptActionCasesExist() {
        // The bridge's `actionFromWire(_:)` maps these to the wire strings.
        let actions: [PLYPresentationAction] = [
            .close, .closeAll, .login, .navigate, .purchase,
            .restore, .openPresentation, .openPlacement, .promoCode, .webCheckout,
        ]
        XCTAssertEqual(actions.count, 10)
    }

    // MARK: - Transition (v6)

    func testTransitionFactories() {
        // Mirrors `parseTransition(_:)`: full screen, modal and the
        // dimension-based drawer/popin.
        XCTAssertNotNil(PLYTransition.fullScreen)
        XCTAssertNotNil(PLYTransition.modal)
        XCTAssertNotNil(PLYTransition.drawer(height: .percentage(0.5), dismissible: true))
        XCTAssertNotNil(PLYTransition.popin(width: nil, height: .percentage(0.5), dismissible: true))
    }

    // MARK: - Inline view event delegation (FLT-W-12)

    func testInlineNativeViewIsAnEventDelegate() {
        // Regression guard for FLT-W-12: the inline `NativeView` must receive SDK
        // events through the `PLYEventDelegate` slot, which is independent of the
        // closure-based `setEventCallback` slot `SwiftEventHandler` uses to
        // forward every event to Dart. A regression back to `setEventCallback`
        // in the inline view would clobber that single global slot and silently
        // stop the Dart event stream. This assignment compiles only while the
        // conformance holds.
        let _: PLYEventDelegate.Type = NativeView.self
    }

    func testEventDelegateRegisterAndUnregisterApiExists() {
        // Compile-only guard (defined, never executed — no global SDK state is
        // mutated): the delegate register/unregister API the inline `NativeView`
        // relies on in `init`/`deinit` must exist with these signatures. Mirrors
        // the exact production calls.
        func compileOnly(_ delegate: PLYEventDelegate) {
            Purchasely.setEventDelegate(delegate)
            Purchasely.removeEventDelegate()
        }
        XCTAssertNotNil(compileOnly)
    }

    // MARK: - contentId registry lifecycle (FLT-W-06)

    func testRequestContentIdsRegistryIsClearable() {
        // Issue: the per-request `contentId` registry is written when a
        // presentation carries a contentId and must be removed on dismiss, or it
        // grows unbounded for the session's lifetime. This pins that the registry
        // symbol exists (a rename fails to compile) and that an entry can be
        // added and removed the way every production dismiss path does.
        let key = "req-\(UUID().uuidString)"
        SwiftPurchaselyFlutterPlugin.requestContentIds[key] = "content-1"
        XCTAssertEqual(SwiftPurchaselyFlutterPlugin.requestContentIds[key], "content-1")
        SwiftPurchaselyFlutterPlugin.requestContentIds.removeValue(forKey: key)
        XCTAssertNil(SwiftPurchaselyFlutterPlugin.requestContentIds[key])
    }
}
