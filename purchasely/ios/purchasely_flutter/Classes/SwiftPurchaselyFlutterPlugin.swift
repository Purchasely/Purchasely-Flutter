import Flutter
import UIKit
import Purchasely

public class SwiftPurchaselyFlutterPlugin: NSObject, FlutterPlugin {

    private static var isStarted: Bool = false

    // Presentation/interceptor state shared with the inline NativeView. Keyed by
    // the Dart-side `requestId` so close/back/display and the platform view can
    // find the right handle. Retained after dismissal to support re-displaying a
    // Dart Presentation handle; there is no native dispose API yet.
    static var requests: [String: PLYPresentationRequest] = [:]
    static var loadedPresentations: [String: PLYPresentation] = [:]
    // The native `PLYPresentation` protocol and `PLYPresentationRequest`
    // protocol expose no `contentId` getter (verified against the SDK
    // interface) — only the builder's write-only `.contentId(_:)` setter. Keep
    // our own registry of what was passed in so `presentationToMap` can echo
    // it back instead of hardcoding null (FLT-W-06 / REC-09).
    static var requestContentIds: [String: String] = [:]
    // FIFO cap on the retained registries: requestIds are random per Dart
    // build(), so without a bound they'd grow for the app's lifetime. Evicting
    // the oldest is safe because a Dart re-display resends the full original
    // source — an evicted request is rebuilt identically from the display args.
    static let requestRetentionCap = 64
    private static var requestOrder: [String] = []

    static func retainRequest(_ requestId: String) {
        requestOrder.removeAll { $0 == requestId }
        requestOrder.append(requestId)
        while requestOrder.count > requestRetentionCap {
            let evicted = requestOrder.removeFirst()
            requests.removeValue(forKey: evicted)
            requestContentIds.removeValue(forKey: evicted)
            loadedPresentations.removeValue(forKey: evicted)
        }
    }
    // invocationId -> SDK interceptor completion. Single-shot, removed on resolve.
    private static var pendingInterceptors: [String: (PLYInterceptResult) -> Void] = [:]

    // The live plugin instance, so the inline NativeView can reach the shared
    // `purchasely-presentation-events` sink and surface the same `onDismissed`
    // envelope as the full-screen path.
    private(set) static weak var shared: SwiftPurchaselyFlutterPlugin?

    let eventChannel: FlutterEventChannel
    let eventHandler: SwiftEventHandler

    let purchaseChannel: FlutterEventChannel
    let purchaseHandler: SwiftPurchaseHandler

    let userAttributesChannel: FlutterEventChannel
    let userAttributesHandler: UserAttributesHandler

    // Web2App redemption outcomes (6.1.0). Held as a stored property, not a local
    // in `start`: `PurchaselyBuilder` retains the delegate only until it is applied,
    // and the SDK then keeps a weak reference — a local would be released and the
    // delegate would silently go nil.
    let webRedemptionChannel: FlutterEventChannel
    let webRedemptionHandler: WebRedemptionHandler

    // Presentation/interceptor lifecycle events flow over a dedicated stream,
    // discriminated by the `event` key; each carries a `requestId` so Dart can
    // route back.
    let presentationChannel: FlutterEventChannel
    let presentationEventHandler: PresentationEventHandler

    var presentedPresentationViewController: UIViewController?

    public init(with registrar: FlutterPluginRegistrar) {
        self.eventChannel = FlutterEventChannel(name: "purchasely-events",
                                           binaryMessenger: registrar.messenger())
        self.eventHandler = SwiftEventHandler()
        self.eventChannel.setStreamHandler(self.eventHandler)

        self.purchaseChannel = FlutterEventChannel(name: "purchasely-purchases",
                                                   binaryMessenger: registrar.messenger())
        self.purchaseHandler = SwiftPurchaseHandler()
        self.purchaseChannel.setStreamHandler(self.purchaseHandler)

        self.userAttributesChannel = FlutterEventChannel(name: "purchasely-user-attributes",
                                                      binaryMessenger: registrar.messenger())
        self.userAttributesHandler = UserAttributesHandler()
        self.userAttributesChannel.setStreamHandler(self.userAttributesHandler)

        self.webRedemptionChannel = FlutterEventChannel(name: "purchasely-web-redemption",
                                                        binaryMessenger: registrar.messenger())
        self.webRedemptionHandler = WebRedemptionHandler()
        self.webRedemptionChannel.setStreamHandler(self.webRedemptionHandler)

        self.presentationChannel = FlutterEventChannel(name: "purchasely-presentation-events",
                                                       binaryMessenger: registrar.messenger())
        self.presentationEventHandler = PresentationEventHandler()
        self.presentationChannel.setStreamHandler(self.presentationEventHandler)

        super.init()
        SwiftPurchaselyFlutterPlugin.shared = self
    }

    /// Emits a presentation lifecycle envelope onto the shared
    /// `purchasely-presentation-events` sink. Used by the inline NativeView so
    /// the embedded path surfaces the same `{ event, requestId, outcome }`
    /// envelopes as the full-screen path.
    static func emitPresentationEvent(_ payload: [String: Any?]) {
        shared?.presentationEventHandler.emit(payload)
    }

    /// Static accessor to the outcome serializer so the inline NativeView emits
    /// the exact same `outcome` shape as the full-screen path.
    static func outcomeMap(_ outcome: PLYPresentationOutcome,
                           presentation: PLYPresentation?,
                           error: Error?,
                           requestId: String) -> [String: Any?] {
        return shared?.outcomeToMap(outcome,
                                    presentation: presentation,
                                    error: error,
                                    requestId: requestId) ?? [:]
    }

    /// Static accessor to the presentation serializer so the inline NativeView
    /// emits the exact same `presentation` shape as the full-screen path.
    static func presentationMap(_ presentation: PLYPresentation,
                                requestId: String) -> [String: Any] {
        return shared?.presentationToMap(presentation, requestId: requestId) ?? [:]
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "purchasely",
                                           binaryMessenger: registrar.messenger())

        let instance = SwiftPurchaselyFlutterPlugin(with: registrar)
        registrar.addMethodCallDelegate(instance, channel: channel)

