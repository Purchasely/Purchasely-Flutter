package io.purchasely.purchasely_flutter

import android.app.Activity
import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.mockk.MockKAnnotations
import io.mockk.every
import io.mockk.impl.annotations.MockK
import io.mockk.mockk
import io.mockk.unmockkAll
import io.mockk.verify
import org.junit.After
import org.junit.Before
import org.junit.Test

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
    fun `registerInterceptor rejects unknown action kind`() {
        plugin.onAttachedToEngine(mockFlutterPluginBinding)

        plugin.onMethodCall(
            MethodCall("registerInterceptor", mapOf("kind" to "unknown_action")),
            mockResult,
        )

        verify { mockResult.error("-1", "unknown action kind 'unknown_action'", null) }
    }

    @Test
    fun `handleDeeplink without deeplink returns argument error`() {
        plugin.onAttachedToEngine(mockFlutterPluginBinding)

        plugin.onMethodCall(MethodCall("handleDeeplink", mapOf<String, Any?>()), mockResult)

        verify { mockResult.error("-1", "Deeplink must not be null", null) }
    }

    @Test
    fun `deprecated isDeeplinkHandled routes through deeplink validation`() {
        plugin.onAttachedToEngine(mockFlutterPluginBinding)

        plugin.onMethodCall(MethodCall("isDeeplinkHandled", mapOf<String, Any?>()), mockResult)

        verify { mockResult.error("-1", "Deeplink must not be null", null) }
    }

    @Test
    fun `removed Android subscription UI methods are no-ops`() {
        plugin.onAttachedToEngine(mockFlutterPluginBinding)

        plugin.onMethodCall(MethodCall("presentSubscriptions", null), mockResult)
        plugin.onMethodCall(MethodCall("displaySubscriptionCancellationInstruction", null), mockResult)

        verify(exactly = 2) { mockResult.success(true) }
    }
}
