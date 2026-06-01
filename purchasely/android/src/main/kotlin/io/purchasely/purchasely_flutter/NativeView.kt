package io.purchasely.purchasely_flutter

import android.content.Context
import android.util.Log
import android.view.View
import android.widget.FrameLayout
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView
import io.purchasely.ext.presentation.PLYPresentationOutcome

internal class NativeView(
    context: Context,
    id: Int,
    creationParams: Map<String?, Any?>?,
    private val methodChannel: MethodChannel
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

        if (presentation != null) {
            Log.d("Purchasely", "Loaded Presentation found for requestId=$requestId")

            val presentationView = presentation.buildView(context) { outcome ->
                methodChannel.invokeMethod("onPresentationResult", outcomeToMap(outcome))
            }
            Log.d("Purchasely", "Presentation built successfully.")
            layout.addView(presentationView)
        } else {
            Log.e("Purchasely", "Loaded Presentation not found for requestId=$requestId; nothing to display inline.")
        }
    }

    private fun outcomeToMap(outcome: PLYPresentationOutcome): Map<String, Any?> {
        return mapOf(
            "purchaseResult" to outcome.purchaseResult?.name?.lowercase(),
            "plan" to outcome.plan?.let { plan ->
                mapOf(
                    "vendorId" to plan.vendorId,
                    "productId" to plan.getProductId(),
                    "basePlanId" to plan.basePlanId,
                )
            },
            "closeReason" to outcome.closeReason?.value,
        )
    }
}
