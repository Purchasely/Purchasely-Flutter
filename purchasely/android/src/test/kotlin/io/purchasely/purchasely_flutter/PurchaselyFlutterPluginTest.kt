package io.purchasely.purchasely_flutter

import android.app.Activity
import android.content.Context
import android.net.Uri
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.mockk.MockKAnnotations
import io.mockk.every
import io.mockk.impl.annotations.MockK
import io.mockk.mockk
import io.mockk.mockkStatic
import io.mockk.unmockkAll
import io.mockk.verify
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.setMain
import io.purchasely.ext.StoreType
import io.purchasely.models.PLYPlan
import io.purchasely.models.PLYProduct
import io.purchasely.models.PLYSubscriptionData
import io.purchasely.models.PLYWebRedemptionContext
import io.purchasely.models.PLYWebRedemptionResult
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.nio.file.Files
import java.util.UUID

@OptIn(ExperimentalCoroutinesApi::class)
class PurchaselyFlutterPluginTest {

    private lateinit var plugin: PurchaselyFlutterPlugin

    @MockK(relaxed = true)
    private lateinit var mockFlutterPluginBinding: FlutterPlugin.FlutterPluginBinding

    @MockK(relaxed = true)
    private lateinit var mockBinaryMessenger: BinaryMessenger

    @MockK(relaxed = true)
    private lateinit var mockContext: Context

    @MockK(relaxed = true)
    private lateinit var mockResult: MethodChannel.Result

    @MockK(relaxed = true)
    private lateinit var mockActivity: Activity

    @MockK(relaxed = true)
    private lateinit var mockActivityBinding: ActivityPluginBinding

    @Before
    fun setUp() {
        // The plugin is a CoroutineScope and the native start() path touches
        // Dispatchers.Main; provide a test main dispatcher so JVM unit tests can
        // drive onMethodCall("start", ...) without the missing-main crash.
        Dispatchers.setMain(UnconfinedTestDispatcher())
        MockKAnnotations.init(this, relaxed = true)
        plugin = PurchaselyFlutterPlugin()

        every { mockFlutterPluginBinding.binaryMessenger } returns mockBinaryMessenger
        every { mockFlutterPluginBinding.applicationContext } returns mockContext
        every { mockFlutterPluginBinding.platformViewRegistry } returns mockk(relaxed = true)
        every { mockActivityBinding.activity } returns mockActivity

        // `Purchasely.Builder.build()` reaches NetworkService, which builds an OkHttp cache
        // from `context.cacheDir`. A relaxed mock returns null there and the SDK throws an
        // NPE inside `File(parent, child)`. Only the FIRST build() in the JVM hits it —
        // `setEnvironment` resets the network once — so without this stub the start tests
        // pass or fail depending on JUnit's method order. Give it a real temp dir.
        val cacheDir = Files.createTempDirectory("ply-flutter-test").toFile()
        every { mockContext.cacheDir } returns cacheDir
        every { mockContext.filesDir } returns cacheDir
        every { mockContext.applicationContext } returns mockContext
    }

    @After
    fun tearDown() {
        PurchaselyFlutterPlugin.preparedRequests.clear()
        PurchaselyFlutterPlugin.loadedPresentations.clear()
        PurchaselyFlutterPlugin.displayCallbacks.clear()
        PurchaselyFlutterPlugin.pendingInterceptors.clear()
        Dispatchers.resetMain()
        unmockkAll()
    }

    @Test
    fun `onAttachedToEngine sets up channels`() {
        plugin.onAttachedToEngine(mockFlutterPluginBinding)

        verify { mockFlutterPluginBinding.binaryMessenger }
        verify { mockFlutterPluginBinding.applicationContext }
    }

    @Test
    fun `onDetachedFromEngine cleans up without throwing`() {
        plugin.onAttachedToEngine(mockFlutterPluginBinding)

        plugin.onDetachedFromEngine(mockFlutterPluginBinding)
    }

    @Test
    fun `onAttachedToActivity stores activity binding`() {
        plugin.onAttachedToActivity(mockActivityBinding)

        verify { mockActivityBinding.activity }
    }

    @Test
    fun `unknown method is not implemented`() {
        plugin.onAttachedToEngine(mockFlutterPluginBinding)

        plugin.onMethodCall(MethodCall("unknownMethod", null), mockResult)

        verify { mockResult.notImplemented() }
    }

    @Test
    fun `start without apiKey returns argument error`() {
        plugin.onAttachedToEngine(mockFlutterPluginBinding)

        plugin.onMethodCall(MethodCall("start", mapOf<String, Any?>()), mockResult)

        verify { mockResult.error("-1", "apiKey must not be null", null) }
    }

