import Foundation
import Flutter
import UIKit
import Purchasely


class NativeView: NSObject, FlutterPlatformView {
    private var _containerView: NativeContainerView
    private var _controller: UIViewController?
    private let _requestId: String?
    // Guards against double-emitting onDismissed (the loaded presentation's
    // onDismissed callback and the `.presentationClosed` event can both fire).
    private var _didEmitDismissed = false

    init(
        frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?
    ) {
        _containerView = NativeContainerView(frame: frame)
        _requestId = (args as? [String: Any])?["requestId"] as? String
        super.init()

        // Fallback: if the loaded presentation's `onDismissed` callback (set
        // below) doesn't fire for the embedded controller, synthesise the
        // dismissal from the `.presentationClosed` SDK event instead. Uses the
        // closure-based `setEventCallback` API — the same one
        // `SwiftEventHandler` prefers over the ObjC delegate API
        // (`setEventDelegate`/`PLYEventDelegate`), which the SDK's own comment
        // there flags as less reliable in v6 RC+ (FLT-W-12). `setEventCallback`
        // is a single global slot with no "add" variant, so this is reset to a
        // no-op on `deinit` for a clean handoff instead of leaving a stale
        // closure referencing a deallocated view.
        Purchasely.setEventCallback { [weak self] event, _ in
            guard event == .presentationClosed else { return }
            self?.handlePresentationClosed()
        }

        // The inline native view is built from a Presentation that was already
        // loaded (via `preload`) and is keyed by the Dart requestId.
        // Creation-param contract: `{ "requestId": <String> }`.
        self._controller = SwiftPurchaselyFlutterPlugin.presentationController(for: args)

        // Surface the embedded outcome through the SAME presentation-events sink
        // and envelope shape as the full-screen path, keyed by the request's
        // `requestId`, so the Dart `onDismissed` callback (and the pending
        // `display()` future) fire for the inline path too.
        if let requestId = _requestId,
           let presentation = SwiftPurchaselyFlutterPlugin.loadedPresentations[requestId] {
            presentation.onDismissed = { [weak self] outcome in
                self?.emitDismissed(requestId: requestId, outcome: outcome)
            }
        }

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

    /// Emits the `onDismissed` envelope once, mirroring the full-screen path,
    /// and clears the request's static state so a re-display re-registers.
    private func emitDismissed(requestId: String, outcome: PLYPresentationOutcome) {
        guard !_didEmitDismissed else { return }
        _didEmitDismissed = true
        let presentation = SwiftPurchaselyFlutterPlugin.loadedPresentations[requestId]
        SwiftPurchaselyFlutterPlugin.emitPresentationEvent([
            "event": "onDismissed",
            "requestId": requestId,
            "outcome": SwiftPurchaselyFlutterPlugin.outcomeMap(
                outcome, presentation: presentation, error: nil, requestId: requestId
            ) as Any?,
        ])
        SwiftPurchaselyFlutterPlugin.loadedPresentations.removeValue(forKey: requestId)
        SwiftPurchaselyFlutterPlugin.requests.removeValue(forKey: requestId)
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

    /// Fallback handler for the `.presentationClosed` SDK event — see the
    /// `setEventCallback` registration in `init`. Idempotent via
    /// `_didEmitDismissed`, mirroring the previous `PLYEventDelegate`-based
    /// implementation.
    private func handlePresentationClosed() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if let requestId = self._requestId, !self._didEmitDismissed {
                self.emitDismissed(requestId: requestId, outcome: PLYPresentationOutcome())
            }
            self.cleanupController()
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
        // Clean unregistration (FLT-W-12): release the closure's `self`
        // capture instead of leaving a stale callback referencing a
        // deallocated view. `setEventCallback` has no "remove" counterpart —
        // overwriting with a no-op is the cleanest handoff the API allows.
        Purchasely.setEventCallback { _, _ in }
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
