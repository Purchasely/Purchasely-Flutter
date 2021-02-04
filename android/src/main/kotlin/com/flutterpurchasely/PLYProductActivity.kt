package com.flutterpurchasely

import android.os.Bundle
import androidx.fragment.app.Fragment
import androidx.fragment.app.FragmentActivity
import io.purchasely.ext.PLYProductViewResult
import io.purchasely.ext.ProductViewResultListener
import io.purchasely.ext.Purchasely
import io.purchasely.models.PLYPlan

class PLYProductActivity : FragmentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_ply_product_activity)

        val presentationId = intent.extras?.getString("presentationId")
        val productId = intent.extras?.getString("productId")
        val planId = intent.extras?.getString("planId")

        val fragment = when {
            planId.isNullOrEmpty().not() -> Purchasely.planFragment(
                    planId,
                    presentationId,
                    callback)
            productId.isNullOrEmpty().not() -> Purchasely.productFragment(
                    productId,
                    presentationId,
                    callback)
            else -> Purchasely.presentationFragment(
                    presentationId,
                    callback)
        }

        supportFragmentManager
                .beginTransaction()
                .replace(R.id.fragmentContainer, fragment)
                .commit()
    }

    private val callback: (PLYProductViewResult, PLYPlan?) -> Unit = { result, plan ->
        PurchaselyPlugin.sendPresentationResult(result, plan)
    }

}