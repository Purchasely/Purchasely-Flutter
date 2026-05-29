package io.purchasely.purchasely_flutter

import android.app.Activity
import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import io.purchasely.billing.Store
import io.purchasely.ext.LogLevel
import io.purchasely.ext.PLYAppTechnology
import io.purchasely.ext.PLYInterceptResult
import io.purchasely.ext.PLYInterceptorInfo
import io.purchasely.ext.PLYRunningMode
import io.purchasely.ext.Purchasely
import io.purchasely.ext.presentation.PLYPresentation
import io.purchasely.ext.presentation.PLYPresentationAction
import io.purchasely.ext.presentation.PLYPresentationBase
import io.purchasely.ext.presentation.PLYPresentationOutcome
import io.purchasely.ext.presentation.preload
import io.purchasely.views.presentation.models.PLYTransition
import io.purchasely.views.presentation.models.PLYTransitionType
import java.util.concurrent.ConcurrentHashMap
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlin.reflect.KClass

/**
 * v6 bridge — wires the Dart-side v6 façade (`lib/src/`) to the v6 Purchasely
 * Android SDK (Builder DSL, PLYPresentationBase, interceptAction…).
 *
 * Wiring contract (cf. `reports/v6-presentation-comparison-v3-claude/BRIDGE-CONTRACT.md`):
 *  - Methods are dispatched from the shared `purchasely` MethodChannel with the
 *    `v6/` prefix (e.g. `v6/start`, `v6/preload`, `v6/display`).
 *  - Lifecycle callbacks (`onLoaded`, `onPresented`, `onCloseRequested`,
 *    `onDismissed`) and interceptor invocations are emitted on the dedicated
 *    `purchasely/v6-events` EventChannel — one stream, discriminated by the
 *    `event` key. Each event carries `requestId` so Dart can route back.
 *  - Interceptor `success/failed/notHandled` replies come back via the
 *    `v6/interceptorResolve` method call.
 */
