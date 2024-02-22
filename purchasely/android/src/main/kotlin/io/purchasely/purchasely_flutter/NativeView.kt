package io.purchasely.purchasely_flutter

import android.content.Context
import android.util.Log
import android.view.View
import android.widget.FrameLayout
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView
import io.purchasely.ext.PLYPresentation
import io.purchasely.ext.PLYPresentationType
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
        val presentation = creationParams?.get("presentation") as? Map<String, Any>


        if (presentation != null) {
            Log.d("Purchasely", "PLYPresentation found.")
            val plyPresentation = PLYPresentation(
                id = presentation.get("id") as? String,
                placementId = presentation.get("placementId") as? String,
                audienceId = presentation.get("audienceId") as? String,
                abTestId = presentation.get("abTestId") as? String,
                abTestVariantId = presentation.get("abTestVariantId") as? String,
                language = presentation.get("language") as? String,
                plans = parsePLYPresentationPlans(presentation.get("plans") as? List<Map<String, Any>>), //Plan are not sent from Flutter for now
                type = PLYPresentationType.valueOf(
                    presentation.get("type") as? String ?: PLYPresentationType.NORMAL.name
                ),
            )

            // Build the presentation view
            val presentationView = plyPresentation.buildView(
                context = context,
                viewProperties = PLYPresentationViewProperties(
                    onClose = { closeCallback() }
                ),
            )
            Log.d("Purchasely", "Presentation built successfully.")
            layout.addView(presentationView)
        } else {
            Log.e("Purchasely", "PLYPresentation not found: using presentationId=$presentationId and placementId=$placementId.")
            val presentationView = Purchasely.presentationView(
                context = context,
                callback = null,
                properties = PLYPresentationViewProperties(
                    presentationId = presentationId,
                    placementId = placementId,
                    onClose = { closeCallback() }
                ),
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