import Foundation
import Flutter
import UIKit
import Purchasely


class NativeView: NSObject, FlutterPlatformView {
    private var _containerView: NativeContainerView
    private var _controller: UIViewController?

    init(
        frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?,
        channel: FlutterMethodChannel
    ) {
        _containerView = NativeContainerView(frame: frame)
        super.init()
        Purchasely.setEventDelegate(self)
        self._controller = SwiftPurchaselyFlutterPlugin.getPresentationController(for: args, with: channel)

        if let controller = _controller {
            let childView = controller.view!
            childView.frame = _containerView.bounds
            childView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            _containerView.addSubview(childView)

            // Attach the controller to the nearest parent VC for proper lifecycle
            if let rootVC = NativeView.findRootViewController() {
                rootVC.addChild(controller)
                controller.didMove(toParent: rootVC)
            }
        }

        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(orientationDidChange),
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )
    }

    @objc private func orientationDidChange() {
        guard let controller = _controller else { return }
        // Give Flutter time to resize the UiKitView, then force the controller to re-layout
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            let newSize = self._containerView.bounds.size
            controller.view.frame = self._containerView.bounds
            controller.viewWillTransition(to: newSize, with: NoAnimationTransitionCoordinator(containerView: self._containerView))
            controller.view.setNeedsLayout()
            controller.view.layoutIfNeeded()
            // Also force all subviews deep in the hierarchy to relayout
            self.forceLayoutRecursive(controller.view)
        }
    }

    private func forceLayoutRecursive(_ view: UIView) {
        for subview in view.subviews {
            subview.setNeedsLayout()
            subview.layoutIfNeeded()
            forceLayoutRecursive(subview)
        }
    }

    func view() -> UIView {
        return _containerView
    }

    /// Locates the host view controller, preferring the active scene's key window
    /// (iOS 13+ multi-scene apps) and falling back to the app delegate's window.
    private static func findRootViewController() -> UIViewController? {
        if let windowScene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
           let rootVC = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController {
            return rootVC
        }
        return UIApplication.shared.delegate?.window??.rootViewController
    }

    private func cleanupController() {
        guard let controller = _controller else { return }
        if controller.parent != nil {
            controller.willMove(toParent: nil)
            controller.removeFromParent()
        }
        if controller.view.superview != nil {
            controller.view.removeFromSuperview()
        }
        _controller = nil
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
        cleanupController()
    }
}

/// Container view that forces child layout on bounds changes (e.g. rotation).
private class NativeContainerView: UIView {
    override func layoutSubviews() {
        super.layoutSubviews()
        for child in subviews {
            if child.frame != bounds {
                child.frame = bounds
                child.setNeedsLayout()
                child.layoutIfNeeded()
            }
        }
    }
}

/// Minimal transition coordinator to pass to viewWillTransition(to:with:).
/// Holds a stable container view per `UIViewControllerTransitionCoordinatorContext`'s contract.
private class NoAnimationTransitionCoordinator: NSObject, UIViewControllerTransitionCoordinator {
    private let _containerView: UIView

    init(containerView: UIView) {
        self._containerView = containerView
        super.init()
    }

    var isAnimated: Bool { false }
    var presentationStyle: UIModalPresentationStyle { .none }
    var initiallyInteractive: Bool { false }
    var isInterruptible: Bool { false }
    var isInteractive: Bool { false }
    var isCancelled: Bool { false }
    var transitionDuration: TimeInterval { 0 }
    var percentComplete: CGFloat { 1.0 }
    var completionVelocity: CGFloat { 0 }
    var completionCurve: UIView.AnimationCurve { .linear }
    var targetTransform: CGAffineTransform { .identity }
    var containerView: UIView { _containerView }

    func viewController(forKey key: UITransitionContextViewControllerKey) -> UIViewController? { nil }
    func view(forKey key: UITransitionContextViewKey) -> UIView? { nil }

    func animate(
        alongsideTransition animation: ((any UIViewControllerTransitionCoordinatorContext) -> Void)?,
        completion: ((any UIViewControllerTransitionCoordinatorContext) -> Void)? = nil
    ) -> Bool {
        animation?(self)
        completion?(self)
        return true
    }

    func animateAlongsideTransition(
        in view: UIView?,
        animation: ((any UIViewControllerTransitionCoordinatorContext) -> Void)?,
        completion: ((any UIViewControllerTransitionCoordinatorContext) -> Void)? = nil
    ) -> Bool {
        animation?(self)
        completion?(self)
        return true
    }

    func notifyWhenInteractionEnds(_ handler: @escaping (any UIViewControllerTransitionCoordinatorContext) -> Void) {
        handler(self)
    }

    func notifyWhenInteractionChanges(_ handler: @escaping (any UIViewControllerTransitionCoordinatorContext) -> Void) {
        handler(self)
    }
}

extension NativeView: PLYEventDelegate {
    func eventTriggered(_ event: PLYEvent, properties: [String : Any]?) {
        if event == .presentationClosed {
            DispatchQueue.main.async { [weak self] in
                self?.cleanupController()
            }
        }
    }
}
