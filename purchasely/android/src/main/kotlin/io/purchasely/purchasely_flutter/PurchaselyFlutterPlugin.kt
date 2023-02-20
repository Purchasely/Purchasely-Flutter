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
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.annotation.NonNull
import androidx.fragment.app.FragmentActivity

import io.purchasely.billing.Store
import io.purchasely.ext.*
import io.purchasely.ext.EventListener
import io.purchasely.models.PLYPlan
import io.purchasely.models.PLYProduct
import kotlinx.coroutines.*
import io.purchasely.ext.Purchasely
import java.lang.ref.WeakReference
import java.text.SimpleDateFormat
import java.util.*
import kotlin.collections.ArrayList
import kotlin.collections.HashMap

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
                        call.argument<Int>("runningMode"),
                        result)
          }
          "close" -> {
              close()
              result.success(true)
          }
          "setDefaultPresentationResultHandler" -> setDefaultPresentationResultHandler(result)
          "synchronize" -> synchronize()
          "fetchPresentation" -> fetchPresentation(
                  call.argument<String>("placementVendorId"),
                  call.argument<String>("presentationVendorId"),
                  call.argument<String>("contentId"),
                result)
          "presentPresentation" -> presentPresentation(
              call.argument<Map<String, Any>>("presentation"),
              call.argument<Boolean>("isFullscreen") ?: false,
              result)
          "presentPresentationWithIdentifier" -> {
              presentPresentationWithIdentifier(
                      call.argument<String>("presentationVendorId"),
                      call.argument<String>("contentId"),
                      call.argument<Boolean>("isFullscreen")
              )
              presentationResult = result
          }
          "presentPresentationForPlacement" -> {
              presentPresentationForPlacement(
                  call.argument<String>("placementVendorId"),
                  call.argument<String>("contentId"),
                  call.argument<Boolean>("isFullscreen")
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
                      call.argument<String>("contentId"),
                      call.argument<Boolean>("isFullscreen")
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
                      call.argument<String>("contentId"),
                      call.argument<Boolean>("isFullscreen")
              )
              presentationResult = result
          }
          "restoreAllProducts" -> restoreAllProducts(result)
          "silentRestoreAllProducts" -> restoreAllProducts(result)
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
          "setLanguage" -> {
              setLanguage(call.argument<String>("language"))
              result.success(true)
          }
          "userDidConsumeSubscriptionContent" -> {
              Purchasely.userDidConsumeSubscriptionContent()
              result.success(true)
          }
          "clientPresentationDisplayed" -> clientPresentationDisplayed(call.argument<Map<String, Any>>("presentation"))
          "clientPresentationClosed" -> clientPresentationClosed(call.argument<Map<String, Any>>("presentation"))
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
          "setUserAttributeWithString" -> {
              val key = call.argument<String>("key") ?: return
              val value = call.argument<String>("value") ?: return
              setUserAttributeWithString(key, value)
          }
          "setUserAttributeWithInt" -> {
              val key = call.argument<String>("key") ?: return
              val value = call.argument<Int>("value") ?: return
              setUserAttributeWithInt(key, value)
          }
          "setUserAttributeWithDouble" -> {
              val key = call.argument<String>("key") ?: return
              val value = call.argument<Double>("value") ?: return
              setUserAttributeWithDouble(key, value)
          }
          "setUserAttributeWithBoolean" -> {
              val key = call.argument<String>("key") ?: return
              val value = call.argument<Boolean>("value") ?: return
              setUserAttributeWithBoolean(key, value)
          }
          "setUserAttributeWithDate" -> {
              val key = call.argument<String>("key") ?: return
              val value = call.argument<String>("value") ?: return
              setUserAttributeWithDate(key, value)
          }
          "userAttribute" -> {
              val key = call.argument<String>("key") ?: return
              userAttribute(key, result)
          }
          "userAttributes" -> userAttributes(result)
          "clearUserAttribute" -> {
              val key = call.argument<String>("key") ?: return
              clearUserAttribute(key)
          }
          "clearUserAttributes" -> clearUserAttributes()
          "setPaywallActionInterceptor" -> setPaywallActionInterceptor(result)
          "onProcessAction" -> onProcessAction(call.argument<Boolean>("processAction") ?: false)
          "closePaywall" -> closePaywall(call.argument<Boolean>("definitively") ?: false)
          else -> {
              result.notImplemented()
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
                  2 -> PLYRunningMode.PaywallObserver
                  else -> PLYRunningMode.Full
              })
            .userId(userId)
            .build()

	  Purchasely.sdkBridgeVersion = "1.6.1"
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

    private fun fetchPresentation(placementId: String?,
                          presentationId: String?,
                          contentId: String?,
                          result: Result) {

        fetchResult = result

        val properties = PLYPresentationViewProperties(
            placementId = placementId,
            presentationId = presentationId,
            contentId = contentId)

        activity?.let {
            val intent = PLYPaywallActivity.newIntent(it, properties).apply {
                flags = Intent.FLAG_ACTIVITY_MULTIPLE_TASK or Intent.FLAG_ACTIVITY_NEW_TASK
            }
            it.startActivity(intent)
        }

    }

    private fun presentPresentation(presentationMap: Map<String, Any>?,
                                    isFullScreen: Boolean,
                                    result: Result) {
        if (presentationMap == null) {
            result.error("-1", "presentation cannot be null", null)
            return
        }

        if(presentationsLoaded.lastOrNull()?.id != presentationMap["id"]) {
            result.error("-1", "presentation cannot be fetched", null)
            return
        }

        presentationResult = result

        val activity = productActivity?.activity?.get()
        if(activity is PLYPaywallActivity) {
            activity.runOnUiThread {
                activity.updateDisplay(isFullScreen)
            }
        }

        activity?.let {
            it.startActivity(
                Intent(it, PLYPaywallActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
                }
            )
        }



    }

  private fun presentPresentationWithIdentifier(presentationVendorId: String?,
                                                contentId: String?,
                                                isFullscreen: Boolean?) {
      val intent = Intent(context, PLYProductActivity::class.java)
      intent.putExtra("presentationId", presentationVendorId)
      intent.putExtra("contentId", contentId)
      intent.putExtra("isFullScreen", isFullscreen ?: false)
      activity?.startActivity(intent)
  }

    private fun presentPresentationForPlacement(placementVendorId: String?,
                                                contentId: String?,
                                                isFullscreen: Boolean?) {
        val intent = Intent(context, PLYProductActivity::class.java)
        intent.putExtra("placementId", placementVendorId)
        intent.putExtra("contentId", contentId)
        intent.putExtra("isFullScreen", isFullscreen ?: false)
        activity?.startActivity(intent)
    }

  private fun presentProductWithIdentifier(productVendorId: String,
                                            presentationVendorId: String?,
                                            contentId: String?,
                                            isFullscreen: Boolean?) {
      val intent = Intent(context, PLYProductActivity::class.java)
      intent.putExtra("presentationId", presentationVendorId)
      intent.putExtra("productId", productVendorId)
      intent.putExtra("contentId", contentId)
      intent.putExtra("isFullScreen", isFullscreen ?: false)
      activity?.startActivity(intent)
  }

  private fun presentPlanWithIdentifier(planVendorId: String,
                                        presentationVendorId: String?,
                                        contentId: String?,
                                        isFullscreen: Boolean?) {
      val intent = Intent(context, PLYProductActivity::class.java)
      intent.putExtra("presentationId", presentationVendorId)
      intent.putExtra("planId", planVendorId)
      intent.putExtra("contentId", contentId)
      intent.putExtra("isFullScreen", isFullscreen ?: false)
      activity?.startActivity(intent)
  }

  private fun restoreAllProducts(result: Result) {
      Purchasely.restoreAllProducts(
          success = { plan ->
              result.success(true)
              Purchasely.restoreAllProducts(null)
          }, error = { error ->
              error?.let {
                  result.error("-1", it.message, it)
              } ?: let {
                  result.error("-1", "Unknown error", null)
              }
              Purchasely.restoreAllProducts(null)
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
              list.add(product.toMap().toMutableMap().apply {
                  val plans: MutableMap<String?, Any> = HashMap()
                  product.plans.forEach { plan ->
                      plans[plan.name] = transformPlanToMap(plan)
                  }
                  this["plans"] = plans
              })
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
                  remove("subscription_status") //TODO add in a future version after checking with iOS
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
      value?.let {
          Purchasely.setAttribute(
              when(attribute) {
                  0 -> Attribute.AMPLITUDE_SESSION_ID
                  1 -> Attribute.AMPLITUDE_USER_ID
                  2 -> Attribute.AMPLITUDE_DEVICE_ID
                  3 -> Attribute.FIREBASE_APP_INSTANCE_ID
                  4 -> Attribute.AIRSHIP_CHANNEL_ID
                  5 -> Attribute.BATCH_INSTALLATION_ID
                  6 -> Attribute.ADJUST_ID
                  7 -> Attribute.APPSFLYER_ID
                  8 -> Attribute.ONESIGNAL_PLAYER_ID
                  9 -> Attribute.MIXPANEL_DISTINCT_ID
                  10 -> Attribute.CLEVER_TAP_ID
                  11 -> Attribute.SENDINBLUE_USER_EMAIL
                  12 -> Attribute.ITERABLE_USER_EMAIL
                  13 -> Attribute.AT_INTERNET_ID_CLIENT
                  14 -> Attribute.MPARTICLE_USER_ID
                  15 -> Attribute.BRANCH_USER_DEVELOPER_IDENTITY
                  16 -> Attribute.CUSTOMERIO_USER_EMAIL
                  17 -> Attribute.CUSTOMERIO_USER_ID
                  // TODO 18 -> Attribute.moengageUniqueId
                  else -> Attribute.AMPLITUDE_SESSION_ID
              },
              it
          )
      }
  }

    fun setUserAttributeWithString(key: String, value: String) {
        Purchasely.setUserAttribute(key, value)
    }

    fun setUserAttributeWithInt(key: String, value: Int) {
        Purchasely.setUserAttribute(key, value)
    }

    fun setUserAttributeWithDouble(key: String, value: Double) {
        Purchasely.setUserAttribute(key, value.toFloat())
    }

    fun setUserAttributeWithBoolean(key: String, value: Boolean) {
        Purchasely.setUserAttribute(key, value)
    }

    fun setUserAttributeWithDate(key: String, value: String) {
        Log.d("Attribute", value)
        val format = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSSX", Locale.getDefault())
        } else {
            SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.getDefault())
        }
        format.timeZone = TimeZone.getTimeZone("GMT")
        val calendar = Calendar.getInstance()
        try {
            format.parse(value)?.let {
                calendar.time = it
            }
            Log.d("Attribute", calendar.time.toString())
            Purchasely.setUserAttribute(key, calendar.time)
        } catch (e: Exception) {
            Log.e("Purchasely", "Cannot save date attribute $key", e)
        }
    }

    fun userAttribute(key: String, result: Result) {
        val value = getUserAttributeValueForFlutter(Purchasely.userAttribute(key))
        result.success(value)
    }

    fun userAttributes(result: Result) {
        val map = Purchasely.userAttributes()
        result.success(
            map.mapValues {
                getUserAttributeValueForFlutter(it.value)
            }
        )
    }

    private fun getUserAttributeValueForFlutter(value: Any?): Any? {
        return when (value) {
            is Date -> {
                val format = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSSX", Locale.getDefault())
                } else {
                    SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.getDefault())
                }
                format.timeZone = TimeZone.getTimeZone("GMT")
                try {
                    format.format(value)
                } catch (e: Exception) {
                    ""
                }
            }
            //awful but to keep same precision so 1.2f = 1.2 double and not 1.20000056
            is Float -> value.toString().toDouble()
            else -> value
        }
    }

    fun clearUserAttribute(key: String) {
        Purchasely.clearUserAttribute(key)
    }

    fun clearUserAttributes() {
        Purchasely.clearUserAttributes()
    }

    fun setLanguage(language: String?) {
        Purchasely.language = try {
            if(language != null) Locale(language) else Locale.getDefault()
        } catch (e: Exception) {
            Locale.getDefault()
        }
    }

    private fun clientPresentationDisplayed(presentationMap: Map<String, Any>?) {
        if(presentationMap == null) {
            PLYLogger.e("presentation cannot be null")
            return
        }

        val presentation = presentationsLoaded.firstOrNull { it.id ==  presentationMap["id"]}

        if(presentation != null) {
            Purchasely.clientPresentationDisplayed(presentation)
        }
    }

    private fun clientPresentationClosed(presentationMap: Map<String, Any>?) {
        if(presentationMap == null) {
            PLYLogger.e("presentation cannot be null")
            return
        }

        val presentation = presentationsLoaded.firstOrNull { it.id ==  presentationMap["id"]}

        if(presentation != null) {
            Purchasely.clientPresentationClosed(presentation)
            presentationsLoaded.removeAll { it.id == presentation.id }
        }
    }


    private fun setPaywallActionInterceptor(result: Result) {
        Purchasely.setPaywallActionsInterceptor { info, action, parameters, processAction ->
            paywallActionHandler = processAction
            paywallAction = action

            val parametersForFlutter = hashMapOf<String, Any?>();

            parametersForFlutter["title"] = parameters.title
            parametersForFlutter["url"] = parameters.url?.toString()
            parametersForFlutter["plan"] = transformPlanToMap(parameters.plan)
            parametersForFlutter["presentation"] = parameters.presentation

            result.success(mapOf(
                Pair("info", mapOf(
                    Pair("contentId", info?.contentId),
                    Pair("presentationId", info?.presentationId),
                    Pair("placementId", info?.placementId),
                    Pair("abTestId", info?.abTestId),
                    Pair("abTestVariantId", info?.abTestVariantId)
                )),
                Pair("action", when(action) {
                    PLYPresentationAction.PURCHASE -> "purchase"
                    PLYPresentationAction.CLOSE -> "close"
                    PLYPresentationAction.LOGIN -> "login"
                    PLYPresentationAction.NAVIGATE -> "navigate"
                    PLYPresentationAction.RESTORE -> "restore"
                    PLYPresentationAction.OPEN_PRESENTATION -> "open_presentation"
                    PLYPresentationAction.PROMO_CODE -> "promo_code"
                }),
                Pair("parameters", parametersForFlutter)
            ))
        }
    }

    private fun onProcessAction(processAction: Boolean) {
        launch {
            when(paywallAction) {
                PLYPresentationAction.PROMO_CODE,
                PLYPresentationAction.RESTORE,
                PLYPresentationAction.PURCHASE,
                PLYPresentationAction.LOGIN,
                PLYPresentationAction.OPEN_PRESENTATION -> {
                    productActivity?.relaunch(activity)
                    withContext(Dispatchers.Default) { delay(500) }
                }
                //We should not open purchasely paywall for other actions
                else -> {}
            }

            productActivity?.activity?.get()?.let {
                it.runOnUiThread {
                    paywallActionHandler?.invoke(processAction)
                }
            }
        }
    }

    private fun closePaywall(definitively: Boolean) {
        if(definitively) {
            val openedPaywall = productActivity?.activity?.get()
            if(openedPaywall is PLYPaywallActivity) {
                openedPaywall.finishAffinity()
                productActivity = null
                return
            } else if(openedPaywall is PLYProductActivity) {
                openedPaywall.finish()
                productActivity = null
                return
            }
        }

        val flutterActivity = activity
        val currentActivity = productActivity?.activity?.get() ?: flutterActivity
        if(flutterActivity != null && currentActivity != null) {
            flutterActivity.startActivity(Intent(currentActivity, flutterActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
            })
        }
    }

  //endregion

  companion object {
      var productActivity: ProductActivity? = null
      var presentationResult: Result? = null
      var fetchResult: Result? = null
      var defaultPresentationResult: Result? = null
      var paywallActionHandler: PLYCompletionHandler? = null
      var paywallAction: PLYPresentationAction? = null
      private lateinit var channel : MethodChannel

      val presentationsLoaded = mutableListOf<PLYPresentation>()

      fun sendFetchResult(presentation: PLYPresentation?, error: Exception?) {
          if(presentation != null) {
              presentationsLoaded.add(presentation)
              fetchResult?.success(presentation.toMap().mapValues {
                  val value = it.value
                  if(value is PLYPresentationType) value.ordinal
                  else value
              })
          }
          if(error != null) fetchResult?.error("467", error.message, error)
          fetchResult = null
      }

      fun sendPresentationResult(result: PLYProductViewResult, plan: PLYPlan?) {
          val productViewResult = when(result) {
              PLYProductViewResult.PURCHASED -> PLYProductViewResult.PURCHASED.ordinal
              PLYProductViewResult.CANCELLED -> PLYProductViewResult.CANCELLED.ordinal
              PLYProductViewResult.RESTORED -> PLYProductViewResult.RESTORED.ordinal
          }

          if(presentationResult != null) {
              presentationResult?.success(
                  mapOf(Pair("result", productViewResult), Pair("plan", transformPlanToMap(plan)))
              )
              presentationResult = null
          } else if(defaultPresentationResult != null) {
              defaultPresentationResult?.success(
                  mapOf(Pair("result", productViewResult), Pair("plan", transformPlanToMap(plan)))
              )
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

              this["isEligibleForIntroOffer"] = plan.isEligibleToIntroOffer()
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
      val placementId: String? = null,
      val productId: String? = null,
      val planId: String? = null,
      val contentId: String? = null,
      val isFullScreen: Boolean = false) {

      var activity: WeakReference<Activity>? = null

      fun relaunch(flutterActivity: Activity?) : Boolean {
          if(flutterActivity == null) return false

          val backgroundActivity = activity?.get()
          return if(backgroundActivity != null
              && !backgroundActivity.isFinishing) {
              backgroundActivity.startActivity(
                  Intent(backgroundActivity, backgroundActivity::class.java).apply {
                      flags = Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
                  }
              )
              true
          } else {
              val intent = PLYProductActivity.newIntent(flutterActivity)
              intent.putExtra("presentationId", presentationId)
              intent.putExtra("placementId", placementId)
              intent.putExtra("productId", productId)
              intent.putExtra("planId", planId)
              intent.putExtra("contentId", contentId)
              intent.putExtra("isFullScreen", isFullScreen)
              flutterActivity.startActivity(intent)
              return false
          }
      }
  }
}
