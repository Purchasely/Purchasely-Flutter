package io.purchasely.purchasely_flutter

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.view.View
import android.widget.FrameLayout
import androidx.core.view.WindowCompat
import androidx.fragment.app.FragmentActivity
import io.purchasely.ext.PLYPresentation
import io.purchasely.ext.PLYPresentationViewProperties
import io.purchasely.ext.PLYProductViewResult
import io.purchasely.ext.Purchasely
import io.purchasely.models.PLYError
import io.purchasely.models.PLYPlan
import java.lang.ref.WeakReference

class PLYPaywallActivity : FragmentActivity() {

  private var presentationId: String? = null
  private var placementId: String? = null
  private var productId: String? = null
  private var planId: String? = null
  private var contentId: String? = null
  private var isFullScreen: Boolean = false

  private var paywallView: View? = null

  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)

    setContentView(R.layout.activity_ply_paywall_activity)

    moveTaskToBack(false)

    presentationId = intent.extras?.getString("presentationId")
    placementId = intent.extras?.getString("placementId")
    productId = intent.extras?.getString("productId")
    planId = intent.extras?.getString("planId")
    contentId = intent.extras?.getString("contentId")

    Purchasely.fetchPresentation(
      this,
      PLYPresentationViewProperties(
        presentationId = presentationId,
        placementId = placementId,
        contentId = contentId
      ),
      { result: PLYProductViewResult, plan: PLYPlan? ->
        PurchaselyFlutterPlugin.sendPresentationResult(result, plan)
        supportFinishAfterTransition()
      }
    ) { presentation: PLYPresentation?, error: PLYError? ->
      PurchaselyFlutterPlugin.sendFetchResult(presentation, error)

      if(presentation?.view != null) {
        presentationId = presentation.id
        placementId = presentation.placementId

        paywallView = presentation.view
        findViewById<FrameLayout>(R.id.container).addView(paywallView)
      } else {
        finish()
      }
    }

  }

  fun updateDisplay(isFullScreen: Boolean) {
    this.isFullScreen = isFullScreen
    if(isFullScreen) WindowCompat.setDecorFitsSystemWindows(window, false)
  }

  override fun onStart() {
    super.onStart()

    PurchaselyFlutterPlugin.productActivity = PurchaselyFlutterPlugin.ProductActivity(
      presentationId = presentationId,
      placementId = placementId,
      productId = productId,
      planId = planId,
      contentId = contentId,
      isFullScreen = isFullScreen
    ).apply {
      activity = WeakReference(this@PLYPaywallActivity)
    }
  }

  override fun onDestroy() {
    if(PurchaselyFlutterPlugin.productActivity?.activity?.get() == this) {
      PurchaselyFlutterPlugin.productActivity?.activity = null
    }
    PurchaselyFlutterPlugin.presentationsLoaded.removeAll { it.id == presentationId }
    super.onDestroy()
  }

  companion object {
    fun newIntent(activity: Activity?,
                  properties: PLYPresentationViewProperties) = Intent(activity, PLYPaywallActivity::class.java).apply {
      //remove old activity if still referenced to avoid issues
      val oldActivity = PurchaselyFlutterPlugin.productActivity?.activity?.get()
      oldActivity?.finish()
      PurchaselyFlutterPlugin.productActivity?.activity = null
      PurchaselyFlutterPlugin.productActivity = null
      //flags = Intent.FLAG_ACTIVITY_NEW_TASK xor Intent.FLAG_ACTIVITY_MULTIPLE_TASK

      putExtra("presentationId", properties.presentationId)
      putExtra("contentId", properties.contentId)
      putExtra("placementId", properties.placementId)
      putExtra("productId", properties.productId)
      putExtra("planId", properties.planId)
    }
  }

}
