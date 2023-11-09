import Flutter
import UIKit
import Purchasely

public class SwiftPurchaselyFlutterPlugin: NSObject, FlutterPlugin {

    let eventChannel: FlutterEventChannel
    let eventHandler: SwiftEventHandler

    let purchaseChannel: FlutterEventChannel
    let purchaseHandler: SwiftPurchaseHandler

    var presentedPresentationViewController: UIViewController?

    var purchaseResult: FlutterResult?
    var presentationsLoaded = [PLYPresentation]()

    var onProcessActionHandler: ((Bool) -> Void)?

    public init(with registrar: FlutterPluginRegistrar) {
        self.eventChannel = FlutterEventChannel(name: "purchasely-events",
                                           binaryMessenger: registrar.messenger())
        self.eventHandler = SwiftEventHandler()
        self.eventChannel.setStreamHandler(self.eventHandler)

        self.purchaseChannel = FlutterEventChannel(name: "purchasely-purchases",
                                                   binaryMessenger: registrar.messenger())
        self.purchaseHandler = SwiftPurchaseHandler()
        self.purchaseChannel.setStreamHandler(self.purchaseHandler)

        super.init()
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "purchasely",
                                           binaryMessenger: registrar.messenger())

        let instance = SwiftPurchaselyFlutterPlugin(with: registrar)
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let arguments = call.arguments as? [String: Any]
        switch call.method {
        case "start":
            start(arguments: call.arguments as? [String: Any], result: result)
        case "startWithApiKey":
            startWithApiKey(arguments: call.arguments as? [String: Any], result: result)
        case "close":
            DispatchQueue.main.async {
                result(true)
            }
        case "setDefaultPresentationResultHandler":
            setDefaultPresentationResultHandler(result: result)
        case "fetchPresentation":
            fetchPresentation(arguments: arguments, result: result)
        case "presentPresentation":
            presentPresentation(arguments: arguments, result: result)
        case "clientPresentationDisplayed":
            clientPresentationDisplayed(arguments: arguments)
        case "clientPresentationClosed":
            clientPresentationClosed(arguments: arguments)
        case "presentPresentationWithIdentifier":
            presentPresentationWithIdentifier(arguments: arguments, result: result)
        case "presentProductWithIdentifier":
            presentProductWithIdentifier(arguments: arguments, result: result)
        case "presentPlanWithIdentifier":
            presentPlanWithIdentifier(arguments: arguments, result: result)
        case "presentPresentationForPlacement":
            presentPresentationForPlacement(arguments: arguments, result: result)
        case "restoreAllProducts":
            restoreAllProducts(result)
        case "silentRestoreAllProducts":
            silentRestoreAllProducts(result)
        case "getAnonymousUserId":
            DispatchQueue.main.async { [weak self] in
                guard let `self` = self else { return }
                result(self.getAnonymousUserId())
            }
        case "userLogin":
            userLogin(arguments: arguments, result: result)
        case "userLogout":
            userLogout()
        case "readyToOpenDeeplink":
            let parameter = arguments?["readyToOpenDeeplink"] as? Bool
            readyToOpenDeeplink(readyToOpenDeeplink: parameter)
        case "setLogLevel":
            let parameter = (arguments?["logLevel"] as? Int) ?? PLYLogger.LogLevel.debug.rawValue
            let logLevel = PLYLogger.LogLevel(rawValue: parameter) ?? PLYLogger.LogLevel.debug
            Purchasely.setLogLevel(logLevel)
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
        case "isDeeplinkHandled":
            let parameter = arguments?["deeplink"] as? String
            isDeeplinkHandled(parameter, result: result)
        case "userSubscriptions":
            userSubscriptions(result)
        case "presentSubscriptions":
            presentSubscriptions()
        case "setAttribute":
            setAttribute(arguments: arguments)
        case "setPaywallActionInterceptor":
            setPaywallActionInterceptor(result: result)
        case "setLanguage":
            let parameter = arguments?["language"] as? String
            setLanguage(with: parameter)
        case "onProcessAction":
            let parameter = arguments?["processAction"] as? Bool
            onProcessAction(parameter ?? true)
        case "userDidConsumeSubscriptionContent":
            userDidConsumeSubscriptionContent()
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
        case "userAttribute":
            getUserAttribute(arguments: arguments, result: result)
        case "userAttributes":
            getUserAttributes(result: result)
        case "clearUserAttribute":
            clearUserAttribute(arguments: arguments)
        case "clearUserAttributes":
            clearUserAttributes()
        case "synchronize", "displaySubscriptionCancellationInstruction":
            result(FlutterMethodNotImplemented)
        case "isAnonymous":
            isAnonymous(result: result)
        case "hidePresentation":
            hidePresentation()
        case "showPresentation":
            showPresentation()
        case "closePresentation":
            closePresentation()
        case "signPromotionalOffer":
            signPromotionalOffer(arguments: arguments, result: result)
        case "isEligibleForIntroOffer":
            isEligibleForIntroOffer(arguments: arguments, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func isAnonymous(result: @escaping FlutterResult) {
        result(Purchasely.isAnonymous())
    }

    private func hidePresentation() {
        if let presentedPresentationViewController = presentedPresentationViewController {
            DispatchQueue.main.async {
                var presentingViewController = presentedPresentationViewController;
                while let presentingController = presentingViewController.presentingViewController {
                    presentingViewController = presentingController
                }
                presentingViewController.dismiss(animated: true, completion: nil)
            }
        }
    }

    private func closePresentation() {
        self.presentedPresentationViewController = nil
        Purchasely.closeDisplayedPresentation()
    }

    private func showPresentation() {
        if let presentedPresentationViewController = presentedPresentationViewController {
            DispatchQueue.main.async {
                Purchasely.showController(presentedPresentationViewController, type: .productPage)
            }
        }
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

    private func start(arguments: [String: Any]?, result: @escaping FlutterResult) {

        guard let arguments = arguments, let apiKey = arguments["apiKey"] as? String else {
            result(FlutterError.failedArgumentField("apiKey", type: String.self))
            return
        }

		Purchasely.setSdkBridgeVersion("4.1.0")
        Purchasely.setAppTechnology(PLYAppTechnology.flutter)

        let logLevel = PLYLogger.LogLevel(rawValue: (arguments["logLevel"] as? Int) ?? PLYLogger.LogLevel.debug.rawValue) ?? PLYLogger.LogLevel.debug
        let userId = arguments["userId"] as? String
        let runningMode = PLYRunningMode(rawValue: (arguments["runningMode"] as? Int) ?? PLYRunningMode.full.rawValue) ?? PLYRunningMode.full
        let storeKitSettingRawValue = arguments["storeKit1"] as? Bool ?? false
        let storeKitSetting = storeKitSettingRawValue ? StorekitSettings.storeKit1 : StorekitSettings.storeKit2

        DispatchQueue.main.async {
            Purchasely.start(withAPIKey: apiKey,
                             appUserId: userId,
                             runningMode: runningMode,
                             paywallActionsInterceptor: nil,
                             storekitSettings: storeKitSetting,
                             logLevel: logLevel) { success, error in
                if success {
                    result(success)
                } else {
                    result(FlutterError.error(code: "0", message: "Purchasely SDK not configured", error: error))
                }
            }
        }
    }

    private func startWithApiKey(arguments: [String: Any]?, result: @escaping FlutterResult) {
        guard let arguments = arguments, let apiKey = arguments["apiKey"] as? String else {
            result(FlutterError.failedArgumentField("apiKey", type: String.self))
            return
        }

		Purchasely.setSdkBridgeVersion("4.1.0")
        Purchasely.setAppTechnology(PLYAppTechnology.flutter)

        let logLevel = PLYLogger.LogLevel(rawValue: (arguments["logLevel"] as? Int) ?? PLYLogger.LogLevel.debug.rawValue) ?? PLYLogger.LogLevel.debug
        let userId = arguments["userId"] as? String
        let runningMode = PLYRunningMode(rawValue: (arguments["runningMode"] as? Int) ?? PLYRunningMode.full.rawValue) ?? PLYRunningMode.full

        DispatchQueue.main.async {
            Purchasely.start(withAPIKey: apiKey,
                             appUserId: userId,
                             runningMode: runningMode,
                             paywallActionsInterceptor: nil,
                             logLevel: logLevel) { success, error in
                if success {
                    result(success)
                } else {
                    result(FlutterError.error(code: "0", message: "Purchasely SDK not configured", error: error))
                }
            }
        }
    }

    private func fetchPresentation(arguments: [String: Any]?, result: @escaping FlutterResult) {

        let placementId = arguments?["placementVendorId"] as? String
        let presentationId = arguments?["presentationVendorId"] as? String
        let contentId = arguments?["contentId"] as? String

        if let placementId = placementId {
            Purchasely.fetchPresentation(for: placementId, contentId: contentId, fetchCompletion: { [weak self] presentation, error in
                guard let `self` = self else { return }
                DispatchQueue.main.async {
                    if let error = error {
                        result(FlutterError.error(code: "-1", message: "Error while fetching presentation", error: error))
                    } else if let presentation = presentation {
                        self.presentationsLoaded.append(presentation)
                        result(presentation.toMap)
                    }
                }
            }) { [weak self] productResult, plan in
                guard let `self` = self else { return }
                let value: [String: Any] = ["result": productResult.rawValue, "plan": plan?.toMap ?? [:]]
                DispatchQueue.main.async {
                    self.purchaseResult?(value)
                }
            }
        } else if let presentationId = presentationId {
            Purchasely.fetchPresentation(with: presentationId, contentId: contentId, fetchCompletion: { [weak self] presentation, error in
                guard let `self` = self else { return }
                DispatchQueue.main.async {
                    if let error = error {
                        result(FlutterError.error(code: "-1", message: "Error while fetching presentation", error: error))
                    } else if let presentation = presentation {
                        self.presentationsLoaded.append(presentation)
                        result(presentation.toMap)
                    }
                }
            }) { [weak self] productResult, plan in
                guard let `self` = self else { return }
                let value: [String: Any] = ["result": productResult.rawValue, "plan": plan?.toMap ?? [:]]
                DispatchQueue.main.async {
                    self.purchaseResult?(value)
                }
            }
        }
    }

    private func presentPresentation(arguments: [String: Any]?, result: @escaping FlutterResult) {
        guard let presentationMap = arguments?["presentation"] as? [String: Any] else {
            result(FlutterError.error(code: "-1", message: "Presentation cannot be nil", error: nil))
            return
        }

        self.purchaseResult = result

        guard let presentationId = presentationMap["id"] as? String, 
                let placementId = presentationMap["placementId"] as? String,
                let presentationLoaded = self.presentationsLoaded.filter({ $0.id == presentationId && $0.placementId == placementId }).first,
                let controller = presentationLoaded.controller else {
            result(FlutterError.error(code: "-1", message: "Presentation not loaded", error: nil))
            return
        }

        self.presentationsLoaded.removeAll(where: { $0.id == presentationId })

        let navCtrl = UINavigationController(rootViewController: controller)
        navCtrl.navigationBar.isTranslucent = true
        navCtrl.navigationBar.setBackgroundImage(UIImage(), for: .default)
        navCtrl.navigationBar.shadowImage = UIImage()
        navCtrl.navigationBar.tintColor = UIColor.white

        self.presentedPresentationViewController = navCtrl

        if let isFullscreen = arguments?["isFullscreen"] as? Bool, isFullscreen {
            navCtrl.modalPresentationStyle = .fullScreen
        }

        DispatchQueue.main.async {
            Purchasely.showController(navCtrl, type: .productPage)
        }
    }

    private func clientPresentationDisplayed(arguments: [String: Any]?) {
        guard let presentationMap = arguments?["presentation"] as? [String: Any] else {
            print("Presentation cannot be nil")
            return
        }

        guard let presentationId = presentationMap["id"] as? String, 
                let placementId = presentationMap["placementId"] as? String,
                let presentationLoaded = self.presentationsLoaded.filter({ $0.id == presentationId && $0.placementId == placementId }).first else { return }

        Purchasely.clientPresentationOpened(with: presentationLoaded)
    }

    private func clientPresentationClosed(arguments: [String: Any]?) {
        guard let presentationMap = arguments?["presentation"] as? [String: Any] else {
            print("Presentation cannot be nil")
            return
        }

        guard let presentationId = presentationMap["id"] as? String,
              let placementId = presentationMap["placementId"] as? String,
              let presentationLoaded = self.presentationsLoaded.filter({ $0.id == presentationId && $0.placementId == placementId }).first else { return }

        Purchasely.clientPresentationClosed(with: presentationLoaded)
    }

    private func presentPresentationWithIdentifier(arguments: [String: Any]?, result: @escaping FlutterResult) {

        let presentationVendorId = arguments?["presentationVendorId"] as? String
        let contentId = arguments?["contentId"] as? String

        let controller = Purchasely.presentationController(with: presentationVendorId,
                                                           contentId: contentId,
                                                           loaded: nil) { productResult, plan in
            let value: [String: Any] = ["result": productResult.rawValue, "plan": plan?.toMap ?? [:]]
            DispatchQueue.main.async {
                result(value)
            }
        }

        if let controller = controller {
            let navCtrl = UINavigationController(rootViewController: controller)
            navCtrl.navigationBar.isTranslucent = true
            navCtrl.navigationBar.setBackgroundImage(UIImage(), for: .default)
            navCtrl.navigationBar.shadowImage = UIImage()
            navCtrl.navigationBar.tintColor = UIColor.white

            self.presentedPresentationViewController = navCtrl

            if let isFullscreen = arguments?["isFullscreen"] as? Bool, isFullscreen {
                navCtrl.modalPresentationStyle = .fullScreen
            }

            DispatchQueue.main.async {
                Purchasely.showController(navCtrl, type: .productPage)
            }
        } else {
            result(FlutterError.error(code: "-1", message: "You are using a running mode that prevent paywalls to be displayed", error: nil))
        }
    }

    private func presentPresentationForPlacement(arguments: [String: Any]?, result: @escaping FlutterResult) {

        let placementVendorId = (arguments?["placementVendorId"] as? String) ?? ""
        let contentId = arguments?["contentId"] as? String

        let controller = Purchasely.presentationController(for: placementVendorId,
                                                           contentId: contentId,
                                                           loaded: nil) { productResult, plan in
            let value: [String: Any] = ["result": productResult.rawValue, "plan": plan?.toMap ?? [:]]
            DispatchQueue.main.async {
                result(value)
            }
        }

        if let controller = controller {
            let navCtrl = UINavigationController(rootViewController: controller)
            navCtrl.navigationBar.isTranslucent = true
            navCtrl.navigationBar.setBackgroundImage(UIImage(), for: .default)
            navCtrl.navigationBar.shadowImage = UIImage()
            navCtrl.navigationBar.tintColor = UIColor.white

            self.presentedPresentationViewController = navCtrl

            if let isFullscreen = arguments?["isFullscreen"] as? Bool, isFullscreen {
                navCtrl.modalPresentationStyle = .fullScreen
            }

            DispatchQueue.main.async {
                Purchasely.showController(navCtrl, type: .productPage)
            }
        } else {
            result(FlutterError.error(code: "-1", message: "You are using a running mode that prevent paywalls to be displayed", error: nil))
        }
    }

    private func presentProductWithIdentifier(arguments: [String: Any]?, result: @escaping FlutterResult) {

        guard let arguments = arguments, let productVendorId = arguments["productVendorId"] as? String else {
            result(FlutterError.error(code: "-1", message: "product vendor id must not be nil", error: nil))
            return
        }
        let presentationVendorId = arguments["presentationVendorId"] as? String
        let contentId = arguments["contentId"] as? String

        let controller = Purchasely.productController(for: productVendorId,
                                                         with: presentationVendorId,
                                                         contentId: contentId,
                                                         loaded: nil) { productResult, plan in
            let value: [String: Any] = ["result": productResult.rawValue, "plan": plan?.toMap ?? [:]]
            DispatchQueue.main.async {
                result(value)
            }
        }

        if let controller = controller {
            let navCtrl = UINavigationController(rootViewController: controller)
            navCtrl.navigationBar.isTranslucent = true
            navCtrl.navigationBar.setBackgroundImage(UIImage(), for: .default)
            navCtrl.navigationBar.shadowImage = UIImage()
            navCtrl.navigationBar.tintColor = UIColor.white

            self.presentedPresentationViewController = navCtrl

            if let isFullscreen = arguments["isFullscreen"] as? Bool, isFullscreen {
                navCtrl.modalPresentationStyle = .fullScreen
            }

            DispatchQueue.main.async {
                Purchasely.showController(navCtrl, type: .productPage)
            }
        } else {
            result(FlutterError.error(code: "-1", message: "You are using a running mode that prevent paywalls to be displayed", error: nil))
        }
    }

    private func presentPlanWithIdentifier(arguments: [String: Any]?, result: @escaping FlutterResult) {

        guard let arguments = arguments, let planVendorId = arguments["planVendorId"] as? String else {
            result(FlutterError.error(code: "-1", message: "plan vendor id must not be nil", error: nil))
            return
        }
        let presentationVendorId = arguments["presentationVendorId"] as? String
        let contentId = arguments["contentId"] as? String

        let controller = Purchasely.planController(for: planVendorId,
                                                      with: presentationVendorId,
                                                      contentId: contentId,
                                                      loaded:nil) { productResult, plan in
            let value: [String: Any] = ["result": productResult.rawValue, "plan": plan?.toMap ?? [:]]
            DispatchQueue.main.async {
                result(value)
            }
        }

        if let controller = controller {
            let navCtrl = UINavigationController(rootViewController: controller)
            navCtrl.navigationBar.isTranslucent = true
            navCtrl.navigationBar.setBackgroundImage(UIImage(), for: .default)
            navCtrl.navigationBar.shadowImage = UIImage()
            navCtrl.navigationBar.tintColor = UIColor.white

            self.presentedPresentationViewController = navCtrl

            if let isFullscreen = arguments["isFullscreen"] as? Bool, isFullscreen {
                navCtrl.modalPresentationStyle = .fullScreen
            }

            DispatchQueue.main.async {
                Purchasely.showController(navCtrl, type: .productPage)
            }
        } else {
            result(FlutterError.error(code: "-1", message: "You are using a running mode that prevent paywalls to be displayed", error: nil))
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

    private func userLogout() {
        Purchasely.userLogout()
    }

    private func readyToOpenDeeplink(readyToOpenDeeplink: Bool?) {
        Purchasely.readyToOpenDeeplink(readyToOpenDeeplink ?? true)
    }

    private func setDefaultPresentationResultHandler(result: @escaping FlutterResult) {
        DispatchQueue.main.async {
            Purchasely.setDefaultPresentationResultHandler { productResult, plan in
                let value: [String: Any] = ["result": productResult.rawValue, "plan": plan?.toMap ?? [:]]
                result(value)
            }
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

    private func isDeeplinkHandled(_ deeplink: String?, result: @escaping FlutterResult) {
        guard let deeplink = deeplink, let url = URL(string: deeplink) else {
            result(FlutterError.error(code: "-1", message: "deeplink must not be nil", error: nil))
            return
        }

        DispatchQueue.main.async {
            result(Purchasely.isDeeplinkHandled(deeplink: url))
        }
    }

    private func userSubscriptions(_ result: @escaping FlutterResult) {

        DispatchQueue.main.async {
            Purchasely.userSubscriptions { subscriptions in
                result((subscriptions ?? []).compactMap { $0.toMap })
            } failure: { error in
                result(FlutterError.error(code:"-1", message:"failed to fetch user subscriptions", error: error))
            }
        }
    }

    private func presentSubscriptions() {
        if let controller = Purchasely.subscriptionsController() {
            let navCtrl = UINavigationController.init(rootViewController: controller)
            navCtrl.navigationBar.topItem?.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: navCtrl, action: #selector(UIViewController.close))

            DispatchQueue.main.async {
                Purchasely.showController(navCtrl, type: .subscriptionList)
            }
        }
    }

    private func setAttribute(arguments: [String: Any]?) {
        guard let arguments = arguments, let value = arguments["value"] as? String, let attribute = arguments["attribute"] as? Int, let attr = Purchasely.PLYAttribute(rawValue: attribute) else {
            return
        }

        Purchasely.setAttribute(attr, value: value)
    }

    private func setUserAttributeWithString(arguments: [String: Any]?) {
        guard let arguments = arguments, let value = arguments["value"] as? String, let key = arguments["key"] as? String else {
            return
        }

        Purchasely.setUserAttribute(withStringValue: value, forKey: key)
    }

    private func setUserAttributeWithInt(arguments: [String: Any]?) {
        guard let arguments = arguments, let value = arguments["value"] as? Int, let key = arguments["key"] as? String else {
            return
        }

        Purchasely.setUserAttribute(withIntValue: value, forKey: key)
    }

    private func setUserAttributeWithDouble(arguments: [String: Any]?) {
        guard let arguments = arguments, let value = arguments["value"] as? Double, let key = arguments["key"] as? String else {
            return
        }

        Purchasely.setUserAttribute(withDoubleValue: value, forKey: key)
    }

    private func setUserAttributeWithBoolean(arguments: [String: Any]?) {
        guard let arguments = arguments, let value = arguments["value"] as? Bool, let key = arguments["key"] as? String else {
            return
        }

        Purchasely.setUserAttribute(withBoolValue: value, forKey: key)
    }

    private func setUserAttributeWithDate(arguments: [String: Any]?) {
        guard let arguments = arguments, let value = arguments["value"] as? String, let key = arguments["key"] as? String else {
            return
        }

        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = TimeZone(identifier: "GMT")
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        if let date = dateFormatter.date(from: value) {
            Purchasely.setUserAttribute(withDateValue: date, forKey: key)
        } else {
            print("Purchasely", "Cannot save date attribute for key \(key)")
        }
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

    private func getUserAttributeForFlutter(with value: Any?) -> Any? {

        if let dateValue = value as? Date {
            let dateFormatter = DateFormatter()
            dateFormatter.timeZone = TimeZone(identifier: "GMT")
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
            return dateFormatter.string(from: dateValue)
        }

        return value
    }

    private func setPaywallActionInterceptor(result: @escaping FlutterResult) {
        DispatchQueue.main.async {
            Purchasely.setPaywallActionsInterceptor { [weak self] action, parameters, info, onProcessAction in
                guard let `self` = self else { return }
                self.onProcessActionHandler = onProcessAction
                var value = [String: Any]()

                var actionString: String?
                switch action {
                case .login:
                    actionString = "login"
                case .purchase:
                    actionString = "purchase"
                case .close:
                    actionString = "close"
                case .restore:
                    actionString = "restore"
                case .navigate:
                    actionString = "navigate"
                case .promoCode:
                    actionString = "promo_code"
                case .openPresentation:
                    actionString = "open_presentation"
                @unknown default:
                    actionString = nil
                }
                if let actionString = actionString {
                    value["action"] = actionString
                }

                value["info"] = info?.toMap ?? [:]
                value["parameters"] = parameters?.toMap ?? [:]

                result(value)
            }
        }
    }

    private func onProcessAction(_ proceed: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.onProcessActionHandler?(proceed)
        }
    }

    private func userDidConsumeSubscriptionContent() {
        Purchasely.userDidConsumeSubscriptionContent()
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
        Purchasely.setEventDelegate(self)
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        Purchasely.setEventDelegate(nil)
        return nil
    }

    func eventTriggered(_ event: PLYEvent, properties: [String : Any]?) {
        guard let eventSink = self.eventSink else { return }
        DispatchQueue.main.async {
            eventSink(["name": event.name, "properties": properties ?? [:]])
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

extension UIViewController {

    @objc func close() {
        self.dismiss(animated: true, completion: nil)
    }

}
