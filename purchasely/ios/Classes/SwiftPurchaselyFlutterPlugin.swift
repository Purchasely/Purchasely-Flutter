import Flutter
import UIKit
import Purchasely

public class SwiftPurchaselyFlutterPlugin: NSObject, FlutterPlugin {

    private static var presentationsLoaded = [PLYPresentation]()
    private static var purchaseResult: FlutterResult?

    private static var isStarted: Bool = false

    let eventChannel: FlutterEventChannel
    let eventHandler: SwiftEventHandler

    let purchaseChannel: FlutterEventChannel
    let purchaseHandler: SwiftPurchaseHandler

    let userAttributesChannel: FlutterEventChannel
    let userAttributesHandler: UserAttributesHandler

    var presentedPresentationViewController: UIViewController?

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

        self.userAttributesChannel = FlutterEventChannel(name: "purchasely-user-attributes",
                                                      binaryMessenger: registrar.messenger())
        self.userAttributesHandler = UserAttributesHandler()
        self.userAttributesChannel.setStreamHandler(self.userAttributesHandler)

        super.init()
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
        case "start":
            start(arguments: call.arguments as? [String: Any], result: result)
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
            userLogout(result: result)
        case "readyToOpenDeeplink":
            let parameter = arguments?["readyToOpenDeeplink"] as? Bool
            readyToOpenDeeplink(readyToOpenDeeplink: parameter)
        case "setLogLevel":
            let parameter = (arguments?["logLevel"] as? Int) ?? PLYLogger.PLYLogLevel.debug.rawValue
            let logLevel = PLYLogger.PLYLogLevel(rawValue: parameter) ?? PLYLogger.PLYLogLevel.debug
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
        case "userSubscriptionsHistory":
            userSubscriptionsHistory(result)
        case "presentSubscriptions":
            presentSubscriptions()
        case "setThemeMode":
            setThemeMode(arguments: arguments)
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
        case "displaySubscriptionCancellationInstruction":
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
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    internal static func getPresentationController(for args: Any?, with channel: FlutterMethodChannel) -> UIViewController? {

        if let creationParams = args as? [String: Any] {

            let presentationId = creationParams["presentationId"] as? String
            let placementId = creationParams["placementId"] as? String

            guard let presentationMap = creationParams["presentation"] as? [String:Any],
                  let mapPresentationId = presentationMap["id"] as? String,
                  let mapPlacementId = presentationMap["placementId"] as? String,
                  let presentationLoaded = presentationsLoaded.filter({ $0.id == mapPresentationId && $0.placementId == mapPlacementId }).first,
                  let presentationLoadedController = presentationLoaded.controller else {
                return SwiftPurchaselyFlutterPlugin.createNativeViewController(presentationId: presentationId, placementId: placementId, channel: channel)
            }

            SwiftPurchaselyFlutterPlugin.purchaseResult = { result in
                if let value = result as? [String : Any] {
                    channel.invokeMethod("onPresentationResult", arguments: ["result": value["result"],
                                                                             "plan": value["plan"]])
                }
            }
            return presentationLoadedController
        }
        return nil
    }

