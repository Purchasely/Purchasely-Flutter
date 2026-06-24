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
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.annotation.NonNull

import io.purchasely.billing.Store
import io.purchasely.ext.*
import io.purchasely.ext.EventListener
import io.purchasely.ext.PLYActionInterceptorCallback
import io.purchasely.ext.PLYInterceptResult
import io.purchasely.ext.PLYInterceptorInfo
import io.purchasely.ext.presentation.PLYPresentationAction
import io.purchasely.ext.presentation.PLYPresentationBase
import io.purchasely.ext.presentation.PLYPresentationMetadata
import io.purchasely.ext.presentation.PLYPresentationOutcome
import io.purchasely.ext.presentation.PLYPresentationType
import io.purchasely.ext.presentation.display
import io.purchasely.ext.presentation.preload
import io.purchasely.models.PLYPlan
import io.purchasely.models.PLYPresentationPlan
import io.purchasely.models.PLYProduct
import kotlinx.coroutines.*
import io.purchasely.ext.Purchasely
import io.purchasely.models.PLYError
import io.purchasely.views.presentation.PLYThemeMode
import io.purchasely.views.presentation.models.PLYDimensionType
import io.purchasely.views.presentation.models.PLYTransition
import io.purchasely.views.presentation.models.PLYTransitionDimension
import io.purchasely.views.presentation.models.PLYTransitionType
import java.text.SimpleDateFormat
import java.util.*
import java.util.concurrent.ConcurrentHashMap
import kotlin.collections.ArrayList
import kotlin.collections.HashMap
import kotlin.reflect.KClass
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
    private lateinit var presentationChannel: EventChannel

    private lateinit var context: Context
    private var activity: Activity? = null

    private val mainHandler = Handler(Looper.getMainLooper())
    private var presentationSink: EventChannel.EventSink?
        get() = activePresentationSink
        set(value) { activePresentationSink = value }

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
            .registerViewFactory(NativeViewFactory.VIEW_TYPE_ID, NativeViewFactory())

        // Presentation/interceptor lifecycle events flow over a dedicated stream,
        // discriminated by the `event` key; each carries a `requestId` so Dart can route back.
        presentationChannel = EventChannel(flutterPluginBinding.binaryMessenger, PRESENTATION_EVENTS_CHANNEL)
        presentationChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                presentationSink = events
            }

            override fun onCancel(arguments: Any?) {
                presentationSink = null
            }
        })
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        @Suppress("UNCHECKED_CAST")
        val args = (call.arguments as? Map<String, Any?>)

        when(call.method) {
            // --- start ---
            "start" -> start(args, result)

            // --- presentation lifecycle ---
            "preload" -> preload(args, result)
            "display" -> display(args, result)
            "close" -> closePresentation(args, result)
            "back" -> back(args, result)

            // --- action interceptor ---
            "registerInterceptor" -> registerInterceptor(args, result)
            "removeInterceptor" -> removeInterceptor(args, result)
            "removeAllInterceptors" -> removeAllInterceptors(result)
            "interceptorResolve" -> interceptorResolve(args, result)

            // --- kept v5 surface ---
            "synchronize" -> synchronize(result)
            "restoreAllProducts" -> restoreAllProducts(result)
            "silentRestoreAllProducts" -> silentRestoreAllProducts(result)
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
            "allowDeeplink" -> {
                allowDeeplink(call.argument<Boolean>("allowDeeplink"))
                result.safeSuccess(true)
            }
            "allowCampaigns" -> {
                allowCampaigns(call.argument<Boolean>("allowCampaigns"))
                result.safeSuccess(true)
            }
            "setDefaultPresentationDismissHandler" -> setDefaultPresentationDismissHandler(result)
            "setLanguage" -> {
                setLanguage(call.argument<String>("language"))
                result.safeSuccess(true)
            }
            "userDidConsumeSubscriptionContent" -> {
                Purchasely.userDidConsumeSubscriptionContent()
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
            "handleDeeplink" -> handleDeeplink(call.argument<String>("deeplink"), result)
            "userSubscriptions" -> launch { userSubscriptions(result) }
            "userSubscriptionsHistory" -> launch { userSubscriptionsHistory(result) }
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
                val debugMode = call.argument<Boolean>("debugMode")
                if (debugMode == null) {
                    result.error("MISSING_PARAMETER", "The 'debugMode' parameter is required.", null)
                    return
                }
                Purchasely.debugMode = debugMode
                result.safeSuccess(true)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    //region start
    private fun logLevelFrom(raw: Any?): LogLevel {
        return when (raw) {
            is Number -> LogLevel.values().getOrElse(raw.toInt()) { LogLevel.ERROR }
            is String -> LogLevel.values().firstOrNull { it.name.equals(raw, ignoreCase = true) } ?: LogLevel.ERROR
            else -> LogLevel.ERROR
        }
    }

    private fun runningModeFrom(raw: Any?): PLYRunningMode {
        return when (raw) {
            is Number -> when (raw.toInt()) {
                3 -> PLYRunningMode.Full
                else -> PLYRunningMode.Observer
            }
            is String -> when (raw.lowercase(Locale.US)) {
                "full" -> PLYRunningMode.Full
                else -> PLYRunningMode.Observer
            }
            else -> PLYRunningMode.Observer
        }
    }

    private fun start(args: Map<String, Any?>?, result: Result) {
        val a = args ?: emptyMap()
        val apiKey = a["apiKey"] as? String
        if (apiKey.isNullOrBlank()) {
            result.safeError("-1", "apiKey must not be null", null)
            return
        }
        val userId = (a["appUserId"] as? String) ?: (a["userId"] as? String)
        val logLevel = logLevelFrom(a["logLevel"])
        val runningMode = runningModeFrom(a["runningMode"])
        val stores = (a["stores"] as? List<*>)?.mapNotNull { it as? String } ?: emptyList()
        val allowDeeplink = a["allowDeeplink"] as? Boolean
        val allowCampaigns = a["allowCampaigns"] as? Boolean ?: true

        Purchasely.Builder(context)
            .apiKey(apiKey)
            .stores(getStoresInstances(stores))
            .logLevel(logLevel)
            .runningMode(runningMode)
            .userId(userId)
            .apply {
                allowDeeplink?.let { this.allowDeeplink(it) }
                this.allowCampaigns(allowCampaigns)
            }
            .build()

        Purchasely.sdkBridgeVersion = "6.0.0-rc.1"
        Purchasely.appTechnology = PLYAppTechnology.FLUTTER

        Purchasely.start { error ->
            if (error == null) {
                result.safeSuccess(true)
            } else {
                result.safeError("0", error.message ?: "Purchasely SDK not configured", error)
            }
        }
    }
    //endregion

    //region Presentation lifecycle
    /**
     * Build a `Prepared` presentation from a Dart-side request map. The map shape mirrors
     * `PresentationRequest.toMap()` in `lib/src/presentation_request.dart`.
     */
    private fun buildPrepared(request: Map<String, Any?>): PLYPresentationBase.Prepared {
        val requestId = request["requestId"] as? String
            ?: error("presentation call missing requestId")
        val source = request["source"] as? Map<*, *>
        val sourceKind = source?.get("kind") as? String ?: "defaultSource"
        val sourceId = source?.get("id") as? String
        val contentId = request["contentId"] as? String
        val backgroundColorHex = request["backgroundColor"] as? String
        val progressColorHex = request["progressColor"] as? String
        val displayCloseButton = request["displayCloseButton"] as? Boolean ?: true
        val displayBackButton = request["displayBackButton"] as? Boolean ?: true

        val builder = PLYPresentationBase.builder().apply {
            when (sourceKind) {
                "placementId" -> sourceId?.let { placementId(it) }
                "screenId" -> sourceId?.let { screenId(it) }
                else -> { /* default source — no id */ }
            }
            contentId(contentId)
            displayCloseButton(displayCloseButton)
            displayBackButton(displayBackButton)
            backgroundColorHex?.let { hex -> tryParseHexColor(hex)?.let { color -> backgroundColor(color) } }
            progressColorHex?.let { hex -> tryParseHexColor(hex)?.let { color -> progressColor(color) } }
            onPresented { presentation, error ->
                emit(eventEnvelope("onPresented", requestId).apply {
                    put("presentation", presentation?.let { presentationToMap(it) })
                    put("error", error?.let { errorToMap(it) })
                })
            }
            onCloseRequested {
                emit(eventEnvelope("onCloseRequested", requestId))
            }
            onDismissed { outcome ->
                displayCallbacks.remove(requestId)
                emit(eventEnvelope("onDismissed", requestId).apply {
                    put("outcome", outcomeToMap(outcome))
                })
            }
        }

        return builder.build().also { preparedRequests[requestId] = it }
    }

    private fun preload(args: Map<String, Any?>?, result: Result) {
        val a = args ?: emptyMap()
        val requestId = a["requestId"] as? String
        if (requestId.isNullOrBlank()) {
            result.safeError("-1", "requestId is required", null)
            return
        }
        val prepared = buildPrepared(a)
        launch {
            try {
                val loaded = prepared.preload()
                loadedPresentations[requestId] = loaded
                emit(eventEnvelope("onLoaded", requestId).apply {
                    put("presentation", presentationToMap(loaded))
                })
                result.safeSuccess(presentationToMap(loaded))
            } catch (t: Throwable) {
                val error = errorToMap(t)
                emit(eventEnvelope("onLoaded", requestId).apply {
                    put("error", error)
                })
                result.safeError("-1", t.message ?: "preload failed", t)
            }
        }
    }

    private fun display(args: Map<String, Any?>?, result: Result) {
        val a = args ?: emptyMap()
        val requestId = a["requestId"] as? String
        if (requestId.isNullOrBlank()) {
            result.safeError("-1", "requestId is required", null)
            return
        }
        val transition = parseTransition(a["transition"] as? Map<*, *>)
        val ctx: Context = activity ?: context

        // The Dart-side Future returned from `display()` resolves at DISMISS — the
        // dismissal callback wired in buildPrepared emits `onDismissed`, which the
        // Dart side listens to on the event channel. `result.success(true)` only
        // confirms the display call was dispatched.
        displayCallbacks[requestId] = { /* outcome handled by emit('onDismissed') */ }

        try {
            // A loaded presentation displays directly; otherwise display from the prepared.
            val loaded = loadedPresentations[requestId]
            if (loaded != null) {
                loaded.display(ctx, transition) { /* outcome emitted via onDismissed */ }
            } else {
                val prepared = preparedRequests[requestId] ?: buildPrepared(a)
                prepared.display(ctx, transition, { /* onLoaded */ }) { /* onDismissed */ }
            }
            result.safeSuccess(true)
        } catch (t: Throwable) {
            displayCallbacks.remove(requestId)
            result.safeError("-1", t.message ?: "display failed", t)
        }
    }

    private fun closePresentation(args: Map<String, Any?>?, result: Result) {
        // The native SDK does not expose per-presentation programmatic close;
        // close all screens regardless of whether a requestId was provided.
        Purchasely.closeAllScreens()
        result.safeSuccess(true)
    }

    private fun back(args: Map<String, Any?>?, result: Result) {
        val requestId = args?.get("requestId") as? String
        val loaded = requestId?.let { loadedPresentations[it] }
        loaded?.back()
        result.safeSuccess(true)
    }
    //endregion

    //region Default presentation dismiss handler
    private fun setDefaultPresentationDismissHandler(result: Result) {
        Purchasely.setDefaultPresentationDismissHandler { outcome: PLYPresentationOutcome ->
            emit(eventEnvelope("onDefaultPresentationDismissed", "").apply {
                put("outcome", outcomeToMap(outcome))
            })
        }
        result.safeSuccess(true)
    }
    //endregion

    //region Action interceptor
    private fun registerInterceptor(args: Map<String, Any?>?, result: Result) {
        val kindWire = args?.get("kind") as? String
        val kindKClass = actionKClassForWire(kindWire)
        if (kindKClass == null) {
            result.safeError("-1", "unknown action kind '$kindWire'", null)
            return
        }
        Purchasely.interceptAction(kindKClass.java, object : PLYActionInterceptorCallback {
            override fun onIntercept(
                info: PLYInterceptorInfo,
                action: PLYPresentationAction,
                completion: (PLYInterceptResult) -> Unit
            ) {
                val id = "ply_ic_${System.nanoTime()}"
                pendingInterceptors[id] = completion
                emit(
                    eventEnvelope("interceptorTriggered", id).apply {
                        put("kind", kindWire)
                        put("info", interceptorInfoToMap(info))
                        put("payload", actionPayloadToMap(action))
                    }
                )
            }
        })
        result.safeSuccess(true)
    }

    private fun removeInterceptor(args: Map<String, Any?>?, result: Result) {
        val kindWire = args?.get("kind") as? String
        val kindKClass = actionKClassForWire(kindWire)
        if (kindKClass != null) {
            Purchasely.removeActionInterceptor(kindKClass.java)
        }
        result.safeSuccess(true)
    }

    private fun removeAllInterceptors(result: Result) {
        Purchasely.removeAllActionInterceptors()
        result.safeSuccess(true)
    }

    private fun interceptorResolve(args: Map<String, Any?>?, result: Result) {
        val id = args?.get("invocationId") as? String
        val value = args?.get("result") as? String
        val ply = when (value) {
            "success" -> PLYInterceptResult.SUCCESS
            "failed" -> PLYInterceptResult.FAILED
            else -> PLYInterceptResult.NOT_HANDLED
        }
        val completion = id?.let { pendingInterceptors.remove(it) }
        activity?.runOnUiThread { completion?.invoke(ply) } ?: completion?.invoke(ply)
        result.safeSuccess(true)
    }

    private fun actionKClassForWire(value: String?): KClass<out PLYPresentationAction>? {
        val backendValue = when (value) {
            "close" -> "close"
            "close_all" -> "close_all"
            "login" -> "login"
            "navigate" -> "navigate"
            "purchase" -> "purchase"
            "restore" -> "restore"
            "open_presentation" -> "open_presentation"
            "open_placement" -> "open_placement"
            "promo_code" -> "promo_code"
            "web_checkout" -> "web_checkout"
            else -> return null
        }
        return PLYPresentationAction.fromValue(backendValue)
    }
    //endregion

    //region Event channel sink
    private fun emit(event: Map<String, Any?>) {
        emitPresentationEvent(event)
    }

    private fun eventEnvelope(event: String, requestId: String): MutableMap<String, Any?> =
        Companion.eventEnvelope(event, requestId)
    //endregion

    //region Presentation serializers
    private fun outcomeToMap(outcome: PLYPresentationOutcome): Map<String, Any?> =
        Companion.outcomeToMap(outcome)

    private fun errorToMap(error: Throwable): Map<String, Any?> {
        return mapOf(
            "code" to error.javaClass.simpleName,
            "message" to error.message,
        )
    }

    private fun interceptorInfoToMap(info: PLYInterceptorInfo): Map<String, Any?> {
        return mapOf(
            "contentId" to info.contentId,
            "presentation" to info.presentation?.let { presentationToMap(it) },
        )
    }

    private fun actionPayloadToMap(action: PLYPresentationAction): Map<String, Any?>? {
        return when (action) {
            is PLYPresentationAction.Navigate -> mapOf(
                "url" to action.url.toString(),
                "title" to action.title,
            )
            is PLYPresentationAction.Purchase -> mapOf(
                "plan" to mapOf(
                    "vendorId" to action.plan.vendorId,
                    "productId" to action.plan.getProductId(),
                    "basePlanId" to action.plan.basePlanId,
                ),
                "subscriptionOffer" to action.subscriptionOffer?.toMap(),
                "offer" to action.offer?.let { offer ->
                    mapOf(
                        "vendorId" to offer.vendorId,
                        "storeOfferId" to offer.storeOfferId,
                        "publicId" to offer.publicId,
                    )
                },
            )
            is PLYPresentationAction.Close -> mapOf("closeReason" to action.closeReason.value)
            is PLYPresentationAction.CloseAll -> mapOf("closeReason" to action.closeReason.value)
            is PLYPresentationAction.OpenPresentation -> mapOf(
                "presentationId" to action.presentationId,
            )
            is PLYPresentationAction.OpenPlacement -> mapOf(
                "placementId" to action.placementId,
            )
            is PLYPresentationAction.WebCheckout -> mapOf(
                "url" to action.url.toString(),
                "clientReferenceId" to action.clientReferenceId,
                "queryParameterKey" to action.queryParameterKey,
                "webCheckoutProvider" to action.webCheckoutProvider.name,
            )
            else -> null
        }
    }

    /**
     * Parses a Dart transition dimension `{ "type": "pixel"|"percentage", "value": <Double> }`
     * into a native [PLYTransitionDimension]. Returns `null` (→ surface default / hug) when
     * absent or malformed.
     */
    private fun parseDimension(raw: Any?): PLYTransitionDimension? {
        val map = raw as? Map<*, *> ?: return null
        val value = (map["value"] as? Number)?.toFloat() ?: return null
        val type = if (map["type"] as? String == "pixel") {
            PLYDimensionType.PIXEL
        } else {
            PLYDimensionType.PERCENTAGE
        }
        return PLYTransitionDimension(type, value)
    }

    private fun parseTransition(map: Map<*, *>?): PLYTransition? {
        if (map == null) return null
        val type = when (map["type"] as? String) {
            "fullScreen" -> PLYTransitionType.FULLSCREEN
            "push" -> PLYTransitionType.PUSH
            "modal" -> PLYTransitionType.MODAL
            "drawer" -> PLYTransitionType.DRAWER
            "popin" -> PLYTransitionType.POPIN
            "inlinePaywall" -> PLYTransitionType.INLINE_PAYWALL
            else -> return null
        }
        val dismissible = map["dismissible"] as? Boolean ?: true
        // v6 models drawer/popin size as PLYTransitionDimension (width is popin-only,
        // height drives drawer + popin). The legacy `heightPercentage` constructor arg
        // is deprecated and intentionally not set.
        val width = parseDimension(map["width"])
        val height = parseDimension(map["height"])
        return PLYTransition(
            type = type,
            width = width,
            height = height,
            dismissible = dismissible,
        )
    }

    private fun tryParseHexColor(hex: String): Int? {
        return try {
            val cleaned = hex.trim().removePrefix("#")
            val full = if (cleaned.length == 6) "FF$cleaned" else cleaned
            full.toLong(16).toInt()
        } catch (_: Throwable) {
            null
        }
    }
    //endregion

    //region Purchasely
    private fun restoreAllProducts(result: Result) {
        Purchasely.restoreAllProducts(
            onSuccess = {
                result.safeSuccess(true)
            },
            onError = { error ->
                error?.let {
                    result.safeError("-1", it.message, it)
                } ?: let {
                    result.safeError("-1", "Unknown error", null)
                }
            }
        )
    }

    private fun silentRestoreAllProducts(result: Result) {
        Purchasely.silentRestoreAllProducts(
            onSuccess = {
                result.safeSuccess(true)
            },
            onError = { error ->
                error?.let {
                    result.safeError("-1", it.message, it)
                } ?: let {
                    result.safeError("-1", "Unknown error", null)
                }
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
        Purchasely.userLogout(true)
    }

    private fun setLogLevel(logLevel: Int?) {
        Purchasely.logLevel = LogLevel.values()[logLevel ?: 0]
    }

    private fun allowDeeplink(allowDeeplink: Boolean?) {
        Purchasely.allowDeeplink = allowDeeplink ?: true
    }

    private fun allowCampaigns(allowCampaigns: Boolean?) {
        Purchasely.allowCampaigns = allowCampaigns ?: true
    }

    private fun synchronize(result: Result) {
        // v6 exposes onSuccess/onError callbacks on synchronize(). The Dart
        // `Purchasely.synchronize()` Future now resolves once the receipt
        // synchronisation completes (and errors via PlatformException) instead
        // of the old fire-and-forget behaviour.
        Purchasely.synchronize(
            onSuccess = { result.safeSuccess(true) },
            onError = { error ->
                result.safeError("-1", error?.message ?: "Synchronization failed", error)
            }
        )
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

    private fun handleDeeplink(deeplink: String?, result: Result) {
        if (deeplink == null) {
            result.safeError("-1", "Deeplink must not be null", null)
            return
        }
        val uri = Uri.parse(deeplink)
        result.safeSuccess(Purchasely.handleDeeplink(uri, activity))
    }

    private fun displaySubscriptionCancellationInstruction() {
        // The native Android v6 SDK removed the built-in cancellation survey UI.
        Log.w("Purchasely", "displaySubscriptionCancellationInstruction is no longer supported by the Android v6 SDK")
    }

    private suspend fun userSubscriptions(result: Result) {
        try {
            val subscriptions = Purchasely.userSubscriptions(true)
            result.safeSuccess(transformSubscriptionsToList(subscriptions))
        } catch (e: Exception) {
            result.safeError("-1", e.message, e)
        }
    }

    private suspend fun userSubscriptionsHistory(result: Result) {
        try {
            val subscriptions = Purchasely.userSubscriptionsHistory(true)
            result.safeSuccess(transformSubscriptionsToList(subscriptions))
        } catch (e: Exception) {
            result.safeError("-1", e.message, e)
        }
    }

    private fun transformSubscriptionsToList(subscriptions: List<io.purchasely.models.PLYSubscriptionData>): ArrayList<MutableMap<String, Any?>> {
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
        }
        return list
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

    private suspend fun isEligibleForIntroOffer(planVendorId: String) : Boolean {
        return try {
            val plan = Purchasely.plan(planVendorId)
            if(plan != null) {
                plan.isEligibleToOffer(null)
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
        stores.orEmpty().forEach { store ->
            val className = when (store.lowercase(Locale.US)) {
                "google" -> "io.purchasely.google.GoogleStore"
                "huawei" -> "io.purchasely.huawei.HuaweiStore"
                "amazon" -> "io.purchasely.amazon.AmazonStore"
                else -> null
            }
            if (className != null) {
                try {
                    result.add(Class.forName(className).getDeclaredConstructor().newInstance() as Store)
                } catch (e: Exception) {
                    Log.e("Purchasely", "$store Store not found: ${e.message}", e)
                }
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
        private const val PRESENTATION_EVENTS_CHANNEL = "purchasely-presentation-events"

        private lateinit var channel : MethodChannel

        // The live presentation-events sink shared by the full-screen path and the
        // inline NativeView, plus a main-thread handler to post onto it. The inline
        // view emits its onDismissed envelope through `emitPresentationEvent` so it
        // is byte-for-byte identical to the full-screen path.
        @Volatile
        private var activePresentationSink: EventChannel.EventSink? = null
        private val presentationHandler = Handler(Looper.getMainLooper())

        // Prepared/loaded presentations keyed by Dart requestId. They are retained after
        // dismissal so a Dart Presentation handle can be displayed again and so the inline
        // platform view can resolve a preloaded requestId. There is no native dispose API yet.
        val preparedRequests = ConcurrentHashMap<String, PLYPresentationBase.Prepared>()
        val loadedPresentations = ConcurrentHashMap<String, PLYPresentationBase.Loaded>()
        val displayCallbacks = ConcurrentHashMap<String, (PLYPresentationOutcome) -> Unit>()

        /**
         * Posts a presentation lifecycle envelope onto the shared
         * `purchasely-presentation-events` sink. Used by the inline NativeView so
         * the embedded path surfaces the same `{ event, requestId, outcome }`
         * envelopes as the full-screen path.
         */
        fun emitPresentationEvent(event: Map<String, Any?>) {
            presentationHandler.post {
                activePresentationSink?.success(event)
            }
        }

        /** Builds the base `{ event, requestId }` envelope shared by all callers. */
        fun eventEnvelope(event: String, requestId: String): MutableMap<String, Any?> {
            return mutableMapOf<String, Any?>(
                "event" to event,
                "requestId" to requestId,
            )
        }

        /**
         * Serializes a presentation outcome to the wire shape consumed by the Dart
         * façade. Shared by the full-screen and inline paths so both are identical.
         */
        fun outcomeToMap(outcome: PLYPresentationOutcome): Map<String, Any?> {
            return mapOf(
                "presentation" to outcome.presentation?.let { presentationToMap(it) },
                "purchaseResult" to outcome.purchaseResult?.name?.lowercase(),
                // Serialize the full PLYPlan (same shape as products/plans elsewhere)
                // so the Dart side parses it into a fully-typed PLYPlan via plyPlanFromMap.
                "plan" to outcome.plan?.let { transformPlanToMap(it) },
                "closeReason" to outcome.closeReason?.value,
                "error" to outcome.error?.let { errorToMap(it) },
            )
        }

        private fun presentationToMap(p: PLYPresentationBase.Loaded): Map<String, Any?> {
            return mapOf(
                "screenId" to p.screenId,
                "placementId" to p.placementId,
                "contentId" to p.contentId,
                "audienceId" to p.audienceId,
                "abTestId" to p.abTestId,
                "abTestVariantId" to p.abTestVariantId,
                "campaignId" to p.campaignId,
                "flowId" to p.flowId,
                "language" to p.language,
                "type" to p.type.ordinal,
                "height" to p.height,
                "plans" to p.plans.map { plan -> presentationPlanToMap(plan) },
            )
        }

        private fun presentationPlanToMap(plan: PLYPresentationPlan): Map<String, Any?> {
            return mapOf(
                "planVendorId" to plan.planVendorId,
                "storeProductId" to plan.storeProductId,
                "basePlanId" to plan.basePlanId,
                "offerId" to plan.storeOfferId,
            )
        }

        private fun errorToMap(error: PLYError): Map<String, Any?> {
            return mapOf(
                "code" to "PLYError",
                "message" to error.message,
            )
        }

        // Pending interceptor invocations awaiting Dart resolution, keyed by the
        // invocation id (`ply_ic_<nanos>`) sent to Dart so `interceptorResolve`
        // can route to the right SDK completion.
        val pendingInterceptors = ConcurrentHashMap<String, (PLYInterceptResult) -> Unit>()

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
