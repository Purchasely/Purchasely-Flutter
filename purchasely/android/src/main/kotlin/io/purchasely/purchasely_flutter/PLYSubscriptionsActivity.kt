package io.purchasely.purchasely_flutter

import android.os.Bundle
import android.util.Log
import androidx.fragment.app.FragmentActivity

class PLYSubscriptionsActivity : FragmentActivity() {

  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    setContentView(R.layout.activity_ply_subscriptions_activity)

    // The v6 Purchasely SDK no longer exposes a built-in subscriptions screen
    // (`Purchasely.subscriptionsFragment()` was removed). Nothing to host, so
    // finish gracefully until a v6 subscriptions surface is wired.
    Log.w("Purchasely", "Subscriptions screen is not available in the v6 SDK")
    supportFinishAfterTransition()
  }

}
