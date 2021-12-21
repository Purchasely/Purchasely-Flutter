package io.purchasely.purchasely_flutter

import android.os.Bundle
import androidx.appcompat.app.AppCompatActivity
import androidx.fragment.app.FragmentActivity
import io.purchasely.ext.Purchasely
import io.purchasely.views.subscriptions.PLYSubscriptionsFragment

class PLYSubscriptionsActivity : AppCompatActivity() {

  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    setContentView(R.layout.activity_ply_product_activity)

    val fragment = Purchasely.subscriptionsFragment() ?: let {
      supportFinishAfterTransition()
      return
    }

    supportFragmentManager
      .beginTransaction()
      .addToBackStack(null)
      .replace(R.id.fragmentContainer, fragment, "SubscriptionsFragment")
      .commitAllowingStateLoss()

    supportFragmentManager.addOnBackStackChangedListener {
      if(supportFragmentManager.backStackEntryCount == 0) {
        supportFinishAfterTransition()
      }
    }
  }

}
