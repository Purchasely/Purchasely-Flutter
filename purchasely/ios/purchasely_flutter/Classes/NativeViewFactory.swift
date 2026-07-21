import Foundation
import Flutter
import UIKit
import Purchasely

class NativeViewFactory: NSObject, FlutterPlatformViewFactory {
    private var messenger: FlutterBinaryMessenger

    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        super.init()
    }

    func create(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> FlutterPlatformView {
        // The inline view surfaces its outcome through the plugin's shared
        // `purchasely-presentation-events` sink (see NativeView), not a dedicated
        // MethodChannel, so no per-view channel is needed.
        return NativeView(
            frame: frame,
            viewIdentifier: viewId,
            arguments: args)
    }

    /// Implementing this method is only necessary when the `arguments` in `createWithFrame` is not `nil`.
    public func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
          return FlutterStandardMessageCodec.sharedInstance()
    }
}
