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

        val productId = intent.extras?.getString("productId") ?: let {
            supportFinishAfterTransition()
            return
        }
        val presentationId = intent.extras?.getString("presentationId")

        val fragment: Fragment = Purchasely.productFragment(
                productId,
                presentationId,
                object: ProductViewResultListener {
                    override fun onResult(result: PLYProductViewResult, plan: PLYPlan?) {
                        PurchaselyPlugin.sendPresentationResult(result, plan)
                    }
                })

        supportFragmentManager
                .beginTransaction()
                .replace(R.id.fragmentContainer, fragment)
                .commit()
    }

}