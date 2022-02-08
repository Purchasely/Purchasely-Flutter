package io.purchasely.purchasely_flutter

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.util.Log
import androidx.core.view.WindowCompat
import androidx.fragment.app.Fragment
import androidx.fragment.app.FragmentActivity
import io.purchasely.ext.PLYProductViewResult
import io.purchasely.ext.ProductViewResultListener
import io.purchasely.ext.Purchasely
import io.purchasely.models.PLYPlan
import java.lang.ref.WeakReference

class PLYProductActivity : FragmentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_ply_product_activity)

        if(intent.extras?.getBoolean("isFullScreen") == true) {
            WindowCompat.setDecorFitsSystemWindows(window, false)
        }

        val presentationId = intent.extras?.getString("presentationId")
        val placementId = intent.extras?.getString("placementId")
        val productId = intent.extras?.getString("productId")
        val planId = intent.extras?.getString("planId")
        val contentId = intent.extras?.getString("contentId")

        val fragment = when {
            placementId?.isNotBlank() == true -> Purchasely.presentationFragmentForPlacement(
                placementId,
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

        PurchaselyFlutterPlugin.productActivity = PurchaselyFlutterPlugin.ProductActivity(
            presentationId = presentationId,
            productId = productId,
            planId = planId,
            contentId = contentId
        ).apply {
            activity = WeakReference(this@PLYProductActivity)
        }
    }

    override fun onDestroy() {
        PurchaselyFlutterPlugin.productActivity?.activity = null
        super.onDestroy()
    }

    private val callback: (PLYProductViewResult, PLYPlan?) -> Unit = { result, plan ->
        PurchaselyFlutterPlugin.sendPresentationResult(result, plan)
    }

    companion object {
        fun newIntent(activity: Activity) = Intent(activity, PLYProductActivity::class.java)
    }

}