    @Test
    fun `preload without requestId returns argument error`() {
        plugin.onAttachedToEngine(mockFlutterPluginBinding)

        plugin.onMethodCall(MethodCall("preload", mapOf<String, Any?>()), mockResult)

        verify { mockResult.error("-1", "requestId is required", null) }
    }

    @Test
    fun `display without requestId returns argument error`() {
        plugin.onAttachedToEngine(mockFlutterPluginBinding)

        plugin.onMethodCall(MethodCall("display", mapOf<String, Any?>()), mockResult)

        verify { mockResult.error("-1", "requestId is required", null) }
    }

    @Test
    fun `getBuiltInAttribute without key returns argument error instead of hanging`() {
        // Regression guard: a missing "key" must complete the Dart Future with an
        // error, not `return` silently and leave the awaited call hanging forever.
        plugin.onAttachedToEngine(mockFlutterPluginBinding)

        plugin.onMethodCall(
            MethodCall("getBuiltInAttribute", mapOf<String, Any?>()),
            mockResult,
        )

        verify { mockResult.error("MISSING_PARAMETER", "The 'key' parameter is required.", null) }
    }

    @Test
    fun `registerInterceptor rejects unknown action kind`() {
        plugin.onAttachedToEngine(mockFlutterPluginBinding)

        plugin.onMethodCall(
            MethodCall("registerInterceptor", mapOf("kind" to "unknown_action")),
            mockResult,
        )

        verify { mockResult.error("-1", "unknown action kind 'unknown_action'", null) }
    }

    @Test
    fun `start reads the cold-start deeplink arg and routes it to the native builder`() {
        // Proves the wire contract end-to-end on the native side: the bridge
        // reads the `deeplink` key from the start payload, parses it, and hands
        // the Uri to Purchasely.Builder.handleDeeplink(uri) BEFORE start(). The
        // Uri.parse(...) verify fires only if the cold-start branch executed —
        // i.e. the Dart `.handleDeeplink(...)` instruction was received and
        // taken into account, not silently dropped.
        mockkStatic(Uri::class)
        val uri = mockk<Uri>(relaxed = true)
        every { Uri.parse(any()) } returns uri

        plugin.onAttachedToEngine(mockFlutterPluginBinding)
        plugin.onMethodCall(
            MethodCall(
                "start",
                mapOf(
                    "apiKey" to "test-key",
                    "deeplink" to "app://ply/presentations/onboarding",
                ),
            ),
            mockResult,
        )

        verify { Uri.parse("app://ply/presentations/onboarding") }
    }

    @Test
    fun `start without a deeplink never touches Uri parse`() {
        mockkStatic(Uri::class)

        plugin.onAttachedToEngine(mockFlutterPluginBinding)
        plugin.onMethodCall(
            MethodCall("start", mapOf("apiKey" to "test-key")),
            mockResult,
        )

        verify(exactly = 0) { Uri.parse(any()) }
    }

    @Test
    fun `handleDeeplink without deeplink returns argument error`() {
        plugin.onAttachedToEngine(mockFlutterPluginBinding)

        plugin.onMethodCall(MethodCall("handleDeeplink", mapOf<String, Any?>()), mockResult)

        verify { mockResult.error("-1", "Deeplink must not be null", null) }
    }

    @Test
    fun `synchronize routes to the native callback and surfaces its result`() {
        // The 6.0 native SDK resolves synchronize() through onSuccess/onError
        // callbacks. With no store configured (fresh plugin, no Builder), the
        // SDK invokes onError(PLYError.NoStoreConfigured) synchronously, which
        // the bridge must surface as a result error rather than the old
        // fire-and-forget result.success(true). This proves the callback is
        // wired end-to-end without mocking the @JvmStatic SDK entry point.
        plugin.onMethodCall(MethodCall("synchronize", null), mockResult)

        verify { mockResult.error(eq("-1"), any(), any()) }
    }

    // region Web2App redemption + anonymous user id (6.1.0)

    @Test
    fun `parseCanonicalUuid accepts a canonical uuid, case-insensitively`() {
        val lower = "3f2504e0-4f89-11d3-9a0c-0305e82c3301"
        assertEquals(UUID.fromString(lower), parseCanonicalUuid(lower))
        assertEquals(UUID.fromString(lower), parseCanonicalUuid(lower.uppercase()))
    }

    @Test
    fun `parseCanonicalUuid refuses the short form UUID fromString accepts`() {
        // `UUID.fromString` is lenient and parses this; `NSUUID` on iOS refuses it.
        // The round-trip check makes both bridges agree on what "canonical" means.
        assertNull(parseCanonicalUuid("1-2-3-4-5"))
    }

    @Test
    fun `parseCanonicalUuid refuses junk and null`() {
        assertNull(parseCanonicalUuid("not-a-uuid"))
        assertNull(parseCanonicalUuid(""))
        assertNull(parseCanonicalUuid(null))
    }