        let factory = NativeViewFactory(messenger: registrar.messenger())
        registrar.register(factory, withId: "io.purchasely.purchasely_flutter/native_view")
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let arguments = call.arguments as? [String: Any]
        switch call.method {
        // --- start ---
        case "start":
            start(arguments: arguments, result: result)

        // --- presentation lifecycle ---
        case "preload":
            preload(arguments, result: result)
        case "display":
            display(arguments, result: result)
        case "close":
            closePresentation(arguments, result: result)
        case "closeAllScreens":
            Purchasely.closeAllScreens()
            result(true)
        case "back":
            back(arguments, result: result)
        case "clientPresentationDisplayed":
            clientPresentationDisplayed(arguments)
            result(true)
        case "clientPresentationClosed":
            clientPresentationClosed(arguments)
            result(true)

        // --- action interceptor ---
        case "registerInterceptor":
            registerInterceptor(arguments, result: result)
        case "removeInterceptor":
            removeInterceptor(arguments, result: result)
        case "removeAllInterceptors":
            removeAllInterceptors(result: result)
        case "interceptorResolve":
            interceptorResolve(arguments, result: result)

        // --- kept v5 surface ---
        case "restoreAllProducts":
            restoreAllProducts(result)
        case "silentRestoreAllProducts":
            silentRestoreAllProducts(result)
        case "synchronize":
            synchronize(result)
        case "getAnonymousUserId":
            DispatchQueue.main.async { [weak self] in
                guard let `self` = self else { return }
                result(self.getAnonymousUserId())
            }
        case "userLogin":
            userLogin(arguments: arguments, result: result)
        case "userLogout":
            userLogout(arguments: arguments, result: result)
        case "allowDeeplink":
            let parameter = arguments?["allowDeeplink"] as? Bool
            allowDeeplink(allowDeeplink: parameter)
            result(true)
        case "allowCampaigns":
            let parameter = arguments?["allowCampaigns"] as? Bool
            allowCampaigns(allowCampaigns: parameter)
            result(true)
        case "setDefaultPresentationDismissHandler":
            setDefaultPresentationDismissHandler(result: result)
        case "removeDefaultPresentationDismissHandler":
            removeDefaultPresentationDismissHandler(result: result)
        case "setLogLevel":
            // PAR-27: the wire contract is `.name` (String) everywhere, same as
            // the `start()` builder — reuse the same tolerant parser rather
            // than a second, Int-only one that would crash `as? Int` into a
            // silent `.debug` default for a String payload.
            Purchasely.setLogLevel(Self.logLevel(from: arguments?["logLevel"]))
            DispatchQueue.main.async {
                result(true)
            }
        case "productWithIdentifier":
            productWithIdentifier(arguments: arguments, result: result)
        case "planWithIdentifier":
            planWithIdentifier(arguments: arguments, result: result)
        case "allProducts":
            allProducts(result)
        case "purchaseWithPlanVendorId":
            purchaseWithPlanVendorId(arguments: arguments, result: result)
        case "handleDeeplink":
            let parameter = arguments?["deeplink"] as? String
            handleDeeplink(parameter, result: result)
        case "userSubscriptions":
            userSubscriptions(arguments, result: result)
        case "userSubscriptionsHistory":
            userSubscriptionsHistory(arguments, result: result)
        case "setThemeMode":
            setThemeMode(arguments: arguments)
            result(true)
        case "setAttribute":
            setAttribute(arguments: arguments)
            result(true)
        case "setLanguage":
            let parameter = arguments?["language"] as? String
            setLanguage(with: parameter)
            result(true)
        case "userDidConsumeSubscriptionContent":
            userDidConsumeSubscriptionContent()
            result(true)
        case "setUserAttributeWithString":
            setUserAttributeWithString(arguments: arguments)
        case "setUserAttributeWithInt":
            setUserAttributeWithInt(arguments: arguments)
        case "setUserAttributeWithDouble":
            setUserAttributeWithDouble(arguments: arguments)
        case "setUserAttributeWithBoolean":
            setUserAttributeWithBoolean(arguments: arguments)
        case "setUserAttributeWithDate":
            setUserAttributeWithDate(arguments: arguments)
        case "setUserAttributeWithStringArray":
            setUserAttributeWithStringArray(arguments: arguments)
        case "setUserAttributeWithIntArray":
            setUserAttributeWithIntArray(arguments: arguments)
        case "setUserAttributeWithDoubleArray":
            setUserAttributeWithDoubleArray(arguments: arguments)
        case "setUserAttributeWithBooleanArray":
            setUserAttributeWithBooleanArray(arguments: arguments)
        case "incrementUserAttribute":
            incrementUserAttribute(arguments: arguments)
        case "decrementUserAttribute":
            decrementUserAttribute(arguments: arguments)
        case "userAttribute":
            getUserAttribute(arguments: arguments, result: result)
        case "userAttributes":
            getUserAttributes(result: result)
        case "clearUserAttribute":
            clearUserAttribute(arguments: arguments)
        case "clearUserAttributes":
            clearUserAttributes()
        case "clearBuiltInAttributes":
            clearBuiltInAttributes()
        case "getBuiltInAttributes":
            getBuiltInAttributes(result: result)
        case "getBuiltInAttribute":
            getBuiltInAttribute(arguments: arguments, result: result)
        case "isAnonymous":
            isAnonymous(result: result)
        case "signPromotionalOffer":
            signPromotionalOffer(arguments: arguments, result: result)
        case "isEligibleForIntroOffer":
            isEligibleForIntroOffer(arguments: arguments, result: result)
        case "setDynamicOffering":
            setDynamicOffering(arguments: arguments, result: result)
        case "getDynamicOfferings":
            getDynamicOfferings(result: result)
        case "removeDynamicOffering":
            removeDynamicOffering(arguments: arguments)
        case "clearDynamicOfferings":
            clearDynamicOfferings()
        case "revokeDataProcessingConsent":
            revokeDataProcessingConsent(arguments: arguments)
        case "setDebugMode":
            setDebugMode(arguments: arguments)
            result(true)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - start

    /// Logs a refused start option.
    ///
    /// **`NSLog("%@", message)`, never `NSLog(message)`.** `NSLog` treats its first
    /// argument as a printf format string, so interpolating a caller-supplied value
    /// into it makes that value the format. An `anonymousUserId` or `proxy` string
    /// containing `%@`/`%s`/`%n` then sends `NSLog` reading arguments that were never
    /// passed — reproduced as a crash inside `__CFStringAppendFormatCore`. Crashing
    /// the host app while reporting that an option was *skipped* is the exact opposite
    /// of this code's contract, which is that `start()` still succeeds.
    ///
    /// One funnel on purpose: every refusal goes through here, so the unsafe form
    /// cannot creep back in at an individual call site.
    static func logRefusedOption(_ message: String) {
        NSLog("%@", message)
    }

    /// The diagnostic for a non-canonical `anonymousUserId`.
    ///
    /// Pure and separate from the logging so a test can assert the caller's value is
    /// carried verbatim — proving no format expansion happens while building it either.
    static func refusedAnonymousUserIdMessage(_ received: String) -> String {
        return "[Purchasely] `anonymousUserId` must be a canonical UUID string, for example "
            + "\"3f2504e0-4f89-11d3-9a0c-0305e82c3301\". Received \"\(received)\". "
            + "The anonymous user id is not applied."
    }

    /// The diagnostic for a `proxy` value the bridge cannot convert. See
    /// [refusedAnonymousUserIdMessage].
    static func refusedProxyMessage(_ received: String) -> String {
        return "[Purchasely] `proxy` must be an https base URL string, for example "
            + "\"https://svc.purchasely.io\", or null to clear it. Received \"\(received)\". "
            + "The proxy is not applied."
    }

    /// What the `proxy` start option asks the native builder to do.
    ///
    /// Three states, and collapsing any two of them is a defect: treating an absent key
    /// as nil turns every start into an implicit clear, and treating nil as absent makes
    /// an explicit clear silently do nothing.
    enum ProxyDecision: Equatable {
        /// No `proxy` key: `proxy()` was never called, so leave the current setting.
        case untouched
        /// `proxy` present: call `proxy(api:)`. A nil URL clears it, back to `api.purchasely.io`.
        case apply(URL?)
        /// `proxy` present but not convertible. Log and SKIP — never pass nil, because nil
        /// means *clear* on the native builder, so a typo would silently disable a proxy
        /// the app explicitly asked for.
        case invalid(String)
    }

    /// Reads the three `proxy` states out of the `start` argument map.
    ///
    /// The bridge only converts the string and rejects what will not convert. The native
    /// SDK refuses a non-https value, a value with no host and a value carrying a
    /// query/fragment/credentials, logs it and keeps the production host, and it drops a
    /// trailing slash — none of that is re-checked here.
    ///
    /// `static` and pure, so a unit test can drive every state without starting the SDK.
    static func proxyDecision(from arguments: [String: Any]) -> ProxyDecision {
        guard arguments.keys.contains("proxy") else { return .untouched }
        let raw = arguments["proxy"]
        if raw == nil || raw is NSNull { return .apply(nil) }
        guard let api = raw as? String else {
            return .invalid(String(describing: raw!))
        }
        guard let url = URL(string: api) else { return .invalid(api) }
        return .apply(url)
    }


    private func start(arguments: [String: Any]?, result: @escaping FlutterResult) {

        guard let arguments = arguments, let apiKey = arguments["apiKey"] as? String, !apiKey.isEmpty else {
            result(FlutterError.failedArgumentField("apiKey", type: String.self))
            return
        }

        guard !SwiftPurchaselyFlutterPlugin.isStarted else {
            result(true)
            return
        }

        var builder = Purchasely.apiKey(apiKey)
            .appTechnology(.flutter)
            .sdkBridgeVersion("6.1.0")

        if let userId = (arguments["appUserId"] as? String) ?? (arguments["userId"] as? String), !userId.isEmpty {
            builder = builder.appUserId(userId)
        }

        builder = builder.runningMode(Self.runningMode(from: arguments["runningMode"]))
        builder = builder.logLevel(Self.logLevel(from: arguments["logLevel"]))
        builder = builder.storekitSettings(Self.storekitSettings(from: arguments))

        // Cold-start deeplink: the builder resolves it automatically once
        // started, so the host does not need a separate handleDeeplink() call.
        if let deeplink = arguments["deeplink"] as? String, let url = URL(string: deeplink) {
            builder = builder.handleDeeplink(url)
        }

        // Dart has no UUID type, so the id crosses the bridge as a string and is
        // parsed here. The native builder takes a `UUID?`, which is where the
        // guarantee used to live; a string-typed bridge is the only place left to
        // catch a bad value. Reject it loudly and skip the modifier — the SDK still
        // starts, matching how Android treats an unusable proxy url.
        // Severity, deliberately matched to Android's `Log.e`: a plain log line and
        // nothing else. `NSLog` never puts UI in front of the host app — unlike React
        // Native's `RCTLogError`, which renders a full-screen redbox in a debug build and
        // makes a *skipped* option look like a crash. A third-party SDK must not interrupt
        // someone else's app over an option it chose to ignore, and the two platforms must
        // not differ in how loudly they refuse the same value.
        if let anonymousUserId = arguments["anonymousUserId"] as? String {
            if let parsed = UUID(uuidString: anonymousUserId) {
                let override = (arguments["anonymousUserIdOverride"] as? Bool) ?? false
                builder = builder.appAnonymousUserId(parsed, override: override)
            } else {
                Self.logRefusedOption(Self.refusedAnonymousUserIdMessage(anonymousUserId))
            }
        }

        // Three proxy states, and they are not interchangeable — see
        // `Self.proxyDecision(from:)`. A Dart null in a map decodes to `NSNull`
        // here, so `keys.contains` is what separates "cleared" from "never
        // called".
        switch Self.proxyDecision(from: arguments) {
        case .untouched:
            break
        case .apply(let url):
            builder = builder.proxy(api: url)
        case .invalid(let raw):
            Self.logRefusedOption(Self.refusedProxyMessage(raw))
        }

        // Registered unconditionally: the native SDK has no runtime setter on
        // purpose, because a redemption can settle during `start()` (a cold start
        // that the link itself triggered, or a token left pending by a previous
        // launch). The bridge emits onto `purchasely-web-redemption`, which reaches
        // no one when Dart added no listener, so this is behaviour-neutral by
        // default.
        builder = builder.webRedemptionDelegate(
            webRedemptionHandler,
            appHandlesRedemptionAlert: (arguments["appHandlesRedemptionAlert"] as? Bool) ?? false)

        if let allowDeeplink = arguments["allowDeeplink"] as? Bool {
            Purchasely.allowDeeplink(allowDeeplink)
        }
        Purchasely.allowCampaigns((arguments["allowCampaigns"] as? Bool) ?? true)

        DispatchQueue.main.async {
            builder.start { error in
                if let error = error {
                    result(FlutterError.error(code: "0", message: "Purchasely SDK not configured", error: error))
                } else {
                    SwiftPurchaselyFlutterPlugin.isStarted = true
                    result(true)
                }
            }
        }
    }

    // MARK: - Presentation lifecycle

    /// Build a `PLYPresentationRequest` from a Dart-side request map. The map
    /// shape mirrors `PresentationRequest.toMap()` in
    /// `lib/src/presentation_request.dart`.
    private func buildRequest(_ args: [String: Any], requestId: String) -> PLYPresentationRequest {
        let source = args["source"] as? [String: Any]
        let kind = (source?["kind"] as? String) ?? "defaultSource"
        let id = source?["id"] as? String
        let contentId = args["contentId"] as? String

        let builder: PLYPresentationBuilder = {
            switch kind {
            case "placementId":
                return id.map { PLYPresentationBuilder.from(placementId: $0) } ?? .default()
            case "screenId":
                return id.map { PLYPresentationBuilder.from(screenId: $0) } ?? .default()
            default:
                return .default()
            }
        }()

        if let contentId = contentId {
            SwiftPurchaselyFlutterPlugin.requestContentIds[requestId] = contentId
            _ = builder.contentId(contentId)
        }
        if let hex = args["backgroundColor"] as? String, let color = UIColor.ply_from(hex: hex) {
            _ = builder.backgroundColor(color)
        }
        if let hex = args["progressColor"] as? String, let color = UIColor.ply_from(hex: hex) {
            _ = builder.progressColor(color)
        }
        if let displayCloseButton = args["displayCloseButton"] as? Bool {
            _ = builder.displayCloseButton(displayCloseButton)
        }
        if let displayBackButton = args["displayBackButton"] as? Bool {
            _ = builder.displayBackButton(displayBackButton)
        }

        // Builder-seeded callbacks are transferred onto the loaded presentation
        // automatically by the SDK. They run on the main actor; we emit on the
        // EventChannel sink (main queue) directly.
        _ = builder.onPresented { [weak self] presentation, error in
            self?.presentationEventHandler.emit([
                "event": "onPresented",
                "requestId": requestId,
                "presentation": presentation.map { self?.presentationToMap($0, requestId: requestId) ?? [:] } as Any?,
                "error": error.map { Self.errorToMap($0) } as Any?,
            ])
        }

        _ = builder.onCloseRequested { [weak self] in
            // Native `onCloseRequested` (close-requested semantics), forwarded as
            // `onCloseRequested` on the wire so the Dart-side façade matches the
            // cross-platform contract.
            self?.presentationEventHandler.emit([
                "event": "onCloseRequested",
                "requestId": requestId,
            ])
        }

        _ = builder.onDismissed { [weak self] outcome in
            let presentation = SwiftPurchaselyFlutterPlugin.loadedPresentations[requestId]
            self?.presentationEventHandler.emit([
                "event": "onDismissed",
                "requestId": requestId,
                "outcome": self?.outcomeToMap(outcome, presentation: presentation, error: nil, requestId: requestId) as Any?,
            ])
            // Full-screen dismiss: drop only the loaded handle (stale once
            // dismissed). The request and its contentId stay registered so a
            // Dart-side re-display() of the same handle reuses the original
            // native request — and thus its source (placement/screen) — instead
            // of being rebuilt against the default source. Mirrors Android,
            // which keeps preparedRequests across dismissals.
            SwiftPurchaselyFlutterPlugin.loadedPresentations.removeValue(forKey: requestId)
        }

        let request = builder.build()
        SwiftPurchaselyFlutterPlugin.requests[requestId] = request
        SwiftPurchaselyFlutterPlugin.retainRequest(requestId)
        return request
    }

    private func preload(_ args: [String: Any]?, result: @escaping FlutterResult) {
        guard let args = args, let requestId = args["requestId"] as? String, !requestId.isEmpty else {
            result(FlutterError(code: "ARG_INVALID", message: "requestId required", details: nil))
            return
        }
        let request = buildRequest(args, requestId: requestId)
        request.preload { [weak self] presentation, error in
            guard let self = self else { return }
            if let presentation = presentation {
                SwiftPurchaselyFlutterPlugin.loadedPresentations[requestId] = presentation
                self.presentationEventHandler.emit([
                    "event": "onLoaded",
                    "requestId": requestId,
                    "presentation": self.presentationToMap(presentation, requestId: requestId),
                ])
                result(self.presentationToMap(presentation, requestId: requestId))
            } else {
                let errMap = error.map { Self.errorToMap($0) } ?? ["code": "Unknown", "message": "unknown"]
                self.presentationEventHandler.emit([
                    "event": "onLoaded",
                    "requestId": requestId,
                    "error": errMap,
                ])
                result(FlutterError(code: "PRELOAD",
                                    message: error?.localizedDescription ?? "preload failed",
                                    details: errMap))
            }
        }
    }

    private func display(_ args: [String: Any]?, result: @escaping FlutterResult) {
        guard let args = args, let requestId = args["requestId"] as? String, !requestId.isEmpty else {
            result(FlutterError(code: "ARG_INVALID", message: "requestId required", details: nil))
            return
        }
        let request = SwiftPurchaselyFlutterPlugin.requests[requestId] ?? buildRequest(args, requestId: requestId)

        let transitionMap = args["transition"] as? [String: Any]
        let displayMode = Self.parseTransition(transitionMap)

        request.display(transition: displayMode) { [weak self] presentation, error in
            guard let self = self else { return }
            // The Dart-side `.display()` Future resolves at *dismiss* time, not
            // here. We don't `result(...)` with the outcome — that's emitted via
            // the `onDismissed` event and the Dart façade resolves its Future
            // from there. We acknowledge the dispatch via `result(true)` on
            // success, and synthesise the error-path callbacks on failure.
            if let presentation = presentation {
                SwiftPurchaselyFlutterPlugin.loadedPresentations[requestId] = presentation
                result(true)
            } else if let error = error {
                // Synthesise onPresented(nil, error) so the Dart-side builder
                // onPresented handler fires uniformly across platforms.
                self.presentationEventHandler.emit([
                    "event": "onPresented",
                    "requestId": requestId,
                    "presentation": nil as Any?,
                    "error": Self.errorToMap(error),
                ])
                // Also synthesise onDismissed with the error outcome.
                let outcome = self.outcomeToMap(
                    PLYPresentationOutcome(),
                    presentation: nil,
                    error: error,
                    requestId: requestId
                )
                self.presentationEventHandler.emit([
                    "event": "onDismissed",
                    "requestId": requestId,
                    "outcome": outcome,
                ])
                // Display failed before present/dismiss, so `builder.onDismissed`
                // never fires — clear all per-request state here (a retry with
                // the same requestId then rebuilds instead of reusing the failed
                // request). Mirrors the inline NativeView cleanup.
                SwiftPurchaselyFlutterPlugin.loadedPresentations.removeValue(forKey: requestId)
                SwiftPurchaselyFlutterPlugin.requests.removeValue(forKey: requestId)
                SwiftPurchaselyFlutterPlugin.requestContentIds.removeValue(forKey: requestId)
                result(true)
            } else {
                result(true)
            }
        }
    }

    private func closePresentation(_ args: [String: Any]?, result: @escaping FlutterResult) {
        let requestId = args?["requestId"] as? String
        if let id = requestId, let presentation = SwiftPurchaselyFlutterPlugin.loadedPresentations[id] {
            presentation.close()
        } else {
            // No per-request handle — fall back to closing every loaded
            // presentation (best-effort; the iOS SDK doesn't expose a global
            // "closeAll").
            SwiftPurchaselyFlutterPlugin.loadedPresentations.values.forEach { $0.close() }
        }
        result(true)
    }

    private func back(_ args: [String: Any]?, result: @escaping FlutterResult) {
        let requestId = args?["requestId"] as? String
        if let id = requestId, let presentation = SwiftPurchaselyFlutterPlugin.loadedPresentations[id] {
            presentation.back()
        }
        result(true)
    }

    /// Resolves the native `PLYPresentation` for a client-paywall notification.
    /// The Dart map carries the `requestId` of the preload that produced the
    /// presentation; v6 `PLYPresentation` is a protocol and cannot be rebuilt
    /// from the map, so we look it up in the registry.
    private func clientPresentation(from args: [String: Any]?, method: String) -> PLYPresentation? {
        guard let requestId = (args?["presentation"] as? [String: Any])?["requestId"] as? String,
              let presentation = SwiftPurchaselyFlutterPlugin.loadedPresentations[requestId] else {
            print("Purchasely", "\(method): no loaded presentation found for this handle — pass the PLYPresentation returned by preload()")
            return nil
        }
        return presentation
    }

    private func clientPresentationDisplayed(_ args: [String: Any]?) {
        guard let presentation = clientPresentation(from: args, method: "clientPresentationDisplayed") else { return }
        Purchasely.clientPresentationDisplayed(with: presentation)
    }

    private func clientPresentationClosed(_ args: [String: Any]?) {
        guard let presentation = clientPresentation(from: args, method: "clientPresentationClosed") else { return }
        Purchasely.clientPresentationClosed(with: presentation)
    }

    // MARK: - Action interceptor

    private func registerInterceptor(_ args: [String: Any]?, result: @escaping FlutterResult) {
        guard let kindWire = args?["kind"] as? String,
              let action = Self.actionFromWire(kindWire) else {
            result(FlutterError(code: "ARG_INVALID", message: "unknown action kind", details: nil))
            return
        }

        Purchasely.interceptAction(action) { [weak self] info, params, completion in
            guard let self = self else { completion(.notHandled); return }
            let id = "ply_ic_\(Int.random(in: 0..<Int.max))"
            SwiftPurchaselyFlutterPlugin.pendingInterceptors[id] = completion
            self.presentationEventHandler.emit([
                "event": "interceptorTriggered",
                "requestId": id,
                "kind": kindWire,
                "info": Self.interceptorInfoToMap(info),
                "payload": Self.actionParamsToMap(params),
            ])
        }

        result(true)
    }

    private func removeInterceptor(_ args: [String: Any]?, result: @escaping FlutterResult) {
        if let kindWire = args?["kind"] as? String,
           let action = Self.actionFromWire(kindWire) {
            Purchasely.removeActionInterceptor(action)
        }
        result(true)
    }

    private func removeAllInterceptors(result: @escaping FlutterResult) {
        Purchasely.removeAllActionInterceptors()
        result(true)
    }

    private func interceptorResolve(_ args: [String: Any]?, result: @escaping FlutterResult) {
        let id = args?["invocationId"] as? String
        let value = args?["result"] as? String
        let ply: PLYInterceptResult = {
            switch value {
            case "success": return .success
            case "failed":  return .failed
            default:        return .notHandled
            }
        }()
        if let id = id, let completion = SwiftPurchaselyFlutterPlugin.pendingInterceptors.removeValue(forKey: id) {
            DispatchQueue.main.async {
                completion(ply)
            }
        }
        result(true)
    }

    // MARK: - Presentation serializers

    // Dart only ever sends the running mode as a String ("observer"/"full" —
    // `PLYRunningMode.name` in purchasely_builder.dart). There is no Int wire
    // format: the native `PLYRunningMode` rawValues (Observer=2, Full=3) don't
    // even line up with Dart's own enum ordinals (0/1), so a since-removed Int
    // branch here was dead *and* wrong — it would have silently resolved any
    // int input to `.observer` (FLT-W-10). Unknown/missing input → observer.
    private static func runningMode(from raw: Any?) -> PLYRunningMode {
        if let value = raw as? String, value.lowercased() == "full" {
            return .full
        }
        return .observer
    }

    private static func logLevel(from raw: Any?) -> PLYLogger.PLYLogLevel {
        if let value = raw as? Int {
            return PLYLogger.PLYLogLevel(rawValue: value) ?? .error
        }
        if let value = raw as? String {
            switch value.lowercased() {
            case "debug": return .debug
            case "info": return .info
            case "warn": return .warn
            default: return .error
            }
        }
        return .error
    }

    private static func storekitSettings(from arguments: [String: Any]) -> StorekitSettings {
        if let value = arguments["storekitVersion"] as? String {
            return value == "storeKit1" ? .storeKit1 : .storeKit2
        }
        let storeKit1 = arguments["storeKit1"] as? Bool ?? false
        return storeKit1 ? .storeKit1 : .storeKit2
    }

    private func presentationToMap(_ p: PLYPresentation, requestId: String) -> [String: Any] {
        return [
            "requestId": requestId,
            // Native `screenId` → wire `screenId`. The Dart factory tolerates both
            // keys; we send `screenId` for forward compatibility with the
            // contract.
            "screenId": p.screenId,
            "placementId": p.placementId as Any,
            // The native PLYPresentation has no contentId getter — echo back
            // what was passed to the builder for this requestId instead of
            // hardcoding null (FLT-W-06 / REC-09).
            "contentId": SwiftPurchaselyFlutterPlugin.requestContentIds[requestId] as Any,
            "audienceId": p.audienceId as Any,
            "abTestId": p.abTestId as Any,
            "abTestVariantId": p.abTestVariantId as Any,
            "campaignId": p.campaignId as Any,
            "flowId": p.flowId as Any,
            "language": p.language,
            "type": p.type.rawValue,
            "height": p.height,
            "plans": p.plans.map { plan -> [String: Any?] in
                [
                    "planVendorId": plan.planVendorId,
                    "storeProductId": plan.storeProductId,
                    "basePlanId": nil as Any?,  // iOS doesn't expose basePlanId on PLYPresentationPlan
                    "offerId": plan.offerId,
                ]
            },
        ]
    }

    private func outcomeToMap(_ outcome: PLYPresentationOutcome,
                              presentation: PLYPresentation?,
                              error: Error?,
                              requestId: String) -> [String: Any?] {
        let purchaseResult: String? = {
            switch outcome.purchaseResult {
            case .purchased: return "purchased"
            case .cancelled: return "cancelled"
            case .restored:  return "restored"
            case .none:      return nil
            @unknown default: return nil
            }
        }()

        // Serialize the full PLYPlan (same shape as products/plans elsewhere) so
        // the Dart side can parse it into a fully-typed PLYPlan via plyPlanFromMap.
        let planMap: [String: Any]? = outcome.plan?.toMap

        // iOS v6 exposes `closeReason` on PLYPresentationOutcome. Serialize via
        // `rawDescription`, which matches Android's wire strings — interactive
        // dismiss stringifies to "back_system" for cross-platform parity.
        // `.none` means no close happened (e.g. a purchase/restore outcome) → send null.
        let closeReason: String? = {
            switch outcome.closeReason {
            case .none: return nil
            default:    return outcome.closeReason.rawDescription
            }
        }()

        let outcomePresentation = outcome.presentation ?? presentation

        return [
            "presentation": outcomePresentation.map { presentationToMap($0, requestId: requestId) } as Any?,
            "purchaseResult": purchaseResult,
            "plan": planMap as Any?,
            "closeReason": closeReason as Any?,
            "error": error.map { Self.errorToMap($0) } as Any?,
        ]
    }

    private static func errorToMap(_ error: Error) -> [String: Any] {
        let ns = error as NSError
        return [
            "code": "\(ns.domain).\(ns.code)",
            "message": ns.localizedDescription,
        ]
    }

    private static func interceptorInfoToMap(_ info: PLYInterceptorInfo) -> [String: Any?] {
        // Mirror Android's shape, which serializes the full presentation map —
        // the Dart façade parses it with the tolerant PLYPresentation.fromMap,
        // so attribution fields (audience/AB test/campaign) survive the bridge.
        return [
            "contentId": info.contentId,
            "presentation": info.presentation.map { p in
                [
                    "screenId": p.screenId,
                    "placementId": p.placementId as Any,
                    "audienceId": p.audienceId as Any,
                    "abTestId": p.abTestId as Any,
                    "abTestVariantId": p.abTestVariantId as Any,
                    "campaignId": p.campaignId as Any,
                    "flowId": p.flowId as Any,
                    "language": p.language,
                    "type": p.type.rawValue,
                ]
            } as Any?,
        ]
    }

    private static func actionParamsToMap(_ params: PLYPresentationActionParameters?) -> [String: Any]? {
        guard let params = params else { return nil }
        var map: [String: Any] = [:]
        if let url = params.url?.absoluteString { map["url"] = url }
        if let title = params.title { map["title"] = title }
        if let plan = params.plan {
            var planMap: [String: Any] = [
                "vendorId": plan.vendorId as Any,
                "productId": plan.appleProductId as Any?,
            ]
            // Apple commitment installment details (iOS 26.4+), same wire shape
            // as PLYPlan.toMap so the Dart payload parses a fully-typed plan.
            if !plan.commitmentInfo.isEmpty {
                planMap["commitmentInfo"] = plan.commitmentInfoMaps
            }
            map["plan"] = planMap
        }
        // Promotional offer attached to the tapped plan (`offer` on the wire,
        // matching Android's shape). iOS has no `subscriptionOffer` equivalent —
        // that payload field stays Android-only (Google Play base-plan /
        // offer-token concepts). PLYPromoOffer.publicId is internal on iOS and
        // intentionally omitted.
        if let offer = params.promoOffer {
            map["offer"] = [
                "vendorId": offer.vendorId,
                "storeOfferId": offer.storeOfferId,
            ]
        }
        if let presentationId = params.presentation { map["presentationId"] = presentationId }
        if let placementId = params.placement { map["placementId"] = placementId }
        // `webCheckoutProvider` is a non-optional enum with `.none` sentinel
        // (meaningful only for the `web_checkout` kind). Send the case name as
        // a String — matching Android's `action.webCheckoutProvider.name`
        // wire contract — instead of the raw Int rawValue: Dart's interceptor
        // casts this field as a String, so the previous Int payload crashed
        // before the native completion could ever resolve (FLT-W-08 / REC-01).
        if let providerName = Self.webCheckoutProviderWireName(params.webCheckoutProvider) {
            map["webCheckoutProvider"] = providerName
        }
        if let clientRef = params.clientReferenceId { map["clientReferenceId"] = clientRef }
        if let queryParam = params.queryParameterKey { map["queryParameterKey"] = queryParam }
        return map
    }

    /// Maps the native `PLYWebCheckoutProvider` Int-backed enum to the same
    /// case-name strings Android sends via `action.webCheckoutProvider.name`.
    /// `.none` is the "not a web-checkout action" sentinel — omit the key
    /// entirely rather than invent a wire string Android never sends.
    private static func webCheckoutProviderWireName(_ provider: PLYWebCheckoutProvider) -> String? {
        switch provider {
        case .stripe: return "STRIPE"
        case .other:  return "OTHER"
        case .none:   return nil
        @unknown default: return nil
        }
    }

    private static func actionFromWire(_ wire: String) -> PLYPresentationAction? {
        switch wire {
        case "close":             return .close
        case "close_all":         return .closeAll
        case "login":             return .login
        case "navigate":          return .navigate
        case "purchase":          return .purchase
        case "restore":           return .restore
        case "open_presentation": return .openPresentation
        case "open_placement":    return .openPlacement
        case "promo_code":        return .promoCode
        case "web_checkout":      return .webCheckout
        default: return nil
        }
    }

    /// Parses a Dart transition dimension `{ "type": "pixel"|"percentage", "value": <Double> }`
    /// into a native `PLYDimension` (`.value(Int)` for pixels, `.percentage(Float)` for
    /// ratios). Returns `nil` (→ "hug" / size-to-content) when absent or malformed.
    private static func parseDimension(_ raw: Any?) -> PLYDimension? {
        guard let map = raw as? [String: Any],
              let value = (map["value"] as? NSNumber)?.doubleValue else { return nil }
        switch map["type"] as? String {
        case "pixel":      return .value(Int(value.rounded()))
        case "percentage": return .percentage(Float(value))
        default:           return .percentage(Float(value))
        }
    }

    /// Parses the Dart `{ "light": "#RRGGBB", "dark": "#RRGGBB" }` map into a
    /// native `PLYColors`. Returns `nil` when absent so the SDK default applies.
    private static func parseColors(_ raw: Any?) -> PLYColors? {
        guard let map = raw as? [String: Any] else { return nil }
        let light = (map["light"] as? String).flatMap { UIColor.ply_from(hex: $0) }
        let dark = (map["dark"] as? String).flatMap { UIColor.ply_from(hex: $0) }
        if light == nil && dark == nil { return nil }
        return PLYColors(lightColor: light, darkColor: dark)
    }

    private static func parseTransition(_ map: [String: Any]?) -> PLYTransition? {
        guard let map = map, let type = map["type"] as? String else { return nil }
        let dismissible = map["dismissible"] as? Bool ?? true
        // v6 models drawer/popin size as PLYDimension (width is popin-only, height
        // drives drawer + popin). `nil` means "hug" — size to content.
        let width = parseDimension(map["width"])
        let height = parseDimension(map["height"])
        // drawer/popin background override; built via the designated initializer
        // because the `.drawer`/`.popin` factories don't take colors.
        let colors = parseColors(map["backgroundColors"])
        switch type {
        case "fullScreen":    return .fullScreen
        case "push":          return .push
        case "modal":         return .modal(dismissible: dismissible)
        case "drawer":
            return PLYTransition(type: .drawer,
                                 height: height,
                                 backgroundColors: colors,
                                 dismissible: dismissible)
        case "popin":
            return PLYTransition(type: .popin,
                                 height: height,
                                 width: width,
                                 backgroundColors: colors,
                                 dismissible: dismissible)
        case "inlinePaywall": return .inlinePaywall
        default: return nil
        }
    }

    // MARK: - Inline native view support

    /// Resolves the controller for the inline platform view. Mirrors Android:
    /// the inline view is built from a presentation that was already loaded
    /// (via `preload`) and is keyed by the Dart `requestId`.
    /// Creation-param contract: `{ "requestId": <String> }`.
    static func presentationController(for args: Any?) -> UIViewController? {
        guard let creationParams = args as? [String: Any],
              let requestId = creationParams["requestId"] as? String,
              let presentation = loadedPresentations[requestId] else {
            return nil
        }
        return presentation.controller
    }

    // MARK: - Kept v5 surface

    private func isAnonymous(result: @escaping FlutterResult) {
        result(Purchasely.isAnonymous())
    }

    private func isEligibleForIntroOffer(arguments: [String: Any]?, result: @escaping FlutterResult) {
        guard let arguments = arguments, let planVendorId = arguments["planVendorId"] as? String else {
            result(FlutterError.failedArgumentField("planVendorId", type: String.self))
            return
        }

        DispatchQueue.main.async {
            Purchasely.plan(with: planVendorId) { plan in
                plan.isUserEligibleForIntroductoryOffer { res in
                    result(res)
                }
            } failure: { error in
                result(FlutterError.error(code:"-1", message:"plan \(planVendorId) not found", error: error))
            }
        }
    }

    private func restoreAllProducts(_ result: @escaping FlutterResult) {
        DispatchQueue.main.async {
            Purchasely.restoreAllProducts {
                result(true)
            } failure: { error in
                result(FlutterError.error(code: "-1", message: "Restore failed", error: error))
            }
        }
    }

    private func silentRestoreAllProducts(_ result: @escaping FlutterResult) {
        DispatchQueue.main.async {
            Purchasely.synchronize {
                result(true)
            } failure: { error in
                result(FlutterError.error(code: "-1", message: "Restore failed", error: error))
            }
        }
    }

    private func synchronize(_ result: @escaping FlutterResult) {
        DispatchQueue.main.async {
            // v6 exposes success/failure callbacks on synchronize(). The Dart
            // `Purchasely.synchronize()` Future now resolves on success and throws
            // (PlatformException) on failure, instead of the old fire-and-forget.
            Purchasely.synchronize {
                result(true)
            } failure: { error in
                result(FlutterError.error(code: "-1", message: "Synchronization failed", error: error))
            }
        }
    }

    private func getAnonymousUserId() -> String {
        return Purchasely.anonymousUserId
    }

    private func setLanguage(with language: String?) {
        guard let language = language else { return }
        let locale = Locale(identifier: language)
        Purchasely.setLanguage(from: locale)
    }

    private func userLogin(arguments: [String: Any]?, result: @escaping FlutterResult) {
        guard let arguments = arguments, let userId = arguments["userId"] as? String else {
            result(FlutterError.error(code: "-1", message: "user id must not be nil", error: nil))
            return
        }
        DispatchQueue.main.async {
            Purchasely.userLogin(with: userId) { refresh in
                result(refresh)
            }
        }
    }

    private func userLogout(arguments: [String: Any]?, result: @escaping FlutterResult) {
        // PAR-30: defaults to true, aligned with the native default.
        let clearUserAttributes = (arguments?["clearUserAttributes"] as? Bool) ?? true
        Purchasely.userLogout(clearUserAttributes)
        result(true)
    }

    private func allowDeeplink(allowDeeplink: Bool?) {
        Purchasely.allowDeeplink(allowDeeplink ?? true)
    }

    private func allowCampaigns(allowCampaigns: Bool?) {
        Purchasely.allowCampaigns(allowCampaigns ?? true)
    }

    private func setDefaultPresentationDismissHandler(result: @escaping FlutterResult) {
        DispatchQueue.main.async { [weak self] in
            Purchasely.setDefaultPresentationDismissHandler { [weak self] outcome in
                guard let self = self else { return }
                self.presentationEventHandler.emit([
                    "event": "onDefaultPresentationDismissed",
                    "outcome": self.outcomeToMap(
                        outcome,
                        presentation: nil,
                        error: nil,
                        requestId: ""
                    ),
                ])
            }
            result(true)
        }
    }

    private func removeDefaultPresentationDismissHandler(result: @escaping FlutterResult) {
        DispatchQueue.main.async {
            Purchasely.setDefaultPresentationDismissHandler(nil)
            result(true)
        }
    }

    private func productWithIdentifier(arguments: [String: Any]?, result: @escaping FlutterResult) {
        guard let arguments = arguments, let vendorId = arguments["vendorId"] as? String else {
            result(FlutterError.error(code: "-1", message: "product vendor id must not be nil", error: nil))
            return
        }

        DispatchQueue.main.async {
            Purchasely.product(with: vendorId) { product in
                let productDict: [String: Any] = product.toMap
                result(productDict)
            } failure: { error in
                result(FlutterError.error(code:"-1", message:"product \(vendorId) not found", error: error))
            }
        }
    }

    private func planWithIdentifier(arguments: [String: Any]?, result: @escaping FlutterResult) {
        guard let arguments = arguments, let vendorId = arguments["vendorId"] as? String else {
            result(FlutterError.error(code: "-1", message: "plan vendor id must not be nil", error: nil))
            return
        }

        DispatchQueue.main.async {
            Purchasely.plan(with: vendorId) { plan in
                result(plan.toMap)
            } failure: { error in
                result(FlutterError.error(code:"-1", message:"plan \(vendorId) not found", error: error))
            }
        }
    }

    private func allProducts(_ result: @escaping FlutterResult) {
        DispatchQueue.main.async {
            Purchasely.allProducts { products in
                result(products.compactMap { $0.toMap })
            } failure: { error in
                result(FlutterError.error(code:"-1", message:"failed to fetch all products", error: error))
            }
        }
    }

    private func signPromotionalOffer(arguments: [String: Any]?, result: @escaping FlutterResult) {
        guard let arguments = arguments,
              let storeProductId = arguments["storeProductId"] as? String,
              let storeOfferId = arguments["storeOfferId"] as? String else {
            result(FlutterError.error(code: "-1", message: "storeProductId and storeOfferId must not be nil", error: nil))
            return
        }

        DispatchQueue.main.async {
            if #available(iOS 12.2, macOS 12.0, tvOS 15.0, watchOS 8.0, *) {
                Purchasely.signPromotionalOffer(storeProductId: storeProductId, storeOfferId: storeOfferId) { signature in
                    result(signature.toMap)
                } failure: { error in
                    result(FlutterError.error(code:"-1", message:"signature failed", error: error))
                }
            } else {
                result(FlutterError.error(code:"-1", message:"Promotional offers signature are only available for iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0", error: nil))
            }
        }
    }

