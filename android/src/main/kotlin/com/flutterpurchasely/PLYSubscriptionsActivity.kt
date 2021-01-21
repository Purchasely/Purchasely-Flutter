package com.flutterpurchasely

import android.os.Bundle
import androidx.fragment.app.FragmentActivity
import io.purchasely.views.subscriptions.PLYSubscriptionsFragment

class PLYSubscriptionsActivity : FragmentActivity() {

  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    setContentView(R.layout.activity_ply_product_activity)

    supportFragmentManager
      .beginTransaction()
      .replace(R.id.fragmentContainer, PLYSubscriptionsFragment())
      .commit()
  }

}