    private static func createNativeViewController(presentationId: String?,
                          placementId: String?,
                          channel: FlutterMethodChannel?) -> UIViewController? {
        if let presentationId = presentationId {
            let controller = Purchasely.presentationController(
                with: presentationId,
                loaded: nil,
                completion: { result, plan in
                    if let plan = plan {
                        channel?.invokeMethod("onPresentationResult", arguments: ["result": result.rawValue,
                                                                                  "plan": plan.toMap])
                    } else {
                        channel?.invokeMethod("onPresentationResult", arguments: ["result": result.rawValue,
                                                                                  "plan": nil])
                    }
                }
            )
            return controller
        }
        else if let placementId = placementId {
            let controller = Purchasely.presentationController(
                for: placementId,
                loaded: nil,
                completion: { result, plan in
                    if let plan = plan {
                        channel?.invokeMethod("onPresentationResult", arguments: ["result": result.rawValue,
                                                                                  "plan": plan.toMap])
                    } else {
                        channel?.invokeMethod("onPresentationResult", arguments: ["result": result.rawValue,
                                                                                  "plan": nil])
                    }
                }
            )
            return controller
        }
        return nil
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

        guard !SwiftPurchaselyFlutterPlugin.isStarted else {
            result(true)
            return
        }

		Purchasely.setSdkBridgeVersion("5.3.3")
        Purchasely.setAppTechnology(PLYAppTechnology.flutter)

        let logLevel = PLYLogger.PLYLogLevel(rawValue: (arguments["logLevel"] as? Int) ?? PLYLogger.PLYLogLevel.debug.rawValue) ?? .debug
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
                    SwiftPurchaselyFlutterPlugin.isStarted = true
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
                        SwiftPurchaselyFlutterPlugin.presentationsLoaded.removeAll(where: { $0.id == presentation.id })
                        SwiftPurchaselyFlutterPlugin.presentationsLoaded.append(presentation)
                        result(presentation.toMap)
                    }
                }
            }) { [weak self] productResult, plan in
                guard let `self` = self else { return }
                let value: [String: Any] = ["result": productResult.rawValue, "plan": plan?.toMap ?? [:]]
                DispatchQueue.main.async {
                    SwiftPurchaselyFlutterPlugin.purchaseResult?(value)
                }
            }
        } else if let presentationId = presentationId {
            Purchasely.fetchPresentation(with: presentationId, contentId: contentId, fetchCompletion: { [weak self] presentation, error in
                guard let `self` = self else { return }
                DispatchQueue.main.async {
                    if let error = error {
                        result(FlutterError.error(code: "-1", message: "Error while fetching presentation", error: error))
                    } else if let presentation = presentation {
                        SwiftPurchaselyFlutterPlugin.presentationsLoaded.removeAll(where: { $0.id == presentation.id })
                        SwiftPurchaselyFlutterPlugin.presentationsLoaded.append(presentation)
                        result(presentation.toMap)
                    }
                }
            }) { [weak self] productResult, plan in
                guard let `self` = self else { return }
                let value: [String: Any] = ["result": productResult.rawValue, "plan": plan?.toMap ?? [:]]
                DispatchQueue.main.async {
                    SwiftPurchaselyFlutterPlugin.purchaseResult?(value)
                }
            }
        }
    }

    private func presentPresentation(arguments: [String: Any]?, result: @escaping FlutterResult) {
        guard let presentationMap = arguments?["presentation"] as? [String: Any] else {
            result(FlutterError.error(code: "-1", message: "Presentation cannot be nil", error: nil))
            return
        }

        SwiftPurchaselyFlutterPlugin.purchaseResult = result

        guard let presentationId = presentationMap["id"] as? String,
                let placementId = presentationMap["placementId"] as? String,
                let presentationLoaded = SwiftPurchaselyFlutterPlugin.presentationsLoaded.filter({ $0.id == presentationId && $0.placementId == placementId }).first,
                let controller = presentationLoaded.controller else {
            result(FlutterError.error(code: "-1", message: "Presentation not loaded", error: nil))
            return
        }

        SwiftPurchaselyFlutterPlugin.presentationsLoaded.removeAll(where: { $0.id == presentationId })

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
            if presentationLoaded.isFlow {
                presentationLoaded.display()
            } else {
                Purchasely.showController(navCtrl, type: .productPage)
            }
            
        }
    }

    private func clientPresentationDisplayed(arguments: [String: Any]?) {
        guard let presentationMap = arguments?["presentation"] as? [String: Any] else {
            print("Presentation cannot be nil")
            return
        }

        guard let presentationId = presentationMap["id"] as? String,
                let placementId = presentationMap["placementId"] as? String,
                let presentationLoaded = SwiftPurchaselyFlutterPlugin.presentationsLoaded.filter({ $0.id == presentationId && $0.placementId == placementId }).first else { return }

        Purchasely.clientPresentationOpened(with: presentationLoaded)
    }

    private func clientPresentationClosed(arguments: [String: Any]?) {
        guard let presentationMap = arguments?["presentation"] as? [String: Any] else {
            print("Presentation cannot be nil")
            return
        }

        guard let presentationId = presentationMap["id"] as? String,
              let placementId = presentationMap["placementId"] as? String,
              let presentationLoaded = SwiftPurchaselyFlutterPlugin.presentationsLoaded.filter({ $0.id == presentationId && $0.placementId == placementId }).first else { return }

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

    private func synchronize(_ result: @escaping FlutterResult) {
        DispatchQueue.main.async {
            Purchasely.synchronize {
                //result(true)
            } failure: { error in
                //result(FlutterError.error(code: "-1", message: "Synchronization failed", error: error))
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

    private func userLogout(result: @escaping FlutterResult) {
        Purchasely.userLogout()
        result(true)
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

    private func userSubscriptionsHistory(_ result: @escaping FlutterResult) {

        DispatchQueue.main.async {
            Purchasely.userSubscriptionsHistory { subscriptions in
                result((subscriptions ?? []).compactMap { $0.toMap })
            } failure: { error in
                result(FlutterError.error(code:"-1", message:"failed to fetch user subscriptions history", error: error))
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
        let processingLegaLBasisArg = arguments["processingLegalBasis"] as? String
        let processingLegalBasis: PLYDataProcessingLegalBasis = processingLegaLBasisArg == "ESSENTIAL" ? .essential : .optional

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
                case .openPlacement:
                    actionString = nil
                case .webCheckout:
                    actionString = "web_checkout"
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
    
    private func setDynamicOffering(arguments: [String: Any]?, result: @escaping FlutterResult) {
        guard let arguments = arguments,
              let reference = arguments["reference"] as? String,
              let planVendorId = arguments["planVendorId"] as? String else {
            result(FlutterError.error(code: "-1", message: "reference and planVendorId must not be nil", error: nil))
            return
        }
        
        let offerVendorId = arguments["offerVendorId"] as? String

        DispatchQueue.main.async {
            Purchasely.setDynamicOffering(reference: reference, planVendorId: planVendorId, offerVendorId: offerVendorId, completion: { success in
                result(success)
            })
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
                    case "THIRD_PARTY_ANALYTICS": .thirdPartyIntegrations
                    default: nil
                }
            })
        }
        Purchasely.revokeDataProcessingConsent(for: purposes)
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
        Purchasely.removeEventDelegate()
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

// WARNING: This enum must be strictly identical to the one in the Flutter side (purchasely_flutter.PLYAttribute).
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
}