    private func purchaseWithPlanVendorId(arguments: [String: Any]?, result: @escaping FlutterResult) {
        guard let arguments = arguments, let vendorId = arguments["vendorId"] as? String else {
            result(FlutterError.error(code: "-1", message: "plan vendor id must not be nil", error: nil))
            return
        }

        let contentId = arguments["contentId"] as? String

        DispatchQueue.main.async {
            Purchasely.plan(with: vendorId) { plan in

                if let offerId = arguments["offerId"] as? String,
                   let storeOfferId = plan.promoOffers.first(where: { $0.vendorId == offerId })?.storeOfferId,
                   #available(iOS 12.2, macOS 12.0, tvOS 15.0, watchOS 8.0, *) {

                    Purchasely.purchaseWithPromotionalOffer(plan: plan, contentId: contentId, storeOfferId: storeOfferId) {
                        result(plan.toMap)
                    } failure: { error in
                        result(FlutterError.error(code:"-1", message:"purchase failed", error: error))
                    }
                } else {
                    Purchasely.purchase(plan: plan, contentId: contentId) {
                        result(plan.toMap)
                    } failure: { error in
                        result(FlutterError.error(code:"-1", message:"purchase failed", error: error))
                    }
                }
            } failure: { error in
                result(FlutterError.error(code:"-1", message:"plan \(vendorId) not found", error: error))
            }
        }
    }

    private func handleDeeplink(_ deeplink: String?, result: @escaping FlutterResult) {
        guard let deeplink = deeplink, let url = URL(string: deeplink) else {
            result(FlutterError.error(code: "-1", message: "deeplink must not be nil", error: nil))
            return
        }

        DispatchQueue.main.async {
            result(Purchasely.handleDeeplink(url))
        }
    }

    private func userSubscriptions(_ arguments: [String: Any]?, result: @escaping FlutterResult) {
        // PAR-29: defaults to false, aligned with the native default.
        let invalidateCache = (arguments?["invalidateCache"] as? Bool) ?? false
        DispatchQueue.main.async {
            Purchasely.userSubscriptions(invalidateCache) { subscriptions in
                result((subscriptions ?? []).compactMap { $0.toMap })
            } failure: { error in
                result(FlutterError.error(code:"-1", message:"failed to fetch user subscriptions", error: error))
            }
        }
    }

    private func userSubscriptionsHistory(_ arguments: [String: Any]?, result: @escaping FlutterResult) {
        let invalidateCache = (arguments?["invalidateCache"] as? Bool) ?? false
        DispatchQueue.main.async {
            Purchasely.userSubscriptionsHistory(invalidateCache) { subscriptions in
                result((subscriptions ?? []).compactMap { $0.toMap })
            } failure: { error in
                result(FlutterError.error(code:"-1", message:"failed to fetch user subscriptions history", error: error))
            }
        }
    }

    private func setThemeMode(arguments: [String: Any]?) {
        guard let arguments = arguments, let mode = arguments["mode"] as? Int, let themeMode = Purchasely.PLYThemeMode(rawValue: mode) else {
            return
        }

        Purchasely.setThemeMode(themeMode)
    }

    private func setAttribute(arguments: [String: Any]?) {
        guard let arguments = arguments,
            let value = arguments["value"] as? String,
            let attribute = arguments["attribute"] as? Int,
            let flutterAttribute = FlutterPLYAttribute(rawValue: attribute) else {
            return
        }

        let attr: Purchasely.PLYAttribute? = {
            switch flutterAttribute {
            case .firebaseAppInstanceId:
                return .firebaseAppInstanceId
            case .airshipChannelId:
                return .airshipChannelId
            case .airshipUserId:
                return .airshipUserId
            case .batchInstallationId:
                return .batchInstallationId
            case .adjustId:
                return .adjustId
            case .appsflyerId:
                return .appsflyerId
            case .mixpanelDistinctId:
                return .mixpanelDistinctId
            case .cleverTapId:
                return .clevertapId
            case .sendinblueUserEmail:
                return .sendinblueUserEmail
            case .iterableUserEmail:
                return .iterableUserEmail
            case .iterableUserId:
                return .iterableUserId
            case .atInternetIdClient:
                return .atInternetIdClient
            case .mParticleUserId:
                return .mParticleUserId
            case .customerioUserId:
                return .customerioUserId
            case .customerioUserEmail:
                return .customerioUserEmail
            case .branchUserDeveloperIdentity:
                return .branchUserDeveloperIdentity
            case .amplitudeUserId:
                return .amplitudeUserId
            case .amplitudeDeviceId:
                return .amplitudeDeviceId
            case .moengageUniqueId:
                return .moengageUniqueId
            case .oneSignalExternalId:
                return .oneSignalExternalId
            case .batchCustomUserId:
                return .batchCustomUserId
            case .oneSignalUserId:
                return .oneSignalUserId
            }
        }()

        guard let attributeKey = attr else { return }
        Purchasely.setAttribute(attributeKey, value: value)
    }

    private func setUserAttributeWithString(arguments: [String: Any]?) {
        guard let (key, value, processingLegalBasis) = mapUserAttributesCallArguments(arguments: arguments, type: String.self) else {
            return
        }
        Purchasely.setUserAttribute(withStringValue: value, forKey: key, processingLegalBasis: processingLegalBasis)
    }

    private func setUserAttributeWithStringArray(arguments: [String: Any]?) {
        guard let (key, value, processingLegalBasis) = mapUserAttributesCallArguments(arguments: arguments, type: [String].self) else {
            return
        }
        Purchasely.setUserAttribute(withStringArray: value, forKey: key, processingLegalBasis: processingLegalBasis)
    }

    private func setUserAttributeWithInt(arguments: [String: Any]?) {
        guard let (key, value, processingLegalBasis) = mapUserAttributesCallArguments(arguments: arguments, type: Int.self) else {
            return
        }
        Purchasely.setUserAttribute(withIntValue: value, forKey: key, processingLegalBasis: processingLegalBasis)
    }

    private func setUserAttributeWithIntArray(arguments: [String: Any]?) {
        guard let (key, value, processingLegalBasis) = mapUserAttributesCallArguments(arguments: arguments, type: [Int].self) else {
            return
        }
        Purchasely.setUserAttribute(withIntArray: value, forKey: key, processingLegalBasis: processingLegalBasis)
    }

    private func setUserAttributeWithDouble(arguments: [String: Any]?) {
        guard let (key, value, processingLegalBasis) = mapUserAttributesCallArguments(arguments: arguments, type: Double.self) else {
            return
        }
        Purchasely.setUserAttribute(withDoubleValue: value, forKey: key, processingLegalBasis: processingLegalBasis)
    }

    private func setUserAttributeWithDoubleArray(arguments: [String: Any]?) {
        guard let (key, value, processingLegalBasis) = mapUserAttributesCallArguments(arguments: arguments, type: [Double].self) else {
            return
        }
        Purchasely.setUserAttribute(withDoubleArray: value, forKey: key, processingLegalBasis: processingLegalBasis)
    }

    private func setUserAttributeWithBoolean(arguments: [String: Any]?) {
        guard let (key, value, processingLegalBasis) = mapUserAttributesCallArguments(arguments: arguments, type: Bool.self) else {
            return
        }
        Purchasely.setUserAttribute(withBoolValue: value, forKey: key, processingLegalBasis: processingLegalBasis)
    }

    private func setUserAttributeWithBooleanArray(arguments: [String: Any]?) {
        guard let (key, value, processingLegalBasis) = mapUserAttributesCallArguments(arguments: arguments, type: [Bool].self) else {
            return
        }
        Purchasely.setUserAttribute(withBoolArray: value, forKey: key, processingLegalBasis: processingLegalBasis)
    }

    private func setUserAttributeWithDate(arguments: [String: Any]?) {
        guard let (key, value, processingLegalBasis) = mapUserAttributesCallArguments(arguments: arguments, type: String.self) else {
            return
        }

        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = TimeZone(identifier: "GMT")
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        if let date = dateFormatter.date(from: value) {
            Purchasely.setUserAttribute(withDateValue: date, forKey: key, processingLegalBasis: processingLegalBasis)
        } else {
            print("Purchasely", "Cannot save date attribute for key \(key)")
        }
    }

    private func incrementUserAttribute(arguments: [String: Any]?) {
        guard let (key, value, processingLegalBasis) = mapUserAttributesCallArguments(arguments: arguments, type: Int.self) else {
            return
        }
        Purchasely.incrementUserAttribute(withKey: key, value: value, processingLegalBasis: processingLegalBasis)
    }

    private func decrementUserAttribute(arguments: [String: Any]?) {
        guard let (key, value, processingLegalBasis) = mapUserAttributesCallArguments(arguments: arguments, type: Int.self) else {
            return
        }
        Purchasely.decrementUserAttribute(withKey: key, value: value, processingLegalBasis: processingLegalBasis)
    }

    private func mapUserAttributesCallArguments<T>(arguments: [String: Any]?, type: T.Type) -> (key: String, value: T, processingLegalBasis: PLYDataProcessingLegalBasis)? {
        guard let arguments = arguments, let value = arguments["value"] as? T, let key = arguments["key"] as? String else {
            return nil
        }
        let processingLegalBasisArg = arguments["processingLegalBasis"] as? String
        let processingLegalBasis: PLYDataProcessingLegalBasis = processingLegalBasisArg == "ESSENTIAL" ? .essential : .optional

        return (key, value, processingLegalBasis)
    }

    private func clearUserAttribute(arguments: [String: Any]?) {
        guard let arguments = arguments, let key = arguments["key"] as? String else {
            return
        }
        Purchasely.clearUserAttribute(forKey: key)
    }

    private func clearUserAttributes() {
        Purchasely.clearUserAttributes()
    }

    private func clearBuiltInAttributes() {
        Purchasely.clearBuiltInAttributes()
    }

    private func getUserAttribute(arguments: [String: Any]?, result: @escaping FlutterResult) {
        guard let arguments = arguments, let key = arguments["key"] as? String else {
            result(FlutterError.error(code: "-1", message: "key must not be nil", error: nil))
            return
        }

        let attribute = getUserAttributeForFlutter(with: Purchasely.getUserAttribute(for: key))
        DispatchQueue.main.async {
            result(attribute)
        }
    }

    private func getUserAttributes(result: @escaping FlutterResult) {

        let resultAttributes = Purchasely.userAttributes.mapValues { getUserAttributeForFlutter(with: $0) }
        DispatchQueue.main.async {
            result(resultAttributes)
        }
    }

    private func getBuiltInAttributes(result: @escaping FlutterResult) {
        let resultAttributes = Purchasely.getBuiltInAttributes().mapValues { getUserAttributeForFlutter(with: $0) }
        DispatchQueue.main.async {
            result(resultAttributes)
        }
    }

    private func getBuiltInAttribute(arguments: [String: Any]?, result: @escaping FlutterResult) {
        guard let arguments = arguments, let key = arguments["key"] as? String else {
            result(FlutterError.error(code: "-1", message: "key must not be nil", error: nil))
            return
        }

        let attribute = getUserAttributeForFlutter(with: Purchasely.getBuiltInAttribute(with: key))
        DispatchQueue.main.async {
            result(attribute)
        }
    }

    private func userDidConsumeSubscriptionContent() {
        Purchasely.userDidConsumeSubscriptionContent()
    }

    private func setDynamicOffering(arguments: [String: Any]?, result: @escaping FlutterResult) {
        guard let arguments = arguments,
              let reference = arguments["reference"] as? String,
              let planVendorId = arguments["planVendorId"] as? String else {
            result(FlutterError.error(code: "-1", message: "reference and planVendorId must not be nil", error: nil))
            return
        }

        let offerVendorId = arguments["offerVendorId"] as? String
        let billingPlanType = Self.billingPlanType(fromWire: arguments["billingPlanType"] as? String)

        DispatchQueue.main.async {
            Purchasely.setDynamicOffering(reference: reference, planVendorId: planVendorId, offerVendorId: offerVendorId, billingPlanType: billingPlanType, completion: { success in
                result(success)
            })
        }
    }

    /// Maps the Dart `billingPlanType` wire string to the native enum. Unknown
    /// / nil (Apple-only feature) falls back to `.unspecified`.
    private static func billingPlanType(fromWire wire: String?) -> PLYBillingPlanType {
        switch wire {
        case "up_front": return .upFront
        case "monthly":  return .monthly
        default:         return .unspecified
        }
    }

    private func getDynamicOfferings(result: @escaping FlutterResult) {
        DispatchQueue.main.async {
            Purchasely.getDynamicOfferings { offerings in
                // create new empty list
                var list: [[String: String]] = []
                offerings.forEach(  { offering in
                    // create new dictionary for each offering
                    var map = [String: String]()

                    map["reference"] = offering.reference
                    map["planVendorId"] = offering.planId
                    map["billingPlanType"] = offering.billingPlanType.wireValue

                    if let offerId = offering.offerId {
                        map["offerVendorId"] = offerId
                    }

                    list.append(map)
                })
                result(list)
            }
        }
    }

    private func removeDynamicOffering(arguments: [String: Any]?) {
        guard let arguments = arguments,
              let reference = arguments["reference"] as? String else {
            return
        }

        Purchasely.removeDynamicOffering(reference: reference)
    }

    private func clearDynamicOfferings() {
        Purchasely.clearDynamicOfferings()
    }

    private func revokeDataProcessingConsent(arguments: [String: Any]?) {
        guard let arguments, let purposesArg = arguments["purposes"] as? [String] else {
            return
        }
        let purposes: Set<PLYDataProcessingPurpose> = if purposesArg.contains("ALL_NON_ESSENTIALS") {
            Set([PLYDataProcessingPurpose.allNonEssentials])
        } else {
            Set(purposesArg.compactMap { (value: String) -> PLYDataProcessingPurpose? in
                switch value {
                    case "ANALYTICS": .analytics
                    case "IDENTIFIED_ANALYTICS": .identifiedAnalytics
                    case "CAMPAIGNS": .campaigns
                    case "PERSONALIZATION": .personalization
                    case "THIRD_PARTY_INTEGRATIONS": .thirdPartyIntegrations
                    default: nil
                }
            })
        }
        Purchasely.revokeDataProcessingConsent(for: purposes)
    }

    private func setDebugMode(arguments: [String: Any]?) {
        guard let arguments, let enabled = arguments["debugMode"] as? Bool else {
            return
        }

        Purchasely.setDebugMode(enabled: enabled)
    }
}

