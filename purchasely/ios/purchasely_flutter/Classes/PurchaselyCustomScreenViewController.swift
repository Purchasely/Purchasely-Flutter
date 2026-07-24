import Flutter
import Purchasely
import UIKit

/// Owns one secondary Flutter engine and its flow-step-scoped bridge.
final class PurchaselyCustomScreenViewController: FlutterViewController {
    private let customScreenEngine: FlutterEngine
    private let customScreenId: String
    private var customScreenChannel: FlutterMethodChannel?
    private var cleanedUp = false

    init(engine: FlutterEngine, customScreenId: String) {
        self.customScreenEngine = engine
        self.customScreenId = customScreenId
        super.init(engine: engine, nibName: nil, bundle: nil)
        let channel = FlutterMethodChannel(
            name: "purchasely-custom-screen",
            binaryMessenger: engine.binaryMessenger
        )
        self.customScreenChannel = channel
        channel.setMethodCallHandler { [weak self] call, result in
            self?.handle(call, result: result)
        }
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func willMove(toParent parent: UIViewController?) {
        if parent == nil && self.parent != nil {
            // Detach the bridge promptly, but keep the engine alive until the
            // VC is fully off-screen (deinit) so the exit transition doesn't
            // message an already-destroyed engine or blank the final frame.
            detachBridge()
        }
        super.willMove(toParent: parent)
    }

    deinit {
        detachBridge()
        customScreenEngine.destroyContext()
    }

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any]
        guard args?["customScreenId"] as? String == customScreenId else {
            result(FlutterError(
                code: "STALE_CUSTOM_SCREEN",
                message: "Custom Screen id does not match this engine",
                details: nil
            ))
            return
        }

        switch call.method {
        case "getCustomScreenPresentation":
            result(SwiftPurchaselyFlutterPlugin.customScreenPresentationMap(customScreenId))
        case "customScreenExecuteConnection":
            let connectionId = args?["connectionId"] as? String
            DispatchQueue.main.async { [customScreenId] in
                guard let presentation = SwiftPurchaselyFlutterPlugin.customScreenPresentation(customScreenId) else {
                    return
                }
                SwiftPurchaselyFlutterPlugin.executeConnection(
                    on: presentation,
                    connectionId: connectionId
                )
            }
            result(true)
        case "customScreenBack":
            DispatchQueue.main.async { [customScreenId] in
                SwiftPurchaselyFlutterPlugin.customScreenPresentation(customScreenId)?.back()
            }
            result(true)
        case "customScreenClose":
            DispatchQueue.main.async { [customScreenId] in
                SwiftPurchaselyFlutterPlugin.customScreenPresentation(customScreenId)?.close()
            }
            result(true)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func detachBridge() {
        guard !cleanedUp else { return }
        cleanedUp = true
        customScreenChannel?.setMethodCallHandler(nil)
        customScreenChannel = nil
        SwiftPurchaselyFlutterPlugin.removeCustomScreenPresentation(customScreenId)
    }
}
