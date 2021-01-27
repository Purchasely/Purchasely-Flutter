package com.flutterpurchasely

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.util.Log
import androidx.annotation.NonNull
import androidx.fragment.app.FragmentActivity

import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

import io.purchasely.billing.Store
import io.purchasely.ext.*
import io.purchasely.models.PLYPlan
import io.purchasely.models.PLYProduct
import kotlinx.coroutines.*

/** PurchaselyPlugin */
class PurchaselyPlugin: FlutterPlugin, MethodCallHandler, ActivityAware, CoroutineScope {
    /// The MethodChannel that will the communication between Flutter and native Android
    ///
    /// This local reference serves to register the plugin with the Flutter Engine and unregister it
    /// when the Flutter Engine is detached from the Activity
    private lateinit var channel : MethodChannel
    private lateinit var eventChannel: EventChannel

    private lateinit var context: Context
    private var activity: Activity? = null

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "purchasely")
        channel.setMethodCallHandler(this)
        context = flutterPluginBinding.applicationContext

        eventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "purchasely-events")

        eventChannel.setStreamHandler(object: EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                Purchasely.eventListener = object: EventListener {
                    override fun onEvent(event: PLYEvent) {
                        val properties = event.properties?.toMap() ?: emptyMap()
                        events?.success(mapOf(Pair("name", event.name), Pair("properties", properties)))
                    }
                }
            }

            override fun onCancel(arguments: Any?) {
                Purchasely.eventListener = null
            }

        })
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        when(call.method) {
            "startWithApiKey" -> {
                startWithApiKey(call.argument<String>("apiKey"), call.argument<List<String>>("stores"),
                        call.argument<String>("userId"), call.argument<String>("logLevel"))
                result.success(true)
            }
            "close" -> {
                close()
                result.success(true)
            }
            "presentPresentationWithIdentifier" -> {
                presentPresentationWithIdentifier(
                        call.argument<String>("presentationVendorId")
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
                userLogin(userId)
                result.success(true)
            }
            "userLogout" -> userLogout()
            "setLogLevel" -> {
                setLogLevel(call.argument<String>("logLevel"))
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
                            result.success(product.toMap())
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
                            result.success(plan.toMap())
                        } else {
                            result.error("-1", "plan ${call.argument<String>("vendorId")} not found", null)
                        }
                    } catch (e: Exception) {
                        result.error("-1", e.message, e)
                    }
                }
            }
            "purchaseWithPlanVendorId" -> purchaseWithPlanVendorId(call.argument<String>("vendorId"), result)
            "displaySubscriptionCancellationInstruction" -> displaySubscriptionCancellationInstruction()
            "handle" -> handle(call.argument<String>("deeplink"), result)
            "userSubscriptions" -> launch { userSubscriptions(result) }
            "presentSubscriptions" -> presentSubscriptions()
            else -> {
                result.notImplemented()
            }
        }
    }

    //region Purchasely
    private fun startWithApiKey(apiKey: String?, stores: List<String>?,
                                userId: String?, logLevel: String?) {
        if(apiKey == null) throw IllegalArgumentException("Api key must not be null")

      Purchasely.Builder(context)
              .apiKey(apiKey)
              .stores(getStoresInstances(stores))
              .logLevel(LogLevel.DEBUG)
              .userId(userId)
              .build()
              .start()

        setLogLevel(logLevel)
    }

    private fun close() {
        Purchasely.close()
    }

    private fun presentPresentationWithIdentifier(presentationVendorId: String?) {

        val intent = Intent(context, PLYProductActivity::class.java)
        intent.putExtra("presentationId", presentationVendorId)
        activity?.startActivity(intent)
    }

    private fun restoreAllProducts(result: Result) {
        val listener = object: PurchaseListener {
            override fun onPurchaseStateChanged(state: State) {
                when(state) {
                    is State.RestorationComplete -> {
                        Purchasely.purchaseListener = null
                        result.success(true)
                    }
                    is State.RestorationFailed -> {
                        Purchasely.purchaseListener = null
                        result.error("-1", state.error.message, state.error)
                    }
                    is State.RestorationNoProducts -> {
                        Purchasely.purchaseListener = null
                        result.success(false)
                    }
                    is State.Error -> {
                        Purchasely.purchaseListener = null
                        state.error?.let {
                            result.error("-1", it.message, it)
                        } ?: let {
                            result.error("-1", "Unknown error", null)
                        }
                    }
                    else -> {
                        //do nothing
                    }
                }
            }
        }

        Purchasely.restoreAllProducts(listener)
    }

    private fun purchaseWithPlanVendorId(planVendorId: String?, result: Result) {
        val listener = object: PurchaseListener {
            override fun onPurchaseStateChanged(state: State) {
                when(state) {
                    is State.PurchaseComplete -> {
                        Purchasely.purchaseListener = null
                        result.success(state.plan?.toMap())
                    }
                    is State.PurchaseFailed -> {
                        Purchasely.purchaseListener = null
                        result.error("-1", state.error.message, state.error)
                    }
                    is State.Error -> {
                        Purchasely.purchaseListener = null
                        result.error("-1", state.error?.message, state.error)
                    }
                    else -> {
                        //do nothing
                    }
                }
            }
        }

        launch {
            try {
                val plan = Purchasely.getPlan(planVendorId ?: "")
                if(plan != null && activity != null) {
                    Purchasely.purchase(activity!!, plan, listener)
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

    private fun userLogin(userId: String) {
        Purchasely.userLogin(userId)
    }

    private fun userLogout() {
        Purchasely.userLogout()
    }

    private fun setLogLevel(logLevel: String?) {
        Purchasely.logLevel = when(logLevel) {
            LOG_LEVEL_DEBUG -> LogLevel.DEBUG
            LOG_LEVEL_INFO -> LogLevel.INFO
            LOG_LEVEL_WARN -> LogLevel.WARN
            else -> LogLevel.ERROR
        }
    }

    private fun isReadyToPurchase(readyToPurchase: Boolean?) {
        Purchasely.isReadyToPurchase = readyToPurchase ?: true
    }

    private suspend fun productWithIdentifier(vendorId: String?) : PLYProduct? {
        return Purchasely.getProduct(vendorId ?: "")
    }

    private suspend fun planWithIdentifier(vendorId: String?) : PLYPlan? {
        return Purchasely.getPlan(vendorId ?: "")
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
            val subscriptions = Purchasely.getUserSubscriptions()
            val list = arrayListOf<Map<String, Any?>>()
            for (data in subscriptions) {
                list.add(data.toMap())
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

    //endregion

    companion object {
        var presentationResult: Result? = null

        fun sendPresentationResult(result: PLYProductViewResult, plan: PLYPlan?) {
            presentationResult?.success(mapOf(Pair("result", result.name), Pair("plan", plan?.toMap() ?: emptyMap())))
            presentationResult = null
        }

        private const val LOG_LEVEL_DEBUG = "debug"
        private const val LOG_LEVEL_INFO = "info"
        private const val LOG_LEVEL_WARN = "warn"
        private const val LOG_LEVEL_ERROR = "error"
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

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        job.cancel()
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
}
