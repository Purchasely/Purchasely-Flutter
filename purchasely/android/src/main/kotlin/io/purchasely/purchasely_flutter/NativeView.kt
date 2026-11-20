package io.purchasely.purchasely_flutter

import android.content.Context
import android.util.Log
import android.view.View
import android.widget.FrameLayout
import io.flutter.plugin.platform.PlatformView
import io.purchasely.ext.presentation.PLYPresentationBase
import io.purchasely.ext.presentation.PLYPresentationOutcome
import io.purchasely.ext.presentation.PLYPresentationState

internal class NativeView(
    context: Context,
    id: Int,
    creationParams: Map<String?, Any?>?,
) : PlatformView {

    private val layout: FrameLayout
    private var pendingAttach: View.OnAttachStateChangeListener? = null
    private var onDispose: (() -> Unit)? = null

    override fun getView(): View = layout

    override fun dispose() {
        pendingAttach?.let { layout.removeOnAttachStateChangeListener(it) }
        pendingAttach = null
        layout.removeAllViews()
        onDispose?.invoke()
    }

    init {
        layout = FrameLayout(context)

        // The inline native view is built from a Presentation that was already
        // loaded (via `preload`) and is keyed by the Dart requestId.
        val requestId = creationParams?.get("requestId") as? String
        val presentation = requestId?.let { PurchaselyFlutterPlugin.loadedPresentations[it] }

        if (requestId != null && presentation != null) {
            Log.d("Purchasely", "Loaded Presentation found for requestId=$requestId")
            buildWhenAttached(context, requestId, presentation)
        } else {
            Log.e("Purchasely", "Loaded Presentation not found for requestId=$requestId; nothing to display inline.")
        }
    }

    /**
     * The SDK view takes its outcome callback from a global request when it attaches, and the
     * next `buildView` replaces that request. Hybrid Composition creates the platform views of a
     * frame before it attaches them, so a view built in `init` can get the callback of another one.
     */
    private fun buildWhenAttached(context: Context, requestId: String, presentation: PLYPresentationBase.Loaded) {
        if (!layout.isAttachedToWindow) {
            val listener = object : View.OnAttachStateChangeListener {
                override fun onViewAttachedToWindow(v: View) {
                    layout.removeOnAttachStateChangeListener(this)
                    pendingAttach = null
                    buildWhenAttached(context, requestId, presentation)
                }
                override fun onViewDetachedFromWindow(v: View) {}
            }
            pendingAttach = listener
            layout.addOnAttachStateChangeListener(listener)
            return
        }

        var dismissed = false
        var hasInlineView = false
        fun dismiss(outcome: PLYPresentationOutcome) {
            if (dismissed) return
            // Surface the embedded outcome through the SAME presentation-events
            // sink and envelope shape as the full-screen path, keyed by the
            // request's `requestId`, so the Dart `onDismissed` callback (and the
            // pending `display()` future) fire for the inline path too.
            dismissed = true
            if (hasInlineView) {
                PurchaselyFlutterPlugin.loadedPresentations.remove(requestId)
                PurchaselyFlutterPlugin.displayCallbacks.remove(requestId)
            }
            PurchaselyFlutterPlugin.emitPresentationEvent(
                PurchaselyFlutterPlugin.eventEnvelope("onDismissed", requestId).apply {
                    put("outcome", PurchaselyFlutterPlugin.outcomeToMap(outcome))
                }
            )
        }
        // A non-embeddable presentation reports its error synchronously and returns null.
        // It can still be exposed by the caller, so only an actual view consumes the handle.
        val presentationView = presentation.buildView(context) { dismiss(it) } ?: return
        hasInlineView = true
        // The SDK skips the buildView callback when the view tree lifecycle owner is already
        // destroyed (a FlutterFragment host; a FlutterActivity has no owner, so the callback
        // still comes), but it still ends the session: send the dismissal from that state.
        onDispose = {
            val state = presentation.state.value
            if (state is PLYPresentationState.Dismissed) dismiss(state.outcome)
        }
        Log.d("Purchasely", "Presentation built successfully.")
        layout.addView(presentationView)

        // The native SDK fires no `onPresented` for an embedded view —
        // synthesise it once the view is mounted so the Dart-side
        // request/presentation `onPresented` callback fires for the inline
        // path too (parity with the full-screen path).
        PurchaselyFlutterPlugin.emitPresentationEvent(
            PurchaselyFlutterPlugin.eventEnvelope("onPresented", requestId).apply {
                put("presentation", PurchaselyFlutterPlugin.presentationToMap(presentation))
            }
        )
    }
}
