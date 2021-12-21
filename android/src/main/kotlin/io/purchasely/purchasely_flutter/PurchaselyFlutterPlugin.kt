package io.purchasely.purchasely_flutter

import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.annotation.NonNull
import androidx.fragment.app.FragmentActivity

import io.purchasely.billing.Store
import io.purchasely.ext.*
import io.purchasely.models.PLYPlan
import io.purchasely.models.PLYProduct
import kotlinx.coroutines.*
import io.purchasely.ext.Purchasely
import java.lang.ref.WeakReference

/** PurchaselyFlutterPlugin */
class PurchaselyFlutterPlugin: FlutterPlugin, MethodCallHandler, ActivityAware, CoroutineScope {
  /// The MethodChannel that will the communication between Flutter and native Android
  ///
  /// This local reference serves to register the plugin with the Flutter Engine and unregister it
  /// when the Flutter Engine is detached from the Activity
  private lateinit var eventChannel: EventChannel
  private lateinit var purchaseChannel: EventChannel

  private lateinit var context: Context
  private var activity: Activity? = null

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
    job.cancel()
  }

  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
      channel = MethodChannel(flutterPluginBinding.binaryMessenger, "purchasely")
      channel.setMethodCallHandler(this)
      context = flutterPluginBinding.applicationContext

      eventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "purchasely-events")
      purchaseChannel = EventChannel(flutterPluginBinding.binaryMessenger, "purchasely-purchases")

      eventChannel.setStreamHandler(object: EventChannel.StreamHandler {
          override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
              Purchasely.eventListener = object: EventListener {
                  override fun onEvent(event: PLYEvent) {
                      val properties = event.properties.toMap() ?: emptyMap()
                      Handler(Looper.getMainLooper()).post {
                          events?.success(mapOf(Pair("name", event.name), Pair("properties", properties)))
                      }
                  }
              }
          }

          override fun onCancel(arguments: Any?) {
              Purchasely.eventListener = null
          }

      })

      purchaseChannel.setStreamHandler(object: EventChannel.StreamHandler {
          override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
              Purchasely.purchaseListener =
                  object: PurchaseListener {
                      override fun onPurchaseStateChanged(state: State) {
                          if (state is State.PurchaseComplete || state is State.RestorationComplete) {
                              Handler(Looper.getMainLooper()).post {
                                  events?.success(null)
                              }
                          }
                      }
                  }
          }

          override fun onCancel(arguments: Any?) {
              Purchasely.purchaseListener = null
          }

      })
  }

  override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
      when(call.method) {
          "startWithApiKey" -> {
              startWithApiKey(call.argument<String>("apiKey"), call.argument<List<String>>("stores"),
                        call.argument<String>("userId"), call.argument<Int>("logLevel"),
                        call.argument<Int>("runningMode"), result)
          }
          "close" -> {
              close()
              result.success(true)
          }
          "setDefaultPresentationResultHandler" -> setDefaultPresentationResultHandler(result)
          "synchronize" -> synchronize()
          "presentPresentationWithIdentifier" -> {
              presentPresentationWithIdentifier(
                      call.argument<String>("presentationVendorId"),
                      call.argument<String>("contentId")
              )
              presentationResult = result
          }
          "presentProductWithIdentifier" -> {
              val productId = call.argument<String>("productVendorId") ?: let {
                  result.error("-1", "product vendor id must not be null", null)
                  return
              }
              presentProductWithIdentifier(
                      productId,
                      call.argument<String>("presentationVendorId"),
                      call.argument<String>("contentId")
              )
              presentationResult = result
          }
          "presentPlanWithIdentifier" -> {
              val planId = call.argument<String>("planVendorId") ?: let {
                  result.error("-1", "plan vendor id must not be null", null)
                  return
              }
              presentPlanWithIdentifier(
                      planId,
                      call.argument<String>("presentationVendorId"),
                      call.argument<String>("contentId")
              )
              presentationResult = result
          }
          "restoreAllProducts" -> restoreAllProducts(result)
          "getAnonymousUserId" -> result.success(getAnonymousUserId())
          "userLogin" -> {
              val userId = call.argument<String>("userId") ?: let {
                  result.error("-1", "user id must not be null", null)
                  return
              }
              userLogin(userId, result)
          }
          "userLogout" -> userLogout()
          "setLogLevel" -> {
              setLogLevel(call.argument<Int>("logLevel"))
              result.success(true)
          }
          "isReadyToPurchase" -> {
              isReadyToPurchase(call.argument<Boolean>("readyToPurchase"))
              result.success(true)
          }
          "productWithIdentifier" -> {
              launch {
                  try {
                      val product = productWithIdentifier(call.argument<String>("vendorId"))
                      if(product != null) {
                          val plans = HashMap<String?, Any>()
                          product.plans.map {
                              plans.put(it.name, transformPlanToMap(it))
                          }
                          result.success(product.toMap().toMutableMap().apply {
                              this["plans"] = plans
                          })
                      } else {
                          result.error("-1", "product ${call.argument<String>("vendorId")} not found", null)
                      }
                  } catch (e: Exception) {
                      result.error("-1", e.message, e)
                  }
              }
          }
          "planWithIdentifier" -> {
              launch {
                  try {
                      val plan = planWithIdentifier(call.argument<String>("vendorId"))
                      if(plan != null) {
                          result.success(transformPlanToMap(plan))
                      } else {
                          result.error("-1", "plan ${call.argument<String>("vendorId")} not found", null)
                      }
                  } catch (e: Exception) {
                      result.error("-1", e.message, e)
                  }
              }
          }
          "allProducts" -> launch { allProducts(result) }
          "purchaseWithPlanVendorId" -> purchaseWithPlanVendorId(
              call.argument<String>("vendorId"),
              call.argument<String>("contentId"),
              result)
          "displaySubscriptionCancellationInstruction" -> displaySubscriptionCancellationInstruction()
          "handle" -> handle(call.argument<String>("deeplink"), result)
          "userSubscriptions" -> launch { userSubscriptions(result) }
          "presentSubscriptions" -> presentSubscriptions()
          "setAttribute" -> setAttribute(call.argument<Int>("attribute"), call.argument<String>("value"))
          "setPaywallActionInterceptor" -> setPaywallActionInterceptor(result)
          "onProcessAction" -> onProcessAction(call.argument<Boolean>("processAction") ?: false)
          "closePaywall" -> closePaywall()
          else -> {
              result.notImplemented()
          }
      }
  }

  private fun transformPlanToMap(plan: PLYPlan?): Map<String, Any?> {
      if(plan == null) return emptyMap()

      return plan.toMap().toMutableMap().apply {
          this["type"] = when(plan.type) {
              DistributionType.RENEWING_SUBSCRIPTION -> DistributionType.RENEWING_SUBSCRIPTION.ordinal
              DistributionType.NON_RENEWING_SUBSCRIPTION -> DistributionType.NON_RENEWING_SUBSCRIPTION.ordinal
              DistributionType.CONSUMABLE -> DistributionType.CONSUMABLE.ordinal
              DistributionType.NON_CONSUMABLE -> DistributionType.NON_CONSUMABLE.ordinal
              DistributionType.UNKNOWN -> DistributionType.UNKNOWN.ordinal
              else -> null
          }
      }
  }

  //region Purchasely
  private fun startWithApiKey(
      apiKey: String?, stores: List<String>?,
      userId: String?, logLevel: Int?,
      runningMode: Int?, result: Result) {
      if(apiKey == null) throw IllegalArgumentException("Api key must not be null")

      Purchasely.Builder(context)
            .apiKey(apiKey)
            .stores(getStoresInstances(stores))
            .logLevel(LogLevel.values()[logLevel ?: 0])
              .runningMode(when(runningMode) {
                  0 -> PLYRunningMode.TransactionOnly
                  1 -> PLYRunningMode.Observer
                  2 -> PLYRunningMode.PaywallOnly
                  3 -> PLYRunningMode.PaywallObserver
                  else -> PLYRunningMode.Full
              })
            .userId(userId)
            .build()

      Purchasely.appTechnology = PLYAppTechnology.FLUTTER

      Purchasely.start { isConfigured, error ->
          if(isConfigured) {
              result.success(true)
          } else {
              result.error("0", error?.message ?: "Purchasely SDK not configured", error)
          }
      }
  }

  private fun close() {
      Purchasely.close()
  }

  private fun presentPresentationWithIdentifier(presentationVendorId: String?,
                                                contentId: String?) {

      val intent = Intent(context, PLYProductActivity::class.java)
      intent.putExtra("presentationId", presentationVendorId)
      intent.putExtra("contentId", contentId)
      activity?.startActivity(intent)
  }

  private fun presentProductWithIdentifier(productVendorId: String,
                                            presentationVendorId: String?,
                                            contentId: String?) {
      val intent = Intent(context, PLYProductActivity::class.java)
      intent.putExtra("presentationId", presentationVendorId)
      intent.putExtra("productId", productVendorId)
      intent.putExtra("contentId", contentId)
      activity?.startActivity(intent)
  }

  private fun presentPlanWithIdentifier(planVendorId: String,
                                        presentationVendorId: String?,
                                        contentId: String?) {
      val intent = Intent(context, PLYProductActivity::class.java)
      intent.putExtra("presentationId", presentationVendorId)
      intent.putExtra("planId", planVendorId)
      intent.putExtra("contentId", contentId)
      activity?.startActivity(intent)
  }

  private fun restoreAllProducts(result: Result) {
      Purchasely.restoreAllProducts(
          success = { plan ->
              result.success(true)
          }, error = { error ->
              error?.let {
                  result.error("-1", it.message, it)
              } ?: let {
                  result.error("-1", "Unknown error", null)
              }
          }
      )
  }

  private fun purchaseWithPlanVendorId(planVendorId: String?,
                                        contentId: String?,
                                        result: Result) {
      launch {
          try {
              val plan = Purchasely.plan(planVendorId ?: "")
              if(plan != null && activity != null) {
                  Purchasely.purchase(activity!!, plan, contentId,
                      success = {
                          result.success(it?.toMap())
                      }, error = { error ->
                          error?.let {
                              result.error("-1", it.message, it)
                          } ?: let {
                              result.error("-1", "Unknown error", null)
                          }
                      }
                  )
              } else {
                  result.error("-1","plan $planVendorId not found", null)
              }
          } catch (e: Exception) {
              result.error("-1", e.message, e)
          }
      }
  }

  private fun getAnonymousUserId() : String {
      return Purchasely.anonymousUserId
  }

  private fun userLogin(userId: String, result: Result) {
      Purchasely.userLogin(userId) { refresh -> result.success(refresh) }
  }

  private fun userLogout() {
      Purchasely.userLogout()
  }

  private fun setLogLevel(logLevel: Int?) {
      Purchasely.logLevel = LogLevel.values()[logLevel ?: 0]
  }

  private fun isReadyToPurchase(readyToPurchase: Boolean?) {
      Purchasely.isReadyToPurchase = readyToPurchase ?: true
  }

  private fun setDefaultPresentationResultHandler(result: Result) {
      defaultPresentationResult = result
      Purchasely.setDefaultPresentationResultHandler { result2, plan ->
          sendPresentationResult(result2, plan)
      }
  }

  private fun synchronize() {
      Purchasely.synchronize()
  }

  private suspend fun productWithIdentifier(vendorId: String?) : PLYProduct? {
      return Purchasely.product(vendorId ?: "")
  }

  private suspend fun planWithIdentifier(vendorId: String?) : PLYPlan? {
      return Purchasely.plan(vendorId ?: "")
  }

  private suspend fun allProducts(result: Result) {
      try {
          val products = Purchasely.allProducts()
          val list = arrayListOf<Map<String, Any?>>()
          for (product in products) {
              list.add(product.toMap())
          }
          result.success(list)
      } catch (e: Exception) {
          result.error("-1", e.message, e)
      }
  }

  private fun handle(deeplink: String?, result: Result) {
      if (deeplink == null) {
          result.error("-1", "Deeplink must not be null", null)
          return
      }
      val uri = Uri.parse(deeplink)
      result.success(Purchasely.handle(uri))
  }

  private fun displaySubscriptionCancellationInstruction() {
      val flutterActivity = activity
      if(flutterActivity is FragmentActivity) {
          Purchasely.displaySubscriptionCancellationInstruction(flutterActivity, 0)
      }
  }

  private suspend fun userSubscriptions(result: Result) {
      try {
          val subscriptions = Purchasely.userSubscriptions()
          val list = ArrayList<MutableMap<String, Any?>>()
          for (data in subscriptions) {
              val map = data.data.toMap().toMutableMap().apply {
                  this["subscriptionSource"] = when(data.data.storeType) {
                      StoreType.GOOGLE_PLAY_STORE -> StoreType.GOOGLE_PLAY_STORE.ordinal
                      StoreType.HUAWEI_APP_GALLERY -> StoreType.HUAWEI_APP_GALLERY.ordinal
                      StoreType.AMAZON_APP_STORE -> StoreType.AMAZON_APP_STORE.ordinal
                      StoreType.APPLE_APP_STORE -> StoreType.APPLE_APP_STORE.ordinal
                      else -> null
                  }

                  this["plan"] = transformPlanToMap(data.plan)

                  val plans = HashMap<String?, Any>()
                  data.product.plans.map {
                      plans.put(it.name, transformPlanToMap(it))
                  }
                  this["product"] = data.product.toMap().toMutableMap().apply {
                      this["plans"] = plans
                  }
              }
              list.add(map)
              //list[data.data.id] = map
          }
          result.success(list)
      } catch (e: Exception) {
          result.error("-1", e.message, e)
      }
  }

  private fun presentSubscriptions() {
      val intent = Intent(context, PLYSubscriptionsActivity::class.java)
      activity?.startActivity(intent)
  }

  private fun setAttribute(attribute: Int?, value: String?) {
      value?.let { Purchasely.setAttribute(Attribute.values()[attribute ?: 0], it) }
  }

    private fun setPaywallActionInterceptor(result: Result) {
        Purchasely.setPaywallActionsInterceptor { activity, action, parameters, processAction ->
            paywallActionHandler = processAction

            val parametersForReact = parameters
                .mapKeys { it.key.toString().lowercase() }
                .mapValues {
                    val value = it.value
                    if(value is PLYPlan) {
                        transformPlanToMap(value)
                    } else {
                        value.toString()
                    }
                }

            result.success(mapOf(
                Pair("action", action.value),
                Pair("parameters", parametersForReact)
            ))
        }
    }

    private fun onProcessAction(processAction: Boolean) {
        launch {
            if(productActivity?.relaunch(activity) == false) {
                //wait for activity to relaunch
                withContext(Dispatchers.Default) { delay(500) }
            }
            productActivity?.activity?.get()?.runOnUiThread {
                paywallActionHandler?.invoke(processAction)
            }
        }
    }

    private fun closePaywall() {
        activity?.let {
            it.startActivity(Intent(productActivity?.activity?.get() ?: it, it::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
            })
        }
    }

  //endregion

  companion object {
      var productActivity: ProductActivity? = null
      var presentationResult: Result? = null
      var defaultPresentationResult: Result? = null
      var paywallActionHandler: PLYCompletionHandler? = null
      private lateinit var channel : MethodChannel

      fun sendPresentationResult(result: PLYProductViewResult, plan: PLYPlan?) {
          val productViewResult = when(result) {
              PLYProductViewResult.PURCHASED -> PLYProductViewResult.PURCHASED.ordinal
              PLYProductViewResult.CANCELLED -> PLYProductViewResult.CANCELLED.ordinal
              PLYProductViewResult.RESTORED -> PLYProductViewResult.RESTORED.ordinal
          }

          if(presentationResult != null) {
              presentationResult?.success(
                  mapOf(Pair("result", productViewResult), Pair("plan", plan?.toMap() ?: emptyMap()))
              )
              presentationResult = null
          } else if(defaultPresentationResult != null) {
              defaultPresentationResult?.success(
                  mapOf(Pair("result", productViewResult), Pair("plan", plan?.toMap() ?: emptyMap()))
              )
          }

      }
  }

  private fun getStoresInstances(stores: List<String>?): ArrayList<Store> {
      val result = ArrayList<Store>()
      if (stores?.contains("Google") == true
              && Package.getPackage("io.purchasely.google") != null) {
          try {
              result.add(Class.forName("io.purchasely.google.GoogleStore").newInstance() as Store)
          } catch (e: Exception) {
              Log.e("Purchasely", "Google Store not found :" + e.message, e)
          }
      }
      if (stores?.contains("Huawei") == true
              && Package.getPackage("io.purchasely.huawei") != null) {
          try {
              result.add(Class.forName("io.purchasely.huawei.HuaweiStore").newInstance() as Store)
          } catch (e: Exception) {
              Log.e("Purchasely", e.message, e)
          }
      }
      return result
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
      activity = binding.activity
  }

  override fun onDetachedFromActivityForConfigChanges() {
      activity = null
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
      activity = binding.activity
  }

  override fun onDetachedFromActivity() {
      activity = null
  }

  private val job = SupervisorJob()
  override val coroutineContext = job + Dispatchers.Main

  class ProductActivity(
      val presentationId: String? = null,
      val productId: String? = null,
      val planId: String? = null,
      val contentId: String? = null) {

      var activity: WeakReference<PLYProductActivity>? = null

      fun relaunch(flutterActivity: Activity?) : Boolean {
          if(flutterActivity == null) return false

          val backgroundActivity = activity?.get()
          return if(backgroundActivity != null
              && !backgroundActivity.isFinishing) {
              flutterActivity.startActivity(
                  Intent(flutterActivity, backgroundActivity::class.java).apply {
                      flags = Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
                  }
              )
              true
          } else {
              val intent = PLYProductActivity.newIntent(flutterActivity)
              intent.putExtra("presentationId", presentationId)
              intent.putExtra("productId", productId)
              intent.putExtra("planId", planId)
              intent.putExtra("contentId", contentId)
              flutterActivity.startActivity(intent)
              return false
          }
      }
  }
}
