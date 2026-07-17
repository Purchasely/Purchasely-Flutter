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
import org.junit.After
import org.junit.Before
import org.junit.Test

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
}