    @Test
    fun `webRedemptionResultToMap flattens a success with no context`() {
        val map = webRedemptionResultToMap(
            PLYWebRedemptionResult.Success(context = null, replay = true)
        )

        assertEquals(true, map["isSuccess"])
        assertNull(map["context"])
        assertEquals(true, map["replay"])
        assertNull(map["errorCode"])
        assertNull(map["errorMessage"])
    }

    @Test
    fun `webRedemptionResultToMap keeps a present context with a null subscription`() {
        // A success can carry a context that describes no subscription: the receipt
        // validated but the response carried none. Both levels stay separately nullable.
        val map = webRedemptionResultToMap(
            PLYWebRedemptionResult.Success(
                context = PLYWebRedemptionContext(subscription = null),
                replay = false,
            )
        )

        @Suppress("UNCHECKED_CAST")
        val context = map["context"] as Map<String, Any?>?
        assertNotNull(context)
        assertTrue(context!!.containsKey("subscription"))
        assertNull(context["subscription"])
        assertEquals(false, map["replay"])
    }

    @Test
    fun `webRedemptionResultToMap flattens a failure to the same 5 keys`() {
        val map = webRedemptionResultToMap(
            PLYWebRedemptionResult.Failure(
                errorCode = "EXPIRED_REDEMPTION_TOKEN",
                errorMessage = "A new link was sent to j***@example.com.",
            )
        )

        assertEquals(false, map["isSuccess"])
        assertNull(map["context"])
        // A failure still reports `replay = false`, which keeps the Dart shape stable.
        assertEquals(false, map["replay"])
        assertEquals("EXPIRED_REDEMPTION_TOKEN", map["errorCode"])
        assertEquals("A new link was sent to j***@example.com.", map["errorMessage"])
        assertEquals(
            setOf("isSuccess", "context", "replay", "errorCode", "errorMessage"),
            map.keys,
        )
    }

    // endregion

    // region proxy: the three states (6.1.0)

    // `proxy(null)` is a supported CLEAR on the native builder, so the bridge has to keep
    // "never called", "cleared" and "set" apart. Collapsing either pair is silent: an absent
    // key read as null turns every start into an implicit clear, and a null read as absent
    // makes an explicit clear do nothing. That second one is the bug the React Native bridge
    // shipped with.

    @Test
    fun `proxyDecisionFrom leaves the setting untouched when the key is absent`() {
        assertEquals(ProxyDecision.Untouched, proxyDecisionFrom(mapOf("apiKey" to "k")))
    }

    @Test
    fun `proxyDecisionFrom reads a present null as an explicit clear`() {
        assertEquals(
            ProxyDecision.Apply(null),
            proxyDecisionFrom(mapOf("proxy" to null)),
        )
    }

    @Test
    fun `proxyDecisionFrom forwards a url string verbatim`() {
        assertEquals(
            ProxyDecision.Apply("https://svc.purchasely.io"),
            proxyDecisionFrom(mapOf("proxy" to "https://svc.purchasely.io")),
        )
    }

    @Test
    fun `proxyDecisionFrom does not validate the scheme or the host`() {
        // The native SDK refuses a non-https value, a value with no host and a value
        // carrying a query/fragment/credentials, logs it and keeps the production host.
        // The bridge must not pre-judge any of that, or the two platforms disagree.
        assertEquals(
            ProxyDecision.Apply("http://insecure.example"),
            proxyDecisionFrom(mapOf("proxy" to "http://insecure.example")),
        )
        assertEquals(
            ProxyDecision.Apply(""),
            proxyDecisionFrom(mapOf("proxy" to "")),
        )
    }

    @Test
    fun `proxyDecisionFrom refuses a non-string value instead of clearing`() {
        // Invalid must never become Apply(null): a bad value would then silently disable a
        // proxy the app explicitly asked for.
        val decision = proxyDecisionFrom(mapOf("proxy" to 42))
        assertTrue(decision is ProxyDecision.Invalid)
        assertEquals(42, (decision as ProxyDecision.Invalid).raw)
    }

    @Test
    fun `proxyDecisionFrom keeps never-called and cleared distinguishable`() {
        // Asserted against each other, because that is the pair a collapsing bridge
        // renders identical.
        val never = proxyDecisionFrom(emptyMap())
        val cleared = proxyDecisionFrom(mapOf("proxy" to null))
        assertNotEquals(never, cleared)
    }

    @Test
    fun `start with an explicit proxy clear does not surface an argument error`() {
        plugin.onAttachedToEngine(mockFlutterPluginBinding)

        plugin.onMethodCall(
            MethodCall("start", mapOf("apiKey" to "test-key", "proxy" to null)),
            mockResult,
        )

        // A clear is a supported operation, not a bad argument.
        verify(exactly = 0) { mockResult.error(eq("-1"), any(), any()) }
    }

