package io.purchasely.purchasely_flutter

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import androidx.core.view.WindowCompat
import androidx.fragment.app.FragmentActivity
import io.purchasely.ext.PLYProductViewResult
import io.purchasely.ext.Purchasely
import io.purchasely.models.PLYPlan
import java.lang.ref.WeakReference

class PLYProductActivity : FragmentActivity() {

    private var presentationId: String? = null
    private var placementId: String? = null
    private var productId: String? = null
    private var planId: String? = null
    private var contentId: String? = null
    private var isFullScreen: Boolean = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_ply_product_activity)

        isFullScreen = intent.extras?.getBoolean("isFullScreen") ?: false

        if(isFullScreen) {
            WindowCompat.setDecorFitsSystemWindows(window, false)
        }

        presentationId = intent.extras?.getString("presentationId")
        placementId = intent.extras?.getString("placementId")
        productId = intent.extras?.getString("productId")
        planId = intent.extras?.getString("planId")
        contentId = intent.extras?.getString("contentId")

        val fragment = when {
            placementId?.isNotBlank() == true -> Purchasely.presentationFragmentForPlacement(
                placementId!!,
                contentId,
                null,
                callback)
            planId.isNullOrEmpty().not() -> Purchasely.planFragment(
                    planId,
                    presentationId,
                    contentId,
                null,
                    callback)
            productId.isNullOrEmpty().not() -> Purchasely.productFragment(
                    productId,
                    presentationId,
                    contentId,
                null,
                    callback)
            else -> Purchasely.presentationFragment(
                    presentationId,
                    contentId,
                null,
                    callback)
        }

        if(fragment == null) {
            supportFinishAfterTransition()
            return
        }

        supportFragmentManager
                .beginTransaction()
                .replace(R.id.fragmentContainer, fragment)
                .commit()
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
    }

    companion object {
        fun newIntent(activity: Activity) = Intent(activity, PLYProductActivity::class.java)
    }

}