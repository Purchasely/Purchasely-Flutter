import Flutter
import Purchasely
import UIKit

/// Supplies a Flutter view controller for CLIENT steps inside native flows.
final class PurchaselyCustomScreenDelegate: NSObject, PLYCustomScreenViewControllerDelegate {
    private static let engineGroup = FlutterEngineGroup(
        name: "io.purchasely.custom-screens",
        project: nil
    )

    func viewController(for presentation: PLYPresentation) -> UIViewController? {
        let customScreenId = SwiftPurchaselyFlutterPlugin.registerCustomScreenPresentation(presentation)
        let options = FlutterEngineGroupOptions()
        options.entrypoint = SwiftPurchaselyFlutterPlugin.customScreenEntrypoint
        options.libraryURI = SwiftPurchaselyFlutterPlugin.customScreenLibraryURI
        options.entrypointArgs = [customScreenId]
        let engine = Self.engineGroup.makeEngine(with: options)
        return PurchaselyCustomScreenViewController(
            engine: engine,
            customScreenId: customScreenId
        )
    }
}
