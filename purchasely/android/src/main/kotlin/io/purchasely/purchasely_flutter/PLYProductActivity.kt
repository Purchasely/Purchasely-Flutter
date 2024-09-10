package io.purchasely.purchasely_flutter

import android.app.Activity
import android.content.Intent
import android.graphics.Color
import android.os.Bundle
import android.view.View
import android.widget.FrameLayout
import androidx.core.view.WindowCompat
import androidx.fragment.app.FragmentActivity
import io.purchasely.ext.PLYPresentation
import io.purchasely.ext.PLYPresentationProperties
import io.purchasely.ext.PLYProductViewResult
import io.purchasely.ext.Purchasely
import io.purchasely.models.PLYPlan
import io.purchasely.views.parseColor
import java.lang.ref.WeakReference

class PLYProductActivity : FragmentActivity() {

    private var presentationId: String? = null
    private var placementId: String? = null
    private var productId: String? = null
    private var planId: String? = null
    private var contentId: String? = null

    private var presentation: PLYPresentation? = null

    private var isFullScreen: Boolean = false
    private var backgroundColor: String? = null

    private var paywallView: View? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        isFullScreen = intent.extras?.getBoolean("isFullScreen") ?: false
        backgroundColor = intent.extras?.getString("background_color")

        if(isFullScreen) {
            WindowCompat.setDecorFitsSystemWindows(window, false)
            hideSystemUI()
        }

        setContentView(R.layout.activity_ply_product_activity)

        try {
            val loadingBackgroundColor = backgroundColor.parseColor(Color.WHITE)
            findViewById<View>(R.id.container).setBackgroundColor(loadingBackgroundColor)
        } catch (e: Exception) {
            //do nothing
        }

        presentationId = intent.extras?.getString("presentationId")
        placementId = intent.extras?.getString("placementId")
        productId = intent.extras?.getString("productId")
        planId = intent.extras?.getString("planId")
        contentId = intent.extras?.getString("contentId")

        presentation = intent.extras?.getParcelable("presentation")

        paywallView = if(presentation != null) {
            presentation?.buildView(this, PLYPresentationProperties(
                onClose = {
                    supportFinishAfterTransition()
                }
            ), callback)
        } else {
            Purchasely.presentationView(
                context = this@PLYProductActivity,
                properties = PLYPresentationProperties(
                    placementId = placementId,
                    contentId = contentId,
                    presentationId = presentationId,
                    planId = planId,
                    productId = productId,
                    onLoaded = { isLoaded ->
                        if(!isLoaded) return@PLYPresentationProperties

                        val backgroundPaywall = paywallView?.findViewById<FrameLayout>(io.purchasely.R.id.content)?.background
                        if(backgroundPaywall != null) {
                            findViewById<View>(R.id.container).background = backgroundPaywall
                        }
                    }
                ),
                callback = callback
            )
        }

        if(paywallView == null) {
            finish()
            return
        }


        findViewById<FrameLayout>(R.id.container).addView(paywallView)
    }

    private fun hideSystemUI() {
        actionBar?.hide()
        window.decorView.systemUiVisibility = (
                View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                        or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                        or View.SYSTEM_UI_FLAG_FULLSCREEN
                )

    }

    override fun onStart() {
        super.onStart()

        PurchaselyFlutterPlugin.productActivity = PurchaselyFlutterPlugin.ProductActivity(
            presentation = presentation,
            presentationId = presentationId,
            placementId = placementId,
            productId = productId,
            planId = planId,
            contentId = contentId,
            isFullScreen = isFullScreen,
            loadingBackgroundColor = backgroundColor
        ).apply {
            activity = WeakReference(this@PLYProductActivity)
        }
    }

    override fun onDestroy() {
        if(PurchaselyFlutterPlugin.productActivity?.activity?.get() == this) {
            PurchaselyFlutterPlugin.productActivity?.activity = null
        }
        super.onDestroy()
    }

    private val callback: (PLYProductViewResult, PLYPlan?) -> Unit = { result, plan ->
        PurchaselyFlutterPlugin.sendPresentationResult(result, plan)
        supportFinishAfterTransition()
    }

    companion object {
        fun newIntent(activity: Activity) = Intent(activity, PLYProductActivity::class.java)
    }

}