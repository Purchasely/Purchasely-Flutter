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
import io.purchasely.models.PLYPresentationPlan
import io.purchasely.models.PLYProduct
import kotlinx.coroutines.*
import io.purchasely.ext.Purchasely
import io.purchasely.models.PLYError
import io.purchasely.views.presentation.PLYThemeMode
import io.purchasely.views.presentation.models.PLYTransitionType
import java.lang.ref.WeakReference
import java.text.SimpleDateFormat
import java.util.*
import kotlin.collections.ArrayList
import kotlin.collections.HashMap
import io.purchasely.ext.UserAttributeListener
import io.purchasely.storage.userData.PLYUserAttributeSource
import io.purchasely.storage.userData.PLYUserAttributeType


/** PurchaselyFlutterPlugin */
class PurchaselyFlutterPlugin: FlutterPlugin, MethodCallHandler, ActivityAware, CoroutineScope {
    /// The MethodChannel that will the communication between Flutter and native Android
    ///
    /// This local reference serves to register the plugin with the Flutter Engine and unregister it
    /// when the Flutter Engine is detached from the Activity
    private lateinit var eventChannel: EventChannel
    private lateinit var purchaseChannel: EventChannel
    private lateinit var userAttributeChannel: EventChannel

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
        userAttributeChannel = EventChannel(flutterPluginBinding.binaryMessenger, "purchasely-user-attributes")

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

        userAttributeChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                Purchasely.userAttributeListener = object : UserAttributeListener {
                    override fun onUserAttributeSet(key: String, type: PLYUserAttributeType, value: Any, source: PLYUserAttributeSource) {
                        Handler(Looper.getMainLooper()).post {
                            val formattedValue = when (value) {
                                is Date -> SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.getDefault()).apply {
                                    timeZone = TimeZone.getTimeZone("GMT")
                                }.format(value)
                                is Array<*> -> value.toList()
                                else -> value
                            }
                            events?.success(
                                mapOf(
                                    "event" to "set",
                                    "key" to key,
                                    "type" to type.name,
                                    "value" to formattedValue,
                                    "source" to source.ordinal
                                )
                            )
                        }
                    }

