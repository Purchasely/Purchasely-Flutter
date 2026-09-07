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
import io.purchasely.models.PLYWebRedemptionContext
import io.purchasely.models.PLYWebRedemptionResult
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
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
}
