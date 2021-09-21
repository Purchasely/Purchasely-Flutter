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
import io.purchasely.ext.Purchasely


/** PurchaselyPlugin */
class PurchaselyPlugin: FlutterPlugin, MethodCallHandler, ActivityAware, CoroutineScope {
    /// The MethodChannel that will the communication between Flutter and native Android
    ///
    /// This local reference serves to register the plugin with the Flutter Engine and unregister it
    /// when the Flutter Engine is detached from the Activity
    private lateinit var eventChannel: EventChannel
    private lateinit var purchaseChannel: EventChannel

    private lateinit var context: Context
    private var activity: Activity? = null

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
                        val properties = event.properties?.toMap() ?: emptyMap()
                        events?.success(mapOf(Pair("name", event.name), Pair("properties", properties)))
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
                                events?.success(null);
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
                        call.argument<String>("userId"), call.argument<Int>("logLevel"), result)
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
            "setLoginTappedHandler" -> setLoginTappedHandler(result)
            "onUserLoggedIn" -> onUserLoggedIn(call.argument<Boolean>("userLoggedIn") ?: false)
            "setConfirmPurchaseHandler" -> setConfirmPurchaseHandler(result)
            "processToPayment" -> processToPayment(call.argument<Boolean>("processToPayment") ?: false)
            else -> {
                result.notImplemented()
            }
        }
    }

    //region Purchasely
    private fun startWithApiKey(
        apiKey: String?, stores: List<String>?,
        userId: String?, logLevel: Int?,
        result: Result) {
        if(apiKey == null) throw IllegalArgumentException("Api key must not be null")

        Purchasely.Builder(context)
              .apiKey(apiKey)
              .stores(getStoresInstances(stores))
              .logLevel(LogLevel.values()[logLevel ?: 0])
              .userId(userId)
              .build()

        Purchasely.appTechnology = PLYAppTechnology.FLUTTER

        Purchasely.start { result.success(it) }
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

    private fun setAttribute(attribute: Int?, value: String?) {
        value?.let { Purchasely.setAttribute(Attribute.values()[attribute ?: 0], it) }
    }

    private fun setLoginTappedHandler(result: Result) {
        Purchasely.setLoginTappedHandler { _, refreshPresentation ->
            loginCompletionHandler = refreshPresentation
            result.success(null)
        }
    }

    private fun onUserLoggedIn(userLoggedIn: Boolean) {
        loginCompletionHandler?.invoke(userLoggedIn)
    }

    private fun setConfirmPurchaseHandler(result: Result) {
        Purchasely.setConfirmPurchaseHandler { _, processToPayment ->
            processToPaymentHandler = processToPayment
            result.success(null)
        }
    }

    private fun processToPayment(processToPayment: Boolean) {
        activity?.runOnUiThread {
            processToPaymentHandler?.invoke(processToPayment)
        }
    }

    //endregion

    companion object {
        var presentationResult: Result? = null
        var defaultPresentationResult: Result? = null
        var loginCompletionHandler: PLYLoginCompletionHandler? = null
        var processToPaymentHandler: PLYProcessToPaymentHandler? = null
        private lateinit var channel : MethodChannel

        fun sendPresentationResult(result: PLYProductViewResult, plan: PLYPlan?) {
            if(presentationResult != null) {
                presentationResult?.success(
                    mapOf(Pair("result", result.name), Pair("plan", plan?.toMap() ?: emptyMap()))
                )
                presentationResult = null
            } else if(defaultPresentationResult != null) {
                defaultPresentationResult?.success(
                    mapOf(Pair("result", result.name), Pair("plan", plan?.toMap() ?: emptyMap()))
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