    // endregion

    // region subscription mapping shared by userSubscriptions and the redemption context

    /** A [PLYSubscriptionData] whose three parts are stubbed, so no org.json is needed. */
    private fun stubbedSubscriptionData(storeType: StoreType): PLYSubscriptionData {
        val subscription = mockk<io.purchasely.models.PLYSubscription>(relaxed = true)
        every { subscription.toMap() } returns mapOf(
            "purchaseToken" to "token-1",
            "subscription_status" to "ACTIVE",
        )
        every { subscription.storeType } returns storeType
        every { subscription.plan } returns null

        val resolvedPlan = mockk<PLYPlan>(relaxed = true)
        every { resolvedPlan.vendorId } returns "plan_monthly"
        every { resolvedPlan.name } returns "Monthly"

        val product = mockk<PLYProduct>(relaxed = true)
        every { product.vendorId } returns "product_premium"
        every { product.name } returns "Premium"
        every { product.plans } returns listOf(resolvedPlan)
        every { product.toMap() } returns mapOf(
            "name" to "Premium",
            "vendorId" to "product_premium",
        )

        val data = mockk<PLYSubscriptionData>(relaxed = true)
        every { data.data } returns subscription
        every { data.plan } returns resolvedPlan
        every { data.product } returns product
        return data
    }

    @Test
    fun `transformSubscriptionToMap maps EVERY store type to its ordinal`() {
        // Exhaustive by construction: iterating StoreType.values() means a new native case
        // fails here as soon as it is added, rather than being quietly dropped. That is
        // exactly how WEB_CHECKOUT_STRIPE went missing — the source a Web2App redemption
        // grants, reachable through PLYWebRedemptionContext.subscription.
        for (storeType in StoreType.values()) {
            val map = PurchaselyFlutterPlugin.transformSubscriptionToMap(
                stubbedSubscriptionData(storeType)
            )
            assertEquals(
                "StoreType.$storeType must forward its ordinal, not null",
                storeType.ordinal,
                map["subscriptionSource"],
            )
        }
    }

    @Test
    fun `the store type ordinals match the Dart PLYSubscriptionSource order`() {
        // The wire contract, pinned as literals. Dart maps this Int by index, so a native
        // reorder must break a test here rather than silently cross-wire two stores.
        assertEquals(0, StoreType.APPLE_APP_STORE.ordinal)
        assertEquals(1, StoreType.GOOGLE_PLAY_STORE.ordinal)
        assertEquals(2, StoreType.AMAZON_APP_STORE.ordinal)
        assertEquals(3, StoreType.HUAWEI_APP_GALLERY.ordinal)
        assertEquals(4, StoreType.WEB_CHECKOUT_STRIPE.ordinal)
        assertEquals(5, StoreType.NONE.ordinal)
    }

    @Test
    fun `transformSubscriptionToMap keys product plans by name for the Dart parser`() {
        // The Dart side reads `product.plans` as a MAP, not a list.
        val map = PurchaselyFlutterPlugin.transformSubscriptionToMap(
            stubbedSubscriptionData(StoreType.GOOGLE_PLAY_STORE)
        )

        @Suppress("UNCHECKED_CAST")
        val product = map["product"] as Map<String, Any?>
        @Suppress("UNCHECKED_CAST")
        val plans = product["plans"] as Map<String?, Any?>
        assertEquals(setOf("Monthly"), plans.keys)
        assertEquals("product_premium", product["vendorId"])
    }

    @Test
    fun `transformSubscriptionToMap drops subscription_status`() {
        // Deliberately withheld until iOS emits the same key — see the TODO on the mapper.
        val map = PurchaselyFlutterPlugin.transformSubscriptionToMap(
            stubbedSubscriptionData(StoreType.GOOGLE_PLAY_STORE)
        )
        assertFalse(map.containsKey("subscription_status"))
        assertEquals("token-1", map["purchaseToken"])
    }

    @Test
    fun `webRedemptionResultToMap maps a granted subscription through the shared mapper`() {
        // The redemption context and userSubscriptions must report ONE subscription shape.
        val data = stubbedSubscriptionData(StoreType.GOOGLE_PLAY_STORE)
        val map = webRedemptionResultToMap(
            PLYWebRedemptionResult.Success(
                context = PLYWebRedemptionContext(subscription = data),
                replay = false,
            )
        )

        @Suppress("UNCHECKED_CAST")
        val context = map["context"] as Map<String, Any?>
        @Suppress("UNCHECKED_CAST")
        val subscription = context["subscription"] as Map<String, Any?>
        assertEquals("token-1", subscription["purchaseToken"])
        assertEquals(
            PurchaselyFlutterPlugin.transformSubscriptionToMap(data),
            subscription,
        )
    }

    // endregion
}