internal class PurchaselyV6Bridge(
    private val context: Context,
    private val activitySupplier: () -> Activity?,
    private val coroutineScope: CoroutineScope = CoroutineScope(SupervisorJob() + Dispatchers.Main),
) {

    // --- Event channel sink ----------------------------------------------------

    private val mainHandler = Handler(Looper.getMainLooper())
    private var eventSink: EventChannel.EventSink? = null

    fun attachEventChannel(channel: EventChannel) {
        channel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
            }

            override fun onCancel(arguments: Any?) {
                eventSink = null
            }
        })
    }

    private fun emit(event: Map<String, Any?>) {
        mainHandler.post {
            eventSink?.success(event)
        }
    }

    // --- Loaded presentations & interceptor state -----------------------------

    private val preparedRequests = ConcurrentHashMap<String, PLYPresentationBase.Prepared>()
    private val loadedPresentations = ConcurrentHashMap<String, PLYPresentation>()
    private val displayCallbacks = ConcurrentHashMap<String, (PLYPresentationOutcome) -> Unit>()

    // Pending interceptor invocations awaiting Dart resolution.
    // Keyed by the invocation id (`ply_ic_<nanos>`) sent to Dart so the
    // `v6/interceptorResolve` reply can route to the right SDK completion.
    private val pendingInterceptorsByInvocationId = ConcurrentHashMap<String, PendingInterceptor>()

    // --- Method dispatch ------------------------------------------------------

    /**
     * Returns `true` if the method was handled by the v6 bridge.
     */
    fun handle(method: String, arguments: Map<String, Any?>?, result: MethodChannel.Result): Boolean {
        return when (method) {
            "v6/start" -> { v6Start(arguments, result); true }
            "v6/preload" -> { v6Preload(arguments, result); true }
            "v6/display" -> { v6Display(arguments, result); true }
            "v6/close" -> { v6Close(arguments, result); true }
            "v6/back" -> { v6Back(arguments, result); true }
            "v6/registerInterceptor" -> { v6RegisterInterceptor(arguments, result); true }
            "v6/removeInterceptor" -> { v6RemoveInterceptor(arguments, result); true }
            "v6/removeAllInterceptors" -> { v6RemoveAllInterceptors(result); true }
            "v6/interceptorResolve" -> { v6InterceptorResolve(arguments, result); true }
            else -> false
        }
    }

    // --- start ----------------------------------------------------------------

    private fun v6Start(args: Map<String, Any?>?, result: MethodChannel.Result) {
        val a = args ?: emptyMap()
        val apiKey = a["apiKey"] as? String
        if (apiKey.isNullOrBlank()) {
            result.error("ARG_INVALID", "apiKey is required", null)
            return
        }
        val appUserId = a["appUserId"] as? String
        val runningMode = when (a["runningMode"] as? String) {
            "full" -> PLYRunningMode.Full
            else -> PLYRunningMode.Observer
        }
        val logLevel = when (a["logLevel"] as? String) {
            "debug" -> LogLevel.DEBUG
            "info" -> LogLevel.INFO
            "warn" -> LogLevel.WARN
            else -> LogLevel.ERROR
        }
        val allowDeeplink = a["allowDeeplink"] as? Boolean
        val allowCampaigns = a["allowCampaigns"] as? Boolean ?: true
        val storesList = (a["stores"] as? List<*>)?.mapNotNull { it as? String } ?: emptyList()

        try {
            val builder = Purchasely.Builder(context)
                .apiKey(apiKey)
                .logLevel(logLevel)
                .runningMode(runningMode)
                .allowCampaigns(allowCampaigns)
                .stores(resolveStores(storesList))
            if (!appUserId.isNullOrBlank()) builder.userId(appUserId)
            if (allowDeeplink != null) builder.allowDeeplink(allowDeeplink)
            builder.build()
            Purchasely.appTechnology = PLYAppTechnology.FLUTTER
            Purchasely.start { error ->
                if (error == null) {
                    result.success(true)
                } else {
                    result.error("V6_START", error.message ?: "Purchasely start failed", error.toString())
                }
            }
        } catch (t: Throwable) {
            result.error("V6_START", t.message ?: "Purchasely start crashed", t.toString())
        }
    }

    private fun resolveStores(stores: List<String>): List<Store> {
        // Reflective resolution mirrors the v5 path — purchasely_google/huawei/amazon
        // are optional Maven artifacts; only include the ones the host app pulled in.
        val out = mutableListOf<Store>()
        stores.forEach { name ->
            val fqcn = when (name) {
                "google" -> "io.purchasely.google.GoogleStore"
                "huawei" -> "io.purchasely.huawei.HuaweiStore"
                "amazon" -> "io.purchasely.amazon.AmazonStore"
                else -> null
            } ?: return@forEach
            try {
                out.add(Class.forName(fqcn).getDeclaredConstructor().newInstance() as Store)
            } catch (_: Throwable) {
                // Store dependency not present — silently skip, matching v5 behaviour.
            }
        }
        return out
    }

    // --- Presentation lifecycle ----------------------------------------------

    /**
     * Build a `Prepared` from a Dart-side request map. The map shape mirrors
     * `PresentationRequest.toMap()` in `lib/src/presentation_request.dart`.
     */
    private fun buildPrepared(request: Map<String, Any?>): PLYPresentationBase.Prepared {
        val requestId = request["requestId"] as? String
            ?: error("v6/* call missing requestId")
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
                val callback = displayCallbacks.remove(requestId)
                callback?.invoke(outcome)
                emit(eventEnvelope("onDismissed", requestId).apply {
                    put("outcome", outcomeToMap(outcome))
                })
            }
        }

        return builder.build().also { preparedRequests[requestId] = it }
    }

    private fun v6Preload(args: Map<String, Any?>?, result: MethodChannel.Result) {
        val a = args ?: emptyMap()
        val requestId = a["requestId"] as? String
        if (requestId.isNullOrBlank()) {
            result.error("ARG_INVALID", "requestId is required", null)
            return
        }
        val prepared = buildPrepared(a)
        coroutineScope.launch {
            try {
                val loaded = prepared.preload()
                loadedPresentations[requestId] = loaded
                emit(eventEnvelope("onLoaded", requestId).apply {
                    put("presentation", presentationToMap(loaded))
                })
                result.success(presentationToMap(loaded))
            } catch (t: Throwable) {
                val error = t.toPLYErrorMap()
                emit(eventEnvelope("onLoaded", requestId).apply {
                    put("error", error)
                })
                result.error("V6_PRELOAD", t.message ?: "preload failed", error)
            }
        }
    }

    private fun v6Display(args: Map<String, Any?>?, result: MethodChannel.Result) {
        val a = args ?: emptyMap()
        val requestId = a["requestId"] as? String
        if (requestId.isNullOrBlank()) {
            result.error("ARG_INVALID", "requestId is required", null)
            return
        }
        val transition = parseTransition(a["transition"] as? Map<*, *>)

        val prepared = preparedRequests[requestId] ?: buildPrepared(a)
        val ctx: Context = activitySupplier() ?: context

        // The Dart-side Future returned from `display()` resolves at DISMISS — we
        // register the dismissal callback here and let onDismissed (set during
        // buildPrepared) invoke it. Result.success(true) confirms the display
        // call was dispatched, but the Dart `.display()` Future actually awaits
        // the dismiss event sent on the EventChannel.
        displayCallbacks[requestId] = { /* outcome handled by emit('onDismissed') */ }

        try {
            prepared.display(ctx, transition) { outcome ->
                // PLY SDK delivers final outcome here — emit onDismissed (already
                // wired in buildPrepared.onDismissed). The Dart side listens to
                // the event channel rather than awaiting this completion.
            }
            result.success(true)
        } catch (t: Throwable) {
            result.error("V6_DISPLAY", t.message ?: "display failed", t.toPLYErrorMap())
        }
    }

    private fun v6Close(args: Map<String, Any?>?, result: MethodChannel.Result) {
        // The v6 Android SDK does not expose per-presentation programmatic close;
        // close all screens regardless of whether a requestId was provided.
        Purchasely.closeAllScreens()
        result.success(true)
    }

    private fun v6Back(args: Map<String, Any?>?, result: MethodChannel.Result) {
        val requestId = args?.get("requestId") as? String
        val loaded = requestId?.let { loadedPresentations[it] }
        loaded?.back()
        result.success(true)
    }

    // --- Interceptors ---------------------------------------------------------

    private fun v6RegisterInterceptor(args: Map<String, Any?>?, result: MethodChannel.Result) {
        val kindWire = args?.get("kind") as? String
        val kindKClass = actionKClassForWire(kindWire)
        if (kindKClass == null) {
            result.error("ARG_INVALID", "unknown action kind '$kindWire'", null)
            return
        }
        // Use the Java-style callback overload (public). Wraps our coroutine
        // suspension into the SDK's `(info, action, completion) -> Unit` shape.
        Purchasely.interceptAction(kindKClass.java) { info, action, completion ->
            val id = "ply_ic_${System.nanoTime()}"
            val pending = PendingInterceptor(completion)
            pendingInterceptorsByInvocationId[id] = pending
            emit(
                eventEnvelope("interceptorTriggered", id).apply {
                    put("kind", kindWire)
                    put("info", interceptorInfoToMap(info))
                    put("payload", actionPayloadToMap(action))
                }
            )
        }
        result.success(true)
    }

    private class PendingInterceptor(
        val completion: (PLYInterceptResult) -> Unit,
    )

    private fun v6RemoveInterceptor(args: Map<String, Any?>?, result: MethodChannel.Result) {
        val kindWire = args?.get("kind") as? String
        val kindKClass = actionKClassForWire(kindWire)
        if (kindKClass != null) {
            Purchasely.removeActionInterceptor(kindKClass.java)
        }
        result.success(true)
    }

    private fun v6RemoveAllInterceptors(result: MethodChannel.Result) {
        Purchasely.removeAllActionInterceptors()
        result.success(true)
    }

    private fun v6InterceptorResolve(args: Map<String, Any?>?, result: MethodChannel.Result) {
        val id = args?.get("invocationId") as? String
        val value = args?.get("result") as? String
        val ply = when (value) {
            "success" -> PLYInterceptResult.SUCCESS
            "failed" -> PLYInterceptResult.FAILED
            else -> PLYInterceptResult.NOT_HANDLED
        }
        val pending = id?.let { pendingInterceptorsByInvocationId.remove(it) }
        pending?.completion?.invoke(ply)
        result.success(true)
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

    // --- Serializers ----------------------------------------------------------

    private fun presentationToMap(p: PLYPresentation): Map<String, Any?> {
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
            "plans" to p.plans.map { plan ->
                mapOf(
                    "planVendorId" to plan.planVendorId,
                    "storeProductId" to plan.storeProductId,
                    "basePlanId" to plan.basePlanId,
                    "offerId" to plan.offerId,
                )
            },
        )
    }

    private fun outcomeToMap(outcome: PLYPresentationOutcome): Map<String, Any?> {
        return mapOf(
            "presentation" to outcome.presentation?.let { presentationToMap(it) },
            "purchaseResult" to outcome.purchaseResult?.name?.lowercase(),
            "plan" to outcome.plan?.let { plan ->
                mapOf(
                    "vendorId" to plan.vendorId,
                    "productId" to plan.getProductId(),
                    "basePlanId" to plan.basePlanId,
                )
            },
            "closeReason" to outcome.closeReason?.value,
            "error" to outcome.error?.let { errorToMap(it) },
        )
    }

    private fun errorToMap(error: Throwable): Map<String, Any?> {
        return mapOf(
            "code" to error.javaClass.simpleName,
            "message" to error.message,
        )
    }

    private fun Throwable.toPLYErrorMap(): Map<String, Any?> = errorToMap(this)

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
            is PLYPresentationAction.Login,
            is PLYPresentationAction.Restore,
            is PLYPresentationAction.PromoCode -> null
            else -> null
        }
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
        val heightPercentage = (map["heightPercentage"] as? Number)?.toFloat()
        val dismissible = map["dismissible"] as? Boolean ?: true
        return PLYTransition(
            type = type,
            heightPercentage = heightPercentage,
            dismissible = dismissible,
            backgroundColors = null,
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

    private fun eventEnvelope(event: String, requestId: String): MutableMap<String, Any?> {
        return mutableMapOf<String, Any?>(
            "event" to event,
            "requestId" to requestId,
        )
    }
}