// MARK: - Presentation EventChannel handler

final class PresentationEventHandler: NSObject, FlutterStreamHandler {
    private var sink: FlutterEventSink?

    func onListen(withArguments _: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        sink = events
        return nil
    }

    func onCancel(withArguments _: Any?) -> FlutterError? {
        sink = nil
        return nil
    }

    func emit(_ payload: [String: Any?]) {
        DispatchQueue.main.async { [weak self] in
            self?.sink?(payload.compactMapValues { $0 })
        }
    }
}

extension FlutterError {
    static let nilArgument = FlutterError(
        code: "argument.nil",
        message: "Expect an argument when invoking channel method, but it is nil.",
        details: nil
    )

    static func failedArgumentField<T>(_ fieldName: String, type: T.Type) -> FlutterError {
        return .init(
            code: "argument.failedField",
            message: "Expect a `\(fieldName)` field with type <\(type)> in the argument, " +
            "but it is missing or type not matched.",
            details: fieldName)
    }

    static func error(code: String, message: String?, error: Error?) -> FlutterError {
        return .init(
            code: code,
            message: message,
            details: error?.localizedDescription)
    }
}

class SwiftEventHandler: NSObject, FlutterStreamHandler, PLYEventDelegate {

    var eventSink: FlutterEventSink?

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        // Use the closure-based v6 API (setEventCallback) — more reliable than
        // the ObjC delegate API (setEventDelegate) in SDK v6 RC+.
        Purchasely.setEventCallback { [weak self] event, properties in
            guard let self = self, let sink = self.eventSink else { return }
            let name = NSString.fromPLYEvent(event)
            DispatchQueue.main.async {
                sink(["name": name, "properties": properties ?? [:]])
            }
        }
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        Purchasely.removeEventDelegate()
        return nil
    }

    func eventTriggered(_ event: PLYEvent, properties: [String : Any]?) {
        guard let eventSink = self.eventSink else { return }
        let name = NSString.fromPLYEvent(event)
        DispatchQueue.main.async {
            eventSink(["name": name, "properties": properties ?? [:]])
        }
    }
}

