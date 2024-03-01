package io.purchasely.purchasely_flutter

import android.content.Context
import android.util.Log
import android.view.View
import android.widget.FrameLayout
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView
import io.purchasely.ext.PLYPresentationViewProperties
import io.purchasely.ext.Purchasely
import io.purchasely.models.PLYPresentationPlan
import android.view.ViewGroup

internal class NativeView(
    context: Context,
    id: Int,
    creationParams: Map<String?, Any?>?,
    private val methodChannel: MethodChannel
) : PlatformView {

    private val layout: FrameLayout

    override fun getView(): View = layout

    override fun dispose() {}

    init {
        layout = FrameLayout(context)
        val presentationId = creationParams?.get("presentationId") as? String
        val placementId = creationParams?.get("placementId") as? String
        val presentationMap = creationParams?.get("presentation") as? Map<String, Any>
        val presentation = PurchaselyFlutterPlugin.presentationsLoaded.lastOrNull {
            it.id == presentationMap?.get("id") as? String
                    && it.placementId == presentationMap?.get(
                "placementId"
            ) as? String
        }

        if (presentation != null) {
            Log.d("Purchasely", "PLYPresentation found: ${presentation}")

            // Build the presentation view
            val presentationView = presentation.buildView(
                context = context,
                viewProperties = PLYPresentationViewProperties(
                    onClose = { closeCallback() }
                ),
                callback = { result, plan ->
                    methodChannel.invokeMethod(
                        "onPresentationResult", mapOf(
                            "result" to result.ordinal,
                            "plan" to plan?.toMap(),
                        )
                    )
                }
            )
            Log.d("Purchasely", "Presentation built successfully.")
            layout.addView(presentationView)
        } else {
            Log.e("Purchasely", "PLYPresentation not found: using presentationId=$presentationId and placementId=$placementId.")
            val presentationView = Purchasely.presentationView(
                context = context,
                properties = PLYPresentationViewProperties(
                    presentationId = presentationId,
                    placementId = placementId,
                    onClose = { closeCallback() }
                ),
                callback = { result, plan ->
                    methodChannel.invokeMethod(
                        "onPresentationResult", mapOf(
                            "result" to result.ordinal,
                            "plan" to plan?.toMap(),
                        )
                    )
                }
            )
            Log.e("Purchasely", "Presentation built successfully.")

            layout.addView(presentationView)
        }
    }

    private fun closeCallback() {
        (layout as ViewGroup).removeAllViews()
    }

    companion object {
        fun parsePLYPresentationPlans(plans: List<Map<String, Any>>?): List<PLYPresentationPlan> {
            val parsedPlans = mutableListOf<PLYPresentationPlan>()

            plans?.forEach { planMap ->
                val planVendorId = planMap["planVendorId"] as? String
                val storeProductId = planMap["storeProductId"] as? String
                val basePlanId = planMap["basePlanId"] as? String
                val offerId = planMap["offerId"] as? String

                val presentationPlan = PLYPresentationPlan(
                    planVendorId = planVendorId,
                    storeProductId = storeProductId,
                    basePlanId = basePlanId,
                    offerId = offerId
                )

                parsedPlans.add(presentationPlan)
            }

            return parsedPlans
        }
    }
}