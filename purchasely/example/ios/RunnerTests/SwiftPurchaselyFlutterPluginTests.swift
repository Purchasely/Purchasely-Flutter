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
        // MOB-308 landed in iOS 6.1.0, so `proxy` is not Android-only. Compiling both
        // arities proves the signatures the bridge depends on, including the `URL?` that
        // makes nil a CLEAR rather than an "ignore".
        let builder = Purchasely.apiKey("test-api-key")
            .appTechnology(.flutter)
            .proxy(api: URL(string: "https://svc.purchasely.io")!)
        XCTAssertNotNil(builder)

        let cleared = Purchasely.apiKey("test-api-key")
            .appTechnology(.flutter)
            .proxy(api: nil)
        XCTAssertNotNil(cleared)
    }

    // MARK: - proxy: the three states (6.1.0)

    // `proxy(api: nil)` is a supported CLEAR on the native builder, so the bridge has to
    // keep "never called", "cleared" and "set" apart. Collapsing either pair is silent: an
    // absent key read as nil turns every start into an implicit clear, and a nil read as
    // absent makes an explicit clear do nothing. A Dart null inside a map decodes to
    // `NSNull` here, which is why the decision keys off `keys.contains`, not off a cast.

    func testProxyDecisionUntouchedWhenTheKeyIsAbsent() {
        XCTAssertEqual(
            SwiftPurchaselyFlutterPlugin.proxyDecision(from: ["apiKey": "k"]),
            .untouched)
    }

    func testProxyDecisionClearsOnAnExplicitNSNull() {
        // This is exactly what a Dart `proxy(null)` arrives as.
        XCTAssertEqual(
            SwiftPurchaselyFlutterPlugin.proxyDecision(from: ["proxy": NSNull()]),
            .apply(nil))
    }

    func testProxyDecisionAppliesAUrl() {
        XCTAssertEqual(
            SwiftPurchaselyFlutterPlugin.proxyDecision(from: ["proxy": "https://svc.purchasely.io"]),
            .apply(URL(string: "https://svc.purchasely.io")))
    }

    func testProxyDecisionDoesNotValidateTheSchemeOrTheHost() {
        // The native SDK refuses a non-https value, a value with no host and a value
        // carrying a query/fragment/credentials, logs it and keeps the production host.
        // The bridge must not pre-judge any of that, or the two platforms disagree.
        XCTAssertEqual(
            SwiftPurchaselyFlutterPlugin.proxyDecision(from: ["proxy": "http://insecure.example"]),
            .apply(URL(string: "http://insecure.example")))
    }

    // MARK: - Redemption handler lifecycle (6.1.0)

    func testTheRedemptionHandlerIsProcessWideNotPerEngine() {
        // `PurchaselyImplementation.webRedemptionDelegate` is weak and has NO runtime
        // setter, and `start()` short-circuits on the process-wide `isStarted`. So a
        // second engine's plugin never reaches the registration call. A per-instance
        // handler would then be released with the first engine, nil the SDK's weak
        // delegate, and drop every later redemption while `start()` still returned true.
        //
        // Identity across accesses is what proves the handler survives engine teardown.
        let first = SwiftPurchaselyFlutterPlugin.sharedWebRedemptionHandler
        let second = SwiftPurchaselyFlutterPlugin.sharedWebRedemptionHandler
        XCTAssertTrue(first === second,
                      "the redemption handler must be one process-wide instance")
    }

    func testEmitDropsTheBodyAfterCancel() {
        // The bug: the delegate captured `eventSink` before a `DispatchQueue.main.async`
        // hop, so a cancel landing in that window could not stop the send. Flutter then
        // buffered the message and handed it to the NEXT listener.
        let handler = WebRedemptionHandler()
        var received: [[String: Any]] = []
        _ = handler.onListen(withArguments: nil) { body in
            if let body = body as? [String: Any] { received.append(body) }
        }

        _ = handler.onCancel(withArguments: nil)
        handler.emit(["isSuccess": true])

        XCTAssertTrue(received.isEmpty,
                      "a settled redemption must not be delivered after cancel")
    }

    func testEmitDeliversWhileListening() {
        let handler = WebRedemptionHandler()
        var received: [[String: Any]] = []
        _ = handler.onListen(withArguments: nil) { body in
            if let body = body as? [String: Any] { received.append(body) }
        }

        handler.emit(["isSuccess": false, "errorCode": "INVALID_REDEMPTION_TOKEN"])

        XCTAssertEqual(received.count, 1)
        XCTAssertEqual(received.first?["errorCode"] as? String, "INVALID_REDEMPTION_TOKEN")
    }

    func testEmitGoesToTheReplacementSinkNotTheOldOne() {
        // The consequence the reviewer reproduced: a stale outcome reaching a later
        // listener. After a re-listen, only the current sink may receive.
        let handler = WebRedemptionHandler()
        var first: [[String: Any]] = []
        var second: [[String: Any]] = []

        _ = handler.onListen(withArguments: nil) { body in
            if let body = body as? [String: Any] { first.append(body) }
        }
        _ = handler.onCancel(withArguments: nil)
        _ = handler.onListen(withArguments: nil) { body in
            if let body = body as? [String: Any] { second.append(body) }
        }

        handler.emit(["isSuccess": true])

        XCTAssertTrue(first.isEmpty, "the replaced sink must receive nothing")
        XCTAssertEqual(second.count, 1, "the current sink must receive exactly once")
    }

    // MARK: - Refused-option diagnostics must not be format strings

    // `NSLog` treats its first argument as a printf format string. Interpolating a
    // caller-supplied value into it made that value the format, so an `anonymousUserId`
    // or `proxy` containing `%@`/`%s`/`%n` crashed inside `__CFStringAppendFormatCore`
    // instead of being skipped — the opposite of the contract, which is that a refused
    // option is logged and `start()` still succeeds.

    /// Format directives that make `NSLog` read arguments that were never passed.
    private static let formatDirectiveInputs = [
        "%@",
        "%@%@%@%@%@%@%@%@",
        "%s%s%s%s",
        "%n",
        "%1$@ %2$@",
        "%x %p %d",
        "3f2504e0-4f89-11d3-9a0c-%@%@",
    ]

    func testRefusedOptionLoggingSurvivesFormatDirectives() {
        // This is the crash reproducer. On the old code — `NSLog(interpolatedString)` —
        // this kills the whole test process, so the run fails rather than reporting a
        // failure. It passing is the proof that the `%@` form is in place.
        for hostile in Self.formatDirectiveInputs {
            SwiftPurchaselyFlutterPlugin.logRefusedOption(
                SwiftPurchaselyFlutterPlugin.refusedAnonymousUserIdMessage(hostile))
            SwiftPurchaselyFlutterPlugin.logRefusedOption(
                SwiftPurchaselyFlutterPlugin.refusedProxyMessage(hostile))
        }
        // Reached only if none of the above crashed.
        XCTAssertTrue(true)
    }

    func testRefusedOptionMessagesCarryTheValueVerbatim() {
        // No expansion while BUILDING the message either: the directives must still be
        // there, unexpanded, so a developer sees exactly what they passed.
        for hostile in Self.formatDirectiveInputs {
            let uuidMessage = SwiftPurchaselyFlutterPlugin.refusedAnonymousUserIdMessage(hostile)
            let proxyMessage = SwiftPurchaselyFlutterPlugin.refusedProxyMessage(hostile)
            XCTAssertTrue(uuidMessage.contains(hostile),
                          "the anonymousUserId diagnostic must quote \(hostile) verbatim")
            XCTAssertTrue(proxyMessage.contains(hostile),
                          "the proxy diagnostic must quote \(hostile) verbatim")
        }
    }

    func testRefusedOptionMessagesNameTheirOptionAndSayItWasSkipped() {
        // A developer must be able to tell the two diagnostics apart, and must be told
        // the option was skipped rather than that something failed.
        let uuidMessage = SwiftPurchaselyFlutterPlugin.refusedAnonymousUserIdMessage("nope")
        XCTAssertTrue(uuidMessage.contains("`anonymousUserId`"))
        XCTAssertTrue(uuidMessage.contains("is not applied"))

        let proxyMessage = SwiftPurchaselyFlutterPlugin.refusedProxyMessage("nope")
        XCTAssertTrue(proxyMessage.contains("`proxy`"))
        XCTAssertTrue(proxyMessage.contains("is not applied"))
        // The clear is a supported operation, so the proxy diagnostic must mention it.
        XCTAssertTrue(proxyMessage.contains("null to clear it"))
    }

    func testProxyDecisionSurvivesFormatDirectivesAndStillRefusesThem() {
        // The decision path must also not choke, and must never turn a hostile value
        // into a proxy CLEAR.
        for hostile in Self.formatDirectiveInputs {
            let decision = SwiftPurchaselyFlutterPlugin.proxyDecision(from: ["proxy": hostile])
            XCTAssertNotEqual(decision, .apply(nil),
                              "\"\(hostile)\" must never be turned into a proxy CLEAR")
        }
    }

    func testProxyDecisionRefusesTheEmptyString() {
        // `URL(string: "")` is nil on every Foundation version, so this one is stable.
        let decision = SwiftPurchaselyFlutterPlugin.proxyDecision(from: ["proxy": ""])
        XCTAssertEqual(decision, .invalid(""))
    }

    func testProxyDecisionNeverClearsForAnyStringInput() {
        // THE invariant, and it is deliberately independent of Foundation's URL parser.
        // `URL(string:)` is lenient and got more lenient in iOS 17 — it percent-encodes a
        // bare space and even accepts "://" — so asserting WHICH strings it rejects makes a
        // test hostage to the simulator image. What must hold regardless: a non-nil string
        // never produces `.apply(nil)`, because nil means CLEAR on the native builder and a
        // typo must not silently disable a proxy the app asked for. Either the string
        // converts and is forwarded, or it is refused and skipped — never a clear.
        let inputs = [
            "",
            "https://svc purchasely.io",
            "ht tp://svc.purchasely.io",
            "://",
            "not-a-proxy",
            "http://insecure.example",
            "https://svc.purchasely.io",
        ]
        for input in inputs {
            let decision = SwiftPurchaselyFlutterPlugin.proxyDecision(from: ["proxy": input])
            XCTAssertNotEqual(decision, .apply(nil),
                              "\"\(input)\" must never be turned into a proxy CLEAR")
            switch decision {
            case .apply(let url):
                XCTAssertNotNil(url)
            case .invalid:
                break
            case .untouched:
                XCTFail("a present key must never read as never-called")
            }
        }
    }

    func testProxyDecisionSkipsANonStringValue() {
        let decision = SwiftPurchaselyFlutterPlugin.proxyDecision(from: ["proxy": 42])
        guard case .invalid = decision else {
            return XCTFail("a non-string proxy must be .invalid, got \(decision)")
        }
        XCTAssertNotEqual(decision, .apply(nil))
    }

    func testProxyDecisionKeepsNeverCalledAndClearedDistinguishable() {
        // Asserted against each other, because that is the pair a collapsing bridge
        // renders identical.
        XCTAssertNotEqual(
            SwiftPurchaselyFlutterPlugin.proxyDecision(from: [:]),
            SwiftPurchaselyFlutterPlugin.proxyDecision(from: ["proxy": NSNull()]))
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

    // MARK: - Subscription source wire contract (6.1.0)

    func testSubscriptionSourceRawValuesMatchTheDartEnumOrder() {
        // `PLYSubscription+ToMap.swift` forwards `subscriptionSource.rawValue` straight to
        // Dart, which maps it by INDEX. So these raw values are the wire contract and a
        // native reorder must break a test here rather than silently cross-wire two stores.
        //
        // `stripe` at 4 is the one that was missing on the Dart side: index 4 used to decode
        // to `none`, so a web-checkout subscription — exactly what a Web2App redemption
        // grants — reported no usable source.
        XCTAssertEqual(PLYSubscriptionSource.appleAppStore.rawValue, 0)
        XCTAssertEqual(PLYSubscriptionSource.googlePlayStore.rawValue, 1)
        XCTAssertEqual(PLYSubscriptionSource.amazonAppstore.rawValue, 2)
        XCTAssertEqual(PLYSubscriptionSource.huaweiAppGallery.rawValue, 3)
        XCTAssertEqual(PLYSubscriptionSource.stripe.rawValue, 4)
        XCTAssertEqual(PLYSubscriptionSource.none.rawValue, 5)
    }

    // MARK: - Web redemption payload policy (6.1.0)

    // `PLYWebRedemptionResult`'s initialiser is internal to the Purchasely module, so no test
    // can construct one and no test can drive `webRedemptionCompleted(result:)` directly.
    // `webRedemptionBody(...)` is extracted precisely so the payload policy IS testable: it
    // takes the destructured fields, with `subscription` already mapped, so these tests need
    // no native type at all. Without it, the iOS encoding step — the one place the two
    // nullability levels could collapse — would be covered only by E2E.

    func testWebRedemptionBodyAlwaysHasTheSameFiveKeys() {
        // The Dart shape must never change between branches, or a caller's null checks
        // become branch-dependent.
        let expected: Set<String> = ["isSuccess", "context", "replay", "errorCode", "errorMessage"]

        let success = WebRedemptionHandler.webRedemptionBody(
            isSuccess: true, hasContext: true, subscription: ["purchaseToken": "t"],
            replay: false, errorCode: nil, errorMessage: nil)
        let failure = WebRedemptionHandler.webRedemptionBody(
            isSuccess: false, hasContext: false, subscription: nil,
            replay: false, errorCode: "INVALID_REDEMPTION_TOKEN", errorMessage: "nope")

        XCTAssertEqual(Set(success.keys), expected)
        XCTAssertEqual(Set(failure.keys), expected)
    }

    func testWebRedemptionBodyNoContextIsNSNull() {
        let body = WebRedemptionHandler.webRedemptionBody(
            isSuccess: true, hasContext: false, subscription: nil,
            replay: false, errorCode: nil, errorMessage: nil)

        XCTAssertTrue(body["context"] is NSNull)
        XCTAssertEqual(body["isSuccess"] as? Bool, true)
    }

    func testWebRedemptionBodyKeepsTheTwoNullabilityLevelsDistinct() {
        // The invariant that matters most. "No context at all" and "a context describing no
        // subscription" are different outcomes, and collapsing them loses information the
        // app needs: the second one still validated a receipt.
        let noContext = WebRedemptionHandler.webRedemptionBody(
            isSuccess: true, hasContext: false, subscription: nil,
            replay: false, errorCode: nil, errorMessage: nil)
        let emptyContext = WebRedemptionHandler.webRedemptionBody(
            isSuccess: true, hasContext: true, subscription: nil,
            replay: false, errorCode: nil, errorMessage: nil)

        XCTAssertTrue(noContext["context"] is NSNull)

        let context = emptyContext["context"] as? [String: Any]
        XCTAssertNotNil(context, "a present context must be a dictionary, not NSNull")
        XCTAssertTrue(context?["subscription"] is NSNull,
                      "the nested subscription must be NSNull, and the key must exist")
    }

    func testWebRedemptionBodyForwardsAMappedSubscription() {
        let body = WebRedemptionHandler.webRedemptionBody(
            isSuccess: true, hasContext: true,
            subscription: ["purchaseToken": "token-1", "subscriptionSource": 4],
            replay: false, errorCode: nil, errorMessage: nil)

        let context = body["context"] as? [String: Any]
        let subscription = context?["subscription"] as? [String: Any]
        XCTAssertEqual(subscription?["purchaseToken"] as? String, "token-1")
        // 4 = stripe / WEB_CHECKOUT_STRIPE, the source a Web2App redemption grants.
        XCTAssertEqual(subscription?["subscriptionSource"] as? Int, 4)
    }

    func testWebRedemptionBodyForwardsReplay() {
        // `replay` is a verdict about the token, independent of success.
        for replay in [true, false] {
            let body = WebRedemptionHandler.webRedemptionBody(
                isSuccess: true, hasContext: true, subscription: nil,
                replay: replay, errorCode: nil, errorMessage: nil)
            XCTAssertEqual(body["replay"] as? Bool, replay)
        }
    }

    func testWebRedemptionBodyFailureBranch() {
        // A failure reports replay false and context NSNull, so the shape holds, and it
        // carries the code and message verbatim — the message can hold the masked email
        // hint on BOTH platforms, so it must not be truncated or scrubbed here.
        let hint = "Redemption link has expired. A new link was sent to j***@example.com."
        let body = WebRedemptionHandler.webRedemptionBody(
            isSuccess: false, hasContext: false, subscription: nil,
            replay: false, errorCode: "EXPIRED_REDEMPTION_TOKEN", errorMessage: hint)

        XCTAssertEqual(body["isSuccess"] as? Bool, false)
        XCTAssertTrue(body["context"] is NSNull)
        XCTAssertEqual(body["replay"] as? Bool, false)
        XCTAssertEqual(body["errorCode"] as? String, "EXPIRED_REDEMPTION_TOKEN")
        XCTAssertEqual(body["errorMessage"] as? String, hint)
    }

    func testWebRedemptionBodyNilCodeAndMessageBecomeNSNull() {
        // Never an empty string: a caller's null check must work.
        let body = WebRedemptionHandler.webRedemptionBody(
            isSuccess: true, hasContext: true, subscription: nil,
            replay: false, errorCode: nil, errorMessage: nil)

        XCTAssertTrue(body["errorCode"] is NSNull)
        XCTAssertTrue(body["errorMessage"] is NSNull)
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