class SwiftPurchaseHandler: NSObject, FlutterStreamHandler {

    var eventSink: FlutterEventSink?

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events

        NotificationCenter.default.addObserver(self, selector: #selector(purchasePerformed), name: .ply_purchasedSubscription, object: nil)

        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        NotificationCenter.default.removeObserver(self, name: .ply_purchasedSubscription, object: nil)
        return nil
    }

    @objc func purchasePerformed() {
        self.eventSink?(nil)
    }

}

/// Bridges `PLYWebRedemptionDelegate` to the `purchasely-web-redemption` channel
/// (6.1.0).
///
/// The delegate is registered on the start chain, not in `onListen`: a redemption
/// can settle during `start()`. Dart is documented to add its listener before
/// `start()`, and a platform channel delivers `listen` before the later `start`
/// invocation on the same messenger, so the sink is attached by then.
/// ponytail: no replay buffer — a listener attached after `start()` misses an
/// in-flight redemption, which is exactly what the "add it before start()"
/// contract says.
class WebRedemptionHandler: NSObject, FlutterStreamHandler, PLYWebRedemptionDelegate {

    var eventSink: FlutterEventSink?

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }

    /// `PLYWebRedemptionDelegate`. The SDK calls this on the main thread, once per
    /// settled redemption. Mapped to the flat 5-field shape the Android bridge
    /// emits, so one Dart listener drives both platforms.
    ///
    /// `context` and `context.subscription` are separately nullable, and both stay
    /// nullable in the emitted body: a success can carry no context at all, and a
    /// present context can carry no subscription.
    ///
    /// `errorMessage` can hold the backend's masked email hint for an expired link.
    /// The `REDEMPTION_FAILED` event drops that hint on purpose; this channel keeps
    /// it, so the app can tell the user where the fresh link went. Android does the
    /// same in `RedemptionOutcome.Expired.toResult()` — the hint is NOT iOS-only,
    /// and the Dart docs must not say it is.
    func webRedemptionCompleted(result: PLYWebRedemptionResult) {
        guard let eventSink = self.eventSink else { return }

        let body = Self.webRedemptionBody(
            isSuccess: result.isSuccess,
            hasContext: result.context != nil,
            subscription: result.context?.subscription?.toMap,
            replay: result.replay,
            errorCode: result.errorCode,
            errorMessage: result.errorMessage)

        DispatchQueue.main.async {
            eventSink(body)
        }
    }

    /// Builds the `purchasely-web-redemption` event body.
    ///
    /// Extracted from the delegate callback, and taking the already-destructured
    /// fields instead of a `PLYWebRedemptionResult`, because that type's
    /// initialiser is `internal` to the Purchasely module: a test target cannot
    /// construct one. `subscription` arrives already mapped, so a test needs no
    /// native type at all. This is the only way to unit-test the payload policy
    /// below, which is otherwise reachable only from a real redemption.
    ///
    /// Two invariants it exists to pin:
    ///
    /// - `context` and `context.subscription` are separately nullable, and the
    ///   two nulls mean different things: no context at all, versus a context
    ///   that describes no subscription. Both stay distinguishable in Dart.
    /// - The same five keys on every branch, so the Dart shape never changes
    ///   between a success and a failure.
    static func webRedemptionBody(isSuccess: Bool,
                                  hasContext: Bool,
                                  subscription: [String: Any]?,
                                  replay: Bool,
                                  errorCode: String?,
                                  errorMessage: String?) -> [String: Any] {
        var context: Any = NSNull()
        if hasContext {
            let mappedSubscription: Any = subscription ?? NSNull()
            context = ["subscription": mappedSubscription]
        }

        let code: Any = errorCode ?? NSNull()
        let message: Any = errorMessage ?? NSNull()

        return [
            "isSuccess": isSuccess,
            "context": context,
            "replay": replay,
            "errorCode": code,
            "errorMessage": message
        ]
    }
}

