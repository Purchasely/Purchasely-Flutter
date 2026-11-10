package io.purchasely.purchasely_flutter

import android.content.Context
import android.util.Log
import android.view.View
import android.widget.FrameLayout
import io.flutter.plugin.platform.PlatformView
import io.purchasely.ext.presentation.PLYPresentationOutcome
import io.purchasely.ext.presentation.PLYPresentationState

internal class NativeView(
    context: Context,
    id: Int,
    creationParams: Map<String?, Any?>?,
) : PlatformView {

    private val layout: FrameLayout
    private var onDispose: (() -> Unit)? = null

    override fun getView(): View = layout

    override fun dispose() {
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

            var dismissed = false
            fun dismiss(outcome: PLYPresentationOutcome) {
                if (dismissed) return
                // Surface the embedded outcome through the SAME presentation-events
                // sink and envelope shape as the full-screen path, keyed by the
                // request's `requestId`, so the Dart `onDismissed` callback (and the
                // pending `display()` future) fire for the inline path too.
                // Only the loaded handle and display callback are dropped: the
                // prepared request stays registered so a re-display of the same
                // Dart handle keeps its original source (same policy as the
                // full-screen path).
                dismissed = true
                PurchaselyFlutterPlugin.loadedPresentations.remove(requestId)
                PurchaselyFlutterPlugin.displayCallbacks.remove(requestId)
                PurchaselyFlutterPlugin.emitPresentationEvent(
                    PurchaselyFlutterPlugin.eventEnvelope("onDismissed", requestId).apply {
                        put("outcome", PurchaselyFlutterPlugin.outcomeToMap(outcome))
                    }
                )
            }
            val presentationView = presentation.buildView(context) { dismiss(it) }
            // The SDK skips the buildView callback when the host lifecycle is already destroyed,
            // but it still ends the session: send the dismissal from that state.
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
        } else {
            Log.e("Purchasely", "Loaded Presentation not found for requestId=$requestId; nothing to display inline.")
        }
    }
}
