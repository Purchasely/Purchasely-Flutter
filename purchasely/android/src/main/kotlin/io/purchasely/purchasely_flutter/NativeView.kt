package io.purchasely.purchasely_flutter

import android.content.Context
import android.util.Log
import android.view.View
import android.widget.FrameLayout
import io.flutter.plugin.platform.PlatformView

internal class NativeView(
    context: Context,
    id: Int,
    creationParams: Map<String?, Any?>?,
) : PlatformView {

    private val layout: FrameLayout

    override fun getView(): View = layout

    override fun dispose() {
        layout.removeAllViews()
    }

    init {
        layout = FrameLayout(context)

        // The inline native view is built from a Presentation that was already
        // loaded (via `preload`) and is keyed by the Dart requestId.
        val requestId = creationParams?.get("requestId") as? String
        val presentation = requestId?.let { PurchaselyFlutterPlugin.loadedPresentations[it] }

        if (requestId != null && presentation != null) {
            Log.d("Purchasely", "Loaded Presentation found for requestId=$requestId")

            val presentationView = presentation.buildView(context) { outcome ->
                // Surface the embedded outcome through the SAME presentation-events
                // sink and envelope shape as the full-screen path, keyed by the
                // request's `requestId`, so the Dart `onDismissed` callback (and the
                // pending `display()` future) fire for the inline path too.
                PurchaselyFlutterPlugin.loadedPresentations.remove(requestId)
                PurchaselyFlutterPlugin.preparedRequests.remove(requestId)
                PurchaselyFlutterPlugin.displayCallbacks.remove(requestId)
                PurchaselyFlutterPlugin.emitPresentationEvent(
                    PurchaselyFlutterPlugin.eventEnvelope("onDismissed", requestId).apply {
                        put("outcome", PurchaselyFlutterPlugin.outcomeToMap(outcome))
                    }
                )
            }
            Log.d("Purchasely", "Presentation built successfully.")
            layout.addView(presentationView)
        } else {
            Log.e("Purchasely", "Loaded Presentation not found for requestId=$requestId; nothing to display inline.")
        }
    }
}