class UserAttributesHandler: NSObject, FlutterStreamHandler, PLYUserAttributeDelegate {

    var eventSink: FlutterEventSink?

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        Purchasely.setUserAttributeDelegate(self)
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        //Purchasely.setUserAttributeDelegate(nil)
        return nil
    }

    func onUserAttributeSet(key: String, type: PLYUserAttributeType, value: Any?, source: PLYUserAttributeSource) {
        guard let eventSink = self.eventSink else { return }

        var formattedType = ""
        switch type {
        case .string:
            formattedType = "STRING"
        case .bool:
            formattedType = "BOOLEAN"
        case .int:
            formattedType = "INT"
        case .double:
            formattedType = "FLOAT"
        case .date:
            formattedType = "DATE"
        case .stringArray:
            formattedType = "STRING_ARRAY"
        case .intArray:
            formattedType = "INT_ARRAY"
        case .doubleArray:
            formattedType = "FLOAT_ARRAY"
        case .boolArray:
            formattedType = "BOOLEAN_ARRAY"
        case .dictionary:
            formattedType = "DICTIONARY"
        case .unknown:
            formattedType = ""
        @unknown default:
            formattedType = ""
        }

        DispatchQueue.main.async {
            eventSink([
                "event": "set",
                "key": key,
                "type": formattedType,
                "value": getUserAttributeForFlutter(with: value),
                "source": source.rawValue
            ])
        }
    }

    func onUserAttributeRemoved(key: String, source: PLYUserAttributeSource) {
        guard let eventSink = self.eventSink else { return }
        DispatchQueue.main.async {
            eventSink([
                "event": "removed",
                "key": key,
                "source": source.rawValue
            ])
        }
    }
}