                    override fun onUserAttributeRemoved(key: String, source: PLYUserAttributeSource) {
                        Handler(Looper.getMainLooper()).post {
                            events?.success(
                                mapOf(
                                    "event" to "removed",
                                    "key" to key,
                                    "source" to source.ordinal
                                )
                            )
                        }
                    }
                }
            }

            override fun onCancel(arguments: Any?) {
                Purchasely.userAttributeListener = null
            }
        })

        flutterPluginBinding
            .platformViewRegistry
            .registerViewFactory(NativeViewFactory.VIEW_TYPE_ID, NativeViewFactory(flutterPluginBinding.binaryMessenger))
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        when(call.method) {
            "start" -> {
                call.argument<String>("apiKey")?.let { apiKey ->
                    start(
                        apiKey = apiKey,
                        stores = call.argument<List<String>>("stores") ?: emptyList(),
                        storeKit1 = call.argument<Boolean>("storeKit1") ?: false,
                        userId = call.argument<String?>("userId"),
                        logLevel = call.argument<Int>("logLevel") ?: 1,
                        runningMode = call.argument<Int>("runningMode") ?: 3,
                        result = result
                    )
                }
            }
            "close" -> {
                close()
                result.safeSuccess(true)
            }
            "setDefaultPresentationResultHandler" -> setDefaultPresentationResultHandler(result)
            "synchronize" -> {
                synchronize()
                result.safeSuccess(true)
            }
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
                    result.safeError("-1", "product vendor id must not be null", null)
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
                    result.safeError("-1", "plan vendor id must not be null", null)
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
            "getAnonymousUserId" -> result.safeSuccess(getAnonymousUserId())
            "isAnonymous" -> result.safeSuccess(isAnonymous())
            "isEligibleForIntroOffer" -> {
                launch {
                    val planVendorId = call.argument<String>("planVendorId")
                    if(planVendorId == null) {
                        result.safeError("-1", "planVendorId must not be null", null)
                        return@launch
                    }

                    result.safeSuccess(isEligibleForIntroOffer(planVendorId))
                }
            }
            "userLogin" -> {
                val userId = call.argument<String>("userId") ?: let {
                    result.safeError("-1", "user id must not be null", null)
                    return
                }
                userLogin(userId, result)
            }
            "userLogout" -> {
                userLogout()
                result.safeSuccess(true)
            }
            "setLogLevel" -> {
                setLogLevel(call.argument<Int>("logLevel"))
                result.safeSuccess(true)
            }
            "readyToOpenDeeplink" -> {
                readyToOpenDeeplink(call.argument<Boolean>("readyToOpenDeeplink"))
                result.safeSuccess(true)
            }
            "setLanguage" -> {
                setLanguage(call.argument<String>("language"))
                result.safeSuccess(true)
            }
            "userDidConsumeSubscriptionContent" -> {
                Purchasely.userDidConsumeSubscriptionContent()
                result.safeSuccess(true)
            }
            "clientPresentationDisplayed" -> {
                clientPresentationDisplayed(call.argument<Map<String, Any>>("presentation"))
                result.safeSuccess(true)
            }
            "clientPresentationClosed" -> {
                clientPresentationClosed(call.argument<Map<String, Any>>("presentation"))
                result.safeSuccess(true)
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
                            result.safeSuccess(product.toMap().toMutableMap().apply {
                                this["plans"] = plans
                            })
                        } else {
                            result.safeError("-1", "product ${call.argument<String>("vendorId")} not found", null)
                        }
                    } catch (e: Exception) {
                        result.safeError("-1", e.message, e)
                    }
                }
            }
            "planWithIdentifier" -> {
                launch {
                    try {
                        val plan = planWithIdentifier(call.argument<String>("vendorId"))
                        if(plan != null) {
                            result.safeSuccess(transformPlanToMap(plan))
                        } else {
                            result.safeError("-1", "plan ${call.argument<String>("vendorId")} not found", null)
                        }
                    } catch (e: Exception) {
                        result.safeError("-1", e.message, e)
                    }
                }
            }
            "allProducts" -> launch { allProducts(result) }
            "purchaseWithPlanVendorId" -> purchaseWithPlanVendorId(
                call.argument<String>("vendorId"),
                call.argument<String>("offerId"),
                call.argument<String>("contentId"),
                result)
            "displaySubscriptionCancellationInstruction" -> {
                displaySubscriptionCancellationInstruction()
                result.safeSuccess(true)
            }
            "isDeeplinkHandled" -> isDeeplinkHandled(call.argument<String>("deeplink"), result)
            "userSubscriptions" -> launch { userSubscriptions(result) }
            "userSubscriptionsHistory" -> launch { userSubscriptionsHistory(result) }
            "presentSubscriptions" -> {
                presentSubscriptions()
                result.safeSuccess(true)
            }
            "setThemeMode" -> {
                setThemeMode(call.argument<Int>("mode"))
                result.safeSuccess(true)
            }
            "setAttribute" -> {
                setAttribute(call.argument<Int>("attribute"), call.argument<String>("value"))
                result.safeSuccess(true)
            }
            "setUserAttributeWithString" -> {
                val key = call.argument<String>("key") ?: return
                val value = call.argument<String>("value") ?: return
                val processingLegalBasis = processingLegalBasisFrom(call.argument<String>("processingLegalBasis"))
                setUserAttributeWithString(key, value, processingLegalBasis)
                result.safeSuccess(true)
            }
            "setUserAttributeWithInt" -> {
                val key = call.argument<String>("key") ?: return
                val value = call.argument<Int>("value") ?: return
                val processingLegalBasis = processingLegalBasisFrom(call.argument<String>("processingLegalBasis"))
                setUserAttributeWithInt(key, value, processingLegalBasis)
                result.safeSuccess(true)
            }
            "setUserAttributeWithDouble" -> {
                val key = call.argument<String>("key") ?: return
                val value = call.argument<Double>("value") ?: return
                val processingLegalBasis = processingLegalBasisFrom(call.argument<String>("processingLegalBasis"))
                setUserAttributeWithDouble(key, value, processingLegalBasis)
                result.safeSuccess(true)
            }
            "setUserAttributeWithBoolean" -> {
                val key = call.argument<String>("key") ?: return
                val value = call.argument<Boolean>("value") ?: return
                val processingLegalBasis = processingLegalBasisFrom(call.argument<String>("processingLegalBasis"))
                setUserAttributeWithBoolean(key, value, processingLegalBasis)
                result.safeSuccess(true)
            }
            "setUserAttributeWithStringArray" -> {
                val key = call.argument<String>("key") ?: return
                val value = call.argument<List<String>>("value") ?: return
                val processingLegalBasis = processingLegalBasisFrom(call.argument<String>("processingLegalBasis"))
                setUserAttributeWithStringArray(key, value, processingLegalBasis)
                result.safeSuccess(true)
            }
            "setUserAttributeWithIntArray" -> {
                val key = call.argument<String>("key") ?: return
                val value = call.argument<List<Int>>("value") ?: return
                val processingLegalBasis = processingLegalBasisFrom(call.argument<String>("processingLegalBasis"))
                setUserAttributeWithIntArray(key, value, processingLegalBasis)
                result.safeSuccess(true)
            }
            "setUserAttributeWithDoubleArray" -> {
                val key = call.argument<String>("key") ?: return
                val value = call.argument<List<Double>>("value") ?: return
                val processingLegalBasis = processingLegalBasisFrom(call.argument<String>("processingLegalBasis"))
                setUserAttributeWithDoubleArray(key, value, processingLegalBasis)
                result.safeSuccess(true)
            }
            "setUserAttributeWithBooleanArray" -> {
                val key = call.argument<String>("key") ?: return
                val value = call.argument<List<Boolean>>("value") ?: return
                val processingLegalBasis = processingLegalBasisFrom(call.argument<String>("processingLegalBasis"))
                setUserAttributeWithBooleanArray(key, value, processingLegalBasis)
                result.safeSuccess(true)
            }
            "setUserAttributeWithDate" -> {
                val key = call.argument<String>("key") ?: return
                val value = call.argument<String>("value") ?: return
                val processingLegalBasis = processingLegalBasisFrom(call.argument<String>("processingLegalBasis"))
                setUserAttributeWithDate(key, value, processingLegalBasis)
                result.safeSuccess(true)
            }
            "incrementUserAttribute" -> {
                val key = call.argument<String>("key") ?: return
                val value = call.argument<Int>("value") ?: 1
                val processingLegalBasis = processingLegalBasisFrom(call.argument<String>("processingLegalBasis"))
                incrementUserAttribute(key, value, processingLegalBasis)
                result.safeSuccess(true)
            }
            "decrementUserAttribute" -> {
                val key = call.argument<String>("key") ?: return
                val value = call.argument<Int>("value") ?: 1
                val processingLegalBasis = processingLegalBasisFrom(call.argument<String>("processingLegalBasis"))
                decrementUserAttribute(key, value, processingLegalBasis)
                result.safeSuccess(true)
            }
            "userAttribute" -> {
                val key = call.argument<String>("key") ?: return
                userAttribute(key, result)
            }
            "userAttributes" -> userAttributes(result)
            "clearUserAttribute" -> {
                val key = call.argument<String>("key") ?: return
                clearUserAttribute(key)
                result.safeSuccess(true)
            }
            "clearUserAttributes" -> {
                clearUserAttributes()
                result.safeSuccess(true)
            }
            "clearBuiltInAttributes" -> {
                clearBuiltInAttributes()
                result.safeSuccess(true)
            }
            "setPaywallActionInterceptor" -> setPaywallActionInterceptor(result)
            "onProcessAction" -> {
                onProcessAction(call.argument<Boolean>("processAction") ?: false)
                result.safeSuccess(true)
            }
            "closePresentation" -> {
                closePresentation()
                result.safeSuccess(true)
            }
            "hidePresentation" -> {
                hidePresentation()
                result.safeSuccess(true)
            }
            "showPresentation" -> {
                showPresentation()
                result.safeSuccess(true)
            }
            "setDynamicOffering" -> {
                setDynamicOffering(
                    call.argument<String>("reference") ?: "",
                    call.argument<String>("planVendorId") ?: "",
                    call.argument<String>("offerVendorId"),
                    result
                )
            }
            "getDynamicOfferings" -> getDynamicOfferings(result)
            "removeDynamicOffering" -> {
                removeDynamicOffering(
                    call.argument<String>("reference") ?: ""
                )
            }
            "clearDynamicOfferings" -> clearDynamicOfferings()
            "revokeDataProcessingConsent" -> {
                val purposes = call.argument<List<String>>("purposes") ?: return
                revokeDataProcessingConsent(purposes)
            }
            "setDebugMode" -> {
                val debugMode = call.argument<Boolean>("debugMode") ?: return
                Purchasely.debugMode = debugMode
                result.safeSuccess(true)
            }
            "isDebugMode" -> {
                result.safeSuccess(Purchasely.debugMode)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    //region Purchasely
    private fun start(
        apiKey: String,
        stores: List<String>,
        storeKit1: Boolean,
        userId: String?,
        logLevel: Int,
        runningMode: Int,
        result: Result
    ) {
        Purchasely.Builder(context)
            .apiKey(apiKey)
            .stores(getStoresInstances(stores))
            .logLevel(LogLevel.values()[logLevel])
            .runningMode(when(runningMode) {
                0 -> PLYRunningMode.Full
                1 -> PLYRunningMode.PaywallObserver
                2 -> PLYRunningMode.PaywallObserver
                else -> PLYRunningMode.Full
            })
            .userId(userId)
            .build()

	  Purchasely.sdkBridgeVersion = "5.6.0"
        Purchasely.appTechnology = PLYAppTechnology.FLUTTER

        Purchasely.start { isConfigured, error ->
            if(isConfigured) {
                result.safeSuccess(true)
            } else {
                result.safeError("0", error?.message ?: "Purchasely SDK not configured", error)
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

        val properties = PLYPresentationProperties(
            placementId = placementId,
            presentationId = presentationId,
            contentId = contentId)

        Purchasely.fetchPresentation(
            properties = properties
        ) { presentation: PLYPresentation?, error: PLYError? ->
            launch {
                if (presentation != null) {
                    presentationsLoaded.removeAll { it.id == presentation.id && it.placementId == presentation.placementId }
                    presentationsLoaded.add(presentation)
                    val map = presentation.toMap().mapValues {
                        val value = it.value
                        when(value) {
                            is PLYPresentationType -> value.ordinal
                            is PLYTransitionType -> value.ordinal
                            else -> value
                        }
                    }
                    val mutableMap = map.toMutableMap().apply {
                        this["height"] = presentation.height
                        this["metadata"] = presentation.metadata?.toMap()
                        this["plans"] = (this["plans"] as List<PLYPresentationPlan>).map { it.toMap() }
                    }
                    result.safeSuccess(mutableMap)
                }

                if (error != null) result.safeError("467", error.message, error)
            }
        }
    }

    private fun presentPresentation(presentationMap: Map<String, Any>?,
                                    isFullScreen: Boolean,
                                    result: Result) {
        if (presentationMap == null) {
            result.safeError("-1", "presentation cannot be null", null)
            return
        }

        if(presentationsLoaded.none { it.id == presentationMap["id"] }) {
            result.safeError("-1", "presentation was not fetched", null)
            return
        }

        val presentation = presentationsLoaded.lastOrNull {
            it.id == presentationMap["id"]
                    && it.placementId == presentationMap["placementId"]
        }

        if(presentation == null) {
            result.safeError("468", "Presentation not found", NullPointerException("presentation not fond"))
            return
        }

        presentationResult = result

        activity?.let {
            if (presentation.flowId != null) {
                presentation.display(it) { result, plan ->
                    sendPresentationResult(result, plan)
                }
            } else {
                // Open legacy Activity for now if not a flow
                val intent = PLYProductActivity.newIntent(it).apply {
                    putExtra("presentation", presentation)
                    putExtra("isFullScreen", isFullScreen)
                }
                it.startActivity(intent)
            }
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
            onSuccess = { plan ->
                result.safeSuccess(true)
                Purchasely.restoreAllProducts(null)
            },
            onError = { error ->
                error?.let {
                    result.safeError("-1", it.message, it)
                } ?: let {
                    result.safeError("-1", "Unknown error", null)
                }
                Purchasely.restoreAllProducts(null)
            }
        )
    }

    private fun purchaseWithPlanVendorId(planVendorId: String?, offerId: String?, contentId: String?, result: Result) {
        launch {
            try {
                val plan = Purchasely.plan(planVendorId ?: "")
                val offer = plan?.promoOffers?.firstOrNull { it.vendorId == offerId }
                if(plan != null && activity != null) {
                    Purchasely.purchase(activity!!, plan, offer, contentId,
                        onSuccess = {
                            result.safeSuccess(it?.toMap())
                        },
                        onError = { error ->
                            error?.let {
                                result.safeError("-1", it.message, it)
                            } ?: let {
                                result.safeError("-1", "Unknown error", null)
                            }
                        }
                    )
                } else {
                    result.safeError("-1","plan $planVendorId not found", null)
                }
            } catch (e: Exception) {
                result.safeError("-1", e.message, e)
            }
        }
    }

    private fun getAnonymousUserId() : String = Purchasely.anonymousUserId

    private fun isAnonymous() : Boolean = Purchasely.isAnonymous()

    private fun userLogin(userId: String, result: Result) {
        Purchasely.userLogin(userId) { refresh -> result.safeSuccess(refresh) }
    }

    private fun userLogout() {
        Purchasely.userLogout()
    }

    private fun setLogLevel(logLevel: Int?) {
        Purchasely.logLevel = LogLevel.values()[logLevel ?: 0]
    }

    private fun readyToOpenDeeplink(readyToOpenDeeplink: Boolean?) {
        Purchasely.readyToOpenDeeplink = readyToOpenDeeplink ?: true
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
            result.safeSuccess(list)
        } catch (e: Exception) {
            result.safeError("-1", e.message, e)
        }
    }

    private fun isDeeplinkHandled(deeplink: String?, result: Result) {
        if (deeplink == null) {
            result.safeError("-1", "Deeplink must not be null", null)
            return
        }
        val uri = Uri.parse(deeplink)
        result.safeSuccess(Purchasely.isDeeplinkHandled(uri))
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
            result.safeSuccess(list)
        } catch (e: Exception) {
            result.safeError("-1", e.message, e)
        }
    }

    private suspend fun userSubscriptionsHistory(result: Result) {
        try {
            val subscriptions = Purchasely.userSubscriptionsHistory()
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
            result.safeSuccess(list)
        } catch (e: Exception) {
            result.safeError("-1", e.message, e)
        }
    }

    private fun presentSubscriptions() {
        val intent = Intent(context, PLYSubscriptionsActivity::class.java)
        activity?.startActivity(intent)
    }

    private fun setThemeMode(mode: Int?) {
        if(mode == null) return

        Purchasely.setThemeMode(PLYThemeMode.values()[mode])
    }

    private fun setAttribute(attribute: Int?, value: String?) {
        if(attribute == null || value == null) return

        val attributeKey = when (attribute) {
            FlutterPLYAttribute.firebase_app_instance_id.ordinal -> Attribute.FIREBASE_APP_INSTANCE_ID
            FlutterPLYAttribute.airship_channel_id.ordinal -> Attribute.AIRSHIP_CHANNEL_ID
            FlutterPLYAttribute.airship_user_id.ordinal -> Attribute.AIRSHIP_USER_ID
            FlutterPLYAttribute.batch_installation_id.ordinal -> Attribute.BATCH_INSTALLATION_ID
            FlutterPLYAttribute.adjust_id.ordinal -> Attribute.ADJUST_ID
            FlutterPLYAttribute.appsflyer_id.ordinal -> Attribute.APPSFLYER_ID
            FlutterPLYAttribute.mixpanel_distinct_id.ordinal -> Attribute.MIXPANEL_DISTINCT_ID
            FlutterPLYAttribute.clever_tap_id.ordinal -> Attribute.CLEVER_TAP_ID
            FlutterPLYAttribute.sendinblueUserEmail.ordinal -> Attribute.SENDINBLUE_USER_EMAIL
            FlutterPLYAttribute.iterableUserEmail.ordinal -> Attribute.ITERABLE_USER_EMAIL
            FlutterPLYAttribute.iterableUserId.ordinal -> Attribute.ITERABLE_USER_ID
            FlutterPLYAttribute.atInternetIdClient.ordinal -> Attribute.AT_INTERNET_ID_CLIENT
            FlutterPLYAttribute.mParticleUserId.ordinal -> Attribute.MPARTICLE_USER_ID
            FlutterPLYAttribute.customerioUserId.ordinal -> Attribute.CUSTOMERIO_USER_ID
            FlutterPLYAttribute.customerioUserEmail.ordinal -> Attribute.CUSTOMERIO_USER_EMAIL
            FlutterPLYAttribute.branchUserDeveloperIdentity.ordinal -> Attribute.BRANCH_USER_DEVELOPER_IDENTITY
            FlutterPLYAttribute.amplitudeUserId.ordinal -> Attribute.AMPLITUDE_USER_ID
            FlutterPLYAttribute.amplitudeDeviceId.ordinal -> Attribute.AMPLITUDE_DEVICE_ID
            FlutterPLYAttribute.moengageUniqueId.ordinal -> Attribute.MOENGAGE_UNIQUE_ID
            FlutterPLYAttribute.oneSignalExternalId.ordinal -> Attribute.ONESIGNAL_EXTERNAL_ID
            FlutterPLYAttribute.batchCustomUserId.ordinal -> Attribute.BATCH_CUSTOM_USER_ID
            else -> null
        }

        attributeKey?.let {
            Purchasely.setAttribute(attribute = it, value = value)
        }
    }

    fun setUserAttributeWithString(key: String, value: String, processingLegalBasis: PLYDataProcessingLegalBasis) {
        Purchasely.setUserAttribute(key, value, processingLegalBasis)
    }

    fun setUserAttributeWithInt(key: String, value: Int, processingLegalBasis: PLYDataProcessingLegalBasis) {
        Purchasely.setUserAttribute(key, value, processingLegalBasis)
    }

    fun setUserAttributeWithDouble(key: String, value: Double, processingLegalBasis: PLYDataProcessingLegalBasis) {
        Purchasely.setUserAttribute(key, value.toFloat(), processingLegalBasis)
    }

    fun setUserAttributeWithBoolean(key: String, value: Boolean, processingLegalBasis: PLYDataProcessingLegalBasis) {
        Purchasely.setUserAttribute(key, value, processingLegalBasis)
    }

    fun setUserAttributeWithStringArray(key: String, value: List<String>, processingLegalBasis: PLYDataProcessingLegalBasis) {
        Purchasely.setUserAttribute(key, value.toTypedArray(), processingLegalBasis)
    }

    fun setUserAttributeWithIntArray(key: String, value: List<Int>, processingLegalBasis: PLYDataProcessingLegalBasis) {
        Purchasely.setUserAttribute(key, value.toTypedArray(), processingLegalBasis)
    }

    fun setUserAttributeWithDoubleArray(key: String, value: List<Double>, processingLegalBasis: PLYDataProcessingLegalBasis) {
        Purchasely.setUserAttribute(key, value.map { it.toFloat() }.toTypedArray(), processingLegalBasis)
    }

    fun setUserAttributeWithBooleanArray(key: String, value: List<Boolean>, processingLegalBasis: PLYDataProcessingLegalBasis) {
        Purchasely.setUserAttribute(key, value.toTypedArray(), processingLegalBasis)
    }

    fun setUserAttributeWithDate(key: String, value: String, processingLegalBasis: PLYDataProcessingLegalBasis) {
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
            Purchasely.setUserAttribute(key, calendar.time, processingLegalBasis)
        } catch (e: Exception) {
            Log.e("Purchasely", "Cannot save date attribute $key", e)
        }
    }

    private fun incrementUserAttribute(key: String, value: Int, processingLegalBasis: PLYDataProcessingLegalBasis) {
        Purchasely.incrementUserAttribute(key, value, processingLegalBasis)
    }

    private fun decrementUserAttribute(key: String, value: Int, processingLegalBasis: PLYDataProcessingLegalBasis) {
        Purchasely.decrementUserAttribute(key, value, processingLegalBasis)
    }

    private fun processingLegalBasisFrom(string: String?): PLYDataProcessingLegalBasis {
        return when (string) {
            "ESSENTIAL" -> PLYDataProcessingLegalBasis.ESSENTIAL
            else -> PLYDataProcessingLegalBasis.OPTIONAL
        }
    }

    fun userAttribute(key: String, result: Result) {
        val value = getUserAttributeValueForFlutter(Purchasely.userAttribute(key))
        result.safeSuccess(value)
    }

    fun userAttributes(result: Result) {
        val map = Purchasely.userAttributes()
        result.safeSuccess(
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
            is Array<*> -> {
                when {
                    value.isArrayOf<String>() -> value.toList()
                    value.isArrayOf<Int>() -> value.toList()
                    value.isArrayOf<Float>() -> value.map { it.toString().toDouble() }.toList()
                    value.isArrayOf<Boolean>() -> value.toList()
                    else -> value
                }
            }
            else -> value
        }
    }

    fun clearUserAttribute(key: String) {
        Purchasely.clearUserAttribute(key)
    }

    fun clearUserAttributes() {
        Purchasely.clearUserAttributes()
    }

    fun clearBuiltInAttributes() {
        Purchasely.clearBuiltInAttributes()
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
            parametersForFlutter["presentation"] = parameters.presentation
            parametersForFlutter["placement"] = parameters.placement
            parametersForFlutter["plan"] = transformPlanToMap(parameters.plan)
            parametersForFlutter["offer"] = mapOf<String, String?>(
                "vendorId" to parameters.offer?.vendorId,
                "storeOfferId" to parameters.offer?.storeOfferId
            )
            parametersForFlutter["subscriptionOffer"] = parameters.subscriptionOffer?.toMap()
            parametersForFlutter["closeReason"] = parameters?.closeReason?.name
            parametersForFlutter["clientReferenceId"] = parameters?.clientReferenceId
            parametersForFlutter["queryParameterKey"] = parameters?.queryParameterKey
            parametersForFlutter["webCheckoutProvider"] = parameters?.webCheckoutProvider?.name

            result.safeSuccess(mapOf(
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
                    PLYPresentationAction.CLOSE_ALL -> "close_all"
                    PLYPresentationAction.LOGIN -> "login"
                    PLYPresentationAction.NAVIGATE -> "navigate"
                    PLYPresentationAction.RESTORE -> "restore"
                    PLYPresentationAction.OPEN_PRESENTATION -> "open_presentation"
                    PLYPresentationAction.PROMO_CODE -> "promo_code"
                    PLYPresentationAction.OPEN_PLACEMENT -> "open_placement"
                    PLYPresentationAction.OPEN_FLOW_STEP -> "open_flow_step"
                    PLYPresentationAction.WEB_CHECKOUT -> "web_checkout"
                }),
                Pair("parameters", parametersForFlutter)
            ))
        }
    }

    private fun showPresentation() {
        launch {
            productActivity?.relaunch(activity)
            withContext(Dispatchers.Default) { delay(500) }
        }
    }

    private fun onProcessAction(processAction: Boolean) {
        activity?.let {
            it.runOnUiThread {
                paywallActionHandler?.invoke(processAction)
            }
        }
    }

    private fun closePresentation() {
        Purchasely.closeAllScreens()
        productActivity = null
    }

    private fun hidePresentation() {
        val flutterActivity = activity
        val currentActivity = productActivity?.activity?.get() ?: flutterActivity
        if(flutterActivity != null && currentActivity != null) {
            flutterActivity.startActivity(Intent(currentActivity, flutterActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
            })
        }
    }

    private suspend fun isEligibleForIntroOffer(planVendorId: String) : Boolean {
        return try {
            val plan = Purchasely.plan(planVendorId)
            if(plan != null) {
                plan.isEligibleToIntroOffer()
            } else {
                Log.e("Purchasely", "plan $planVendorId not found")
                false
            }
        } catch (e: Exception) {
            Log.e("Purchasely", e.message, e)
            false
        }
    }

    fun setDynamicOffering(reference: String, planVendorId: String, offerId: String?, result: Result) {
        Purchasely.setDynamicOffering(reference, planVendorId, offerId) {
            result.safeSuccess(it)
        }
    }

    fun getDynamicOfferings(result: Result) {
        Purchasely.getDynamicOfferings { offerings ->
            val list = ArrayList<Map<String,String>>()
            for (offering in offerings) {
                val map = mutableMapOf<String, String>()
                map["reference"] = offering.reference
                map["planVendorId"] = offering.planId
                if (offering.offerId != null) map["offerVendorId"] = offering.offerId!!
                list.add(map.toMap())
            }
            result.safeSuccess(list)
        }
    }

    fun removeDynamicOffering(reference: String) {
        Purchasely.removeDynamicOffering(reference)
    }

    fun clearDynamicOfferings() {
        Purchasely.clearDynamicOfferings()
    }

    private fun revokeDataProcessingConsent(purposes: List<String>) {
        val mappedPurposes = purposes.mapNotNull {
            when (it) {
                "ANALYTICS" -> PLYDataProcessingPurpose.Analytics
                "IDENTIFIED_ANALYTICS" -> PLYDataProcessingPurpose.IdentifiedAnalytics
                "CAMPAIGNS" -> PLYDataProcessingPurpose.Campaigns
                "PERSONALIZATION" -> PLYDataProcessingPurpose.Personalization
                "THIRD_PARTY_INTEGRATIONS" -> PLYDataProcessingPurpose.ThirdPartyIntegrations
                "ALL_NON_ESSENTIALS" -> PLYDataProcessingPurpose.AllNonEssentials
                else -> null // Ignore any unrecognized strings
            }
        }.toSet()
        Purchasely.revokeDataProcessingConsent(mappedPurposes)
    }

    //endregion

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
        val presentation: PLYPresentation? = null,
        val presentationId: String? = null,
        val placementId: String? = null,
        val productId: String? = null,
        val planId: String? = null,
        val contentId: String? = null,
        val isFullScreen: Boolean = false,
        val loadingBackgroundColor: String? = null,) {

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
                intent.putExtra("presentation", presentation)
                intent.putExtra("presentationId", presentationId)
                intent.putExtra("placementId", placementId)
                intent.putExtra("productId", productId)
                intent.putExtra("planId", planId)
                intent.putExtra("contentId", contentId)
                intent.putExtra("isFullScreen", isFullScreen)
                intent.putExtra("background_color", loadingBackgroundColor)
                flutterActivity.startActivity(intent)
                return false
            }
        }
    }

    fun PLYPresentationPlan.toMap() : Map<String, String?> {
        return mapOf(
            Pair("planVendorId", planVendorId),
            Pair("storeProductId", storeProductId),
            Pair("basePlanId", basePlanId),
            //Pair("offerId", offerId)
        )
    }

    suspend fun PLYPresentationMetadata.toMap() : Map<String, Any> {
        val metadata = mutableMapOf<String, Any>()
        this.keys()?.forEach { key ->
            val value = when (this.type(key)) {
                kotlin.String::class.java.simpleName -> this.getString(key)
                else -> this.get(key)
            }
            value?.let {
                metadata.put(key, it)
            }
        }

        return metadata
    }

    private fun Result.safeSuccess(map: Map<String, Any?>) {
        try {
            this.success(map)
        } catch (e: Throwable) {
            PLYLogger.e("Callback cannot be called: " + e.message, e)
        }
    }

    private fun Result.safeSuccess(value: Any?) {
        try {
            this.success(value)
        } catch (e: Throwable) {
            PLYLogger.e("Callback cannot be called: " + e.message, e)
        }
    }

    private fun Result.safeSuccess(list: ArrayList<MutableMap<String, Any?>>) {
        try {
            this.success(list)
        } catch (e: Throwable) {
            PLYLogger.e("Callback cannot be called: " + e.message, e)
        }
    }

    private fun Result.safeError(errorCode: String, message: String?, e: Throwable?) {
        try {
            this.error(errorCode, message, e)
        } catch (e: Throwable) {
            PLYLogger.e("Callback cannot be called: " + e.message, e)
        }
    }

    companion object {
        var productActivity: ProductActivity? = null
        var presentationResult: Result? = null
        var defaultPresentationResult: Result? = null
        var paywallActionHandler: PLYCompletionHandler? = null
        var paywallAction: PLYPresentationAction? = null
        private lateinit var channel : MethodChannel

        val presentationsLoaded = mutableListOf<PLYPresentation>()

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
            }
        }

        // WARNING: This enum must be strictly identical to the one in the Flutter side (purchasely_flutter.PLYAttribute).
        enum class FlutterPLYAttribute {
            firebase_app_instance_id,
            airship_channel_id,
            airship_user_id,
            batch_installation_id,
            adjust_id,
            appsflyer_id,
            mixpanel_distinct_id,
            clever_tap_id,
            sendinblueUserEmail,
            iterableUserEmail,
            iterableUserId,
            atInternetIdClient,
            mParticleUserId,
            customerioUserId,
            customerioUserEmail,
            branchUserDeveloperIdentity,
            amplitudeUserId,
            amplitudeDeviceId,
            moengageUniqueId,
            oneSignalExternalId,
            batchCustomUserId,
        }
    }
}
