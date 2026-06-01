package io.purchasely.purchasely_flutter

import android.os.Bundle
import androidx.fragment.app.FragmentActivity
import io.purchasely.ext.Purchasely

class PLYSubscriptionsActivity : FragmentActivity() {

  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    setContentView(R.layout.activity_ply_subscriptions_activity)

    val fragment = Purchasely.subscriptionsFragment() ?: let {
      supportFinishAfterTransition()
      return
    }

    supportFragmentManager
      .beginTransaction()
      .addToBackStack(null)
      .replace(R.id.container, fragment, "SubscriptionsFragment")
      .commitAllowingStateLoss()

    supportFragmentManager.addOnBackStackChangedListener {
      if(supportFragmentManager.backStackEntryCount == 0) {
        supportFinishAfterTransition()
      }
    }
  }

}