fileprivate func getDateFormatter() -> DateFormatter {
    let dateFormatter = DateFormatter()
    dateFormatter.timeZone = TimeZone(identifier: "GMT")
    dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
    return dateFormatter
}

fileprivate func getUserAttributeForFlutter(with value: Any?) -> Any? {

    if let dateValue = value as? Date {
        let dateFormatter = getDateFormatter()
        return dateFormatter.string(from: dateValue)
    }

    return value
}

extension UIViewController {

    @objc func close() {
        self.dismiss(animated: true, completion: nil)
    }

}

// MARK: - UIColor helper

extension UIColor {
    static func ply_from(hex: String) -> UIColor? {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6 || s.count == 8 else { return nil }
        if s.count == 6 { s = "FF" + s }
        var rgba: UInt64 = 0
        guard Scanner(string: s).scanHexInt64(&rgba) else { return nil }
        let a = CGFloat((rgba >> 24) & 0xFF) / 255.0
        let r = CGFloat((rgba >> 16) & 0xFF) / 255.0
        let g = CGFloat((rgba >> 8)  & 0xFF) / 255.0
        let b = CGFloat( rgba        & 0xFF) / 255.0
        return UIColor(red: r, green: g, blue: b, alpha: a)
    }
}

// WARNING: This enum must be strictly identical (same case names, same order)
// to purchasely_flutter.PLYAttribute (Dart) and FlutterPLYAttribute (Android,
// PurchaselyFlutterPlugin.kt). All 3 bridges map by case *name* to the native
// `Purchasely.PLYAttribute`/`Attribute`, never by raw ordinal — the two native
// SDKs' own attribute enums are NOT ordinal-aligned with each other (iOS has
// `oneSignalPlayerId` at a different position; Android has no such case at
// all), so an ordinal-based bridge mapping would silently cross-wire
// attributes. Add new cases here, in purchasely_flutter.dart's PLYAttribute
// enum, and in PurchaselyFlutterPlugin.kt's FlutterPLYAttribute in lockstep.
enum FlutterPLYAttribute: Int {
    case firebaseAppInstanceId
    case airshipChannelId
    case airshipUserId
    case batchInstallationId
    case adjustId
    case appsflyerId
    case mixpanelDistinctId
    case cleverTapId
    case sendinblueUserEmail
    case iterableUserEmail
    case iterableUserId
    case atInternetIdClient
    case mParticleUserId
    case customerioUserId
    case customerioUserEmail
    case branchUserDeveloperIdentity
    case amplitudeUserId
    case amplitudeDeviceId
    case moengageUniqueId
    case oneSignalExternalId
    case batchCustomUserId
    case oneSignalUserId
}
