package com.flutterpurchasely

import android.app.Activity
import android.content.Intent
import android.os.Bundle
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

        val presentationId = intent.extras?.getString("presentationId")
        val productId = intent.extras?.getString("productId")
        val planId = intent.extras?.getString("planId")
        val contentId = intent.extras?.getString("contentId")

        val fragment = when {
            planId.isNullOrEmpty().not() -> Purchasely.planFragment(
                    planId,
                    presentationId,
                    contentId,
                    callback)
            productId.isNullOrEmpty().not() -> Purchasely.productFragment(
                    productId,
                    presentationId,
                    contentId,
                    callback)
            else -> Purchasely.presentationFragment(
                    presentationId,
                    contentId,
                    callback)
        }

        supportFragmentManager
                .beginTransaction()
                .replace(R.id.fragmentContainer, fragment)
                .commit()

        PurchaselyPlugin.productActivity = PurchaselyPlugin.ProductActivity(
            presentationId = presentationId,
            productId = productId,
            planId = planId,
            contentId = contentId
        ).apply {
            activity = WeakReference(this@PLYProductActivity)
        }
    }

    override fun onDestroy() {
        PurchaselyPlugin.productActivity?.activity = null
        super.onDestroy()
    }

    private val callback: (PLYProductViewResult, PLYPlan?) -> Unit = { result, plan ->
        PurchaselyPlugin.sendPresentationResult(result, plan)
    }

    companion object {
        fun newIntent(activity: Activity) = Intent(activity, PLYProductActivity::class.java)
    }

}