package io.purchasely.purchasely_flutter

import android.app.Activity
import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.mockk.*
import io.mockk.impl.annotations.MockK
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.*
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test

/**
 * Unit tests for [PurchaselyFlutterPlugin], the v6-only Flutter entry point.
 *
 * After the v5 -> v6 refactor, presentation display, the v5 action interceptor
 * and v5 init were removed. The plugin now:
 *  - sets up the `purchasely` MethodChannel and the `purchasely/v6-events`
 *    EventChannel (alongside the legacy event channels),
 *  - dispatches every "v6/" MethodChannel call to [PurchaselyV6Bridge]
 *    (covered in depth by the Dart-side `bridge_test.dart`),
 *  - keeps routing the surviving v5 verbs (login, attributes, products,
 *    subscriptions data, deeplinks, debug mode, …).
 *
 * These tests assert the entry-point contract: channel/lifecycle setup,
 * unknown-method handling, and the kept-v5 verb routing. They deliberately
 * avoid "v6/" calls that reach into the real Purchasely SDK singleton.
 */
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

    private val testDispatcher = StandardTestDispatcher()

    @Before
    fun setUp() {
        MockKAnnotations.init(this, relaxed = true)
        Dispatchers.setMain(testDispatcher)

        plugin = PurchaselyFlutterPlugin()

        every { mockFlutterPluginBinding.binaryMessenger } returns mockBinaryMessenger
        every { mockFlutterPluginBinding.applicationContext } returns mockContext
        every { mockFlutterPluginBinding.platformViewRegistry } returns mockk(relaxed = true)
        every { mockActivityBinding.activity } returns mockActivity
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
        unmockkAll()
    }

    // region Plugin Lifecycle Tests

    @Test
    fun `onAttachedToEngine sets up channels correctly`() {
        plugin.onAttachedToEngine(mockFlutterPluginBinding)

        // The plugin builds the `purchasely` MethodChannel, the legacy event
        // channels and the `purchasely/v6-events` EventChannel — all of which
        // require the binary messenger and the application context.
        verify { mockFlutterPluginBinding.binaryMessenger }
        verify { mockFlutterPluginBinding.applicationContext }
    }

    @Test
    fun `onDetachedFromEngine cleans up without exceptions`() {
        plugin.onAttachedToEngine(mockFlutterPluginBinding)

        assertDoesNotThrow {
            plugin.onDetachedFromEngine(mockFlutterPluginBinding)
        }
    }

    @Test
    fun `onAttachedToActivity sets activity reference`() {
        plugin.onAttachedToActivity(mockActivityBinding)

        verify { mockActivityBinding.activity }
    }

    @Test
    fun `onDetachedFromActivity does not throw`() {
        plugin.onAttachedToActivity(mockActivityBinding)

        assertDoesNotThrow {
            plugin.onDetachedFromActivity()
        }
    }

    @Test
    fun `onDetachedFromActivityForConfigChanges does not throw`() {
        plugin.onAttachedToActivity(mockActivityBinding)

        assertDoesNotThrow {
            plugin.onDetachedFromActivityForConfigChanges()
        }
    }

    @Test
    fun `onReattachedToActivityForConfigChanges restores activity`() {
        plugin.onReattachedToActivityForConfigChanges(mockActivityBinding)

        verify { mockActivityBinding.activity }
    }

    // endregion

    // region Method Call Routing Tests

    @Test
    fun `onMethodCall with unknown method returns not implemented`() {
        plugin.onAttachedToEngine(mockFlutterPluginBinding)

        val call = MethodCall("unknownMethod", null)
        plugin.onMethodCall(call, mockResult)

        verify { mockResult.notImplemented() }
    }

    @Test
    fun `onMethodCall with unknown v6 method falls through to not implemented`() {
        // The v6 bridge handles a fixed set of `v6/*` verbs and returns false
        // for anything else; unrecognized `v6/*` calls therefore fall through
        // to the legacy switch and end up not-implemented (rather than crashing).
        plugin.onAttachedToEngine(mockFlutterPluginBinding)

        val call = MethodCall("v6/totallyUnknown", emptyMap<String, Any?>())
        plugin.onMethodCall(call, mockResult)

        verify { mockResult.notImplemented() }
    }

    @Test
    fun `userLogin with null userId returns error`() {
        plugin.onAttachedToEngine(mockFlutterPluginBinding)

        val call = MethodCall("userLogin", mapOf<String, Any?>())
        plugin.onMethodCall(call, mockResult)

        verify { mockResult.error("-1", "user id must not be null", null) }
    }

    @Test
    fun `isDeeplinkHandled with null deeplink returns error`() {
        plugin.onAttachedToEngine(mockFlutterPluginBinding)

        val call = MethodCall("isDeeplinkHandled", mapOf<String, Any?>())
        plugin.onMethodCall(call, mockResult)

        verify { mockResult.error("-1", "Deeplink must not be null", null) }
    }

    @Test
    fun `isEligibleForIntroOffer with null planVendorId returns error`() = runTest {
        plugin.onAttachedToEngine(mockFlutterPluginBinding)

        val call = MethodCall("isEligibleForIntroOffer", mapOf<String, Any?>())
        plugin.onMethodCall(call, mockResult)

        advanceUntilIdle()

        verify { mockResult.error("-1", "planVendorId must not be null", null) }
    }

    @Test
    fun `setDebugMode with null returns error`() {
        plugin.onAttachedToEngine(mockFlutterPluginBinding)

        val call = MethodCall("setDebugMode", mapOf<String, Any?>())
        plugin.onMethodCall(call, mockResult)

        verify { mockResult.error("MISSING_PARAMETER", "The 'debugMode' parameter is required.", null) }
    }

    @Test
    fun `setUserAttributeWithString with missing key does not crash`() {
        plugin.onAttachedToEngine(mockFlutterPluginBinding)

        val call = MethodCall("setUserAttributeWithString", mapOf("value" to "test"))

        assertDoesNotThrow {
            plugin.onMethodCall(call, mockResult)
        }
    }

    @Test
    fun `setUserAttributeWithString with missing value does not crash`() {
        plugin.onAttachedToEngine(mockFlutterPluginBinding)

        val call = MethodCall("setUserAttributeWithString", mapOf("key" to "test"))

        assertDoesNotThrow {
            plugin.onMethodCall(call, mockResult)
        }
    }

    @Test
    fun `setUserAttributeWithInt with missing key does not crash`() {
        plugin.onAttachedToEngine(mockFlutterPluginBinding)

        val call = MethodCall("setUserAttributeWithInt", mapOf("value" to 42))

        assertDoesNotThrow {
            plugin.onMethodCall(call, mockResult)
        }
    }

    @Test
    fun `setUserAttributeWithDouble with missing key does not crash`() {
        plugin.onAttachedToEngine(mockFlutterPluginBinding)

        val call = MethodCall("setUserAttributeWithDouble", mapOf("value" to 3.14))

        assertDoesNotThrow {
            plugin.onMethodCall(call, mockResult)
        }
    }

    @Test
    fun `setUserAttributeWithBoolean with missing key does not crash`() {
        plugin.onAttachedToEngine(mockFlutterPluginBinding)

        val call = MethodCall("setUserAttributeWithBoolean", mapOf("value" to true))

        assertDoesNotThrow {
            plugin.onMethodCall(call, mockResult)
        }
    }

    @Test
    fun `incrementUserAttribute with missing key does not crash`() {
        plugin.onAttachedToEngine(mockFlutterPluginBinding)

        val call = MethodCall("incrementUserAttribute", mapOf("value" to 5))

        assertDoesNotThrow {
            plugin.onMethodCall(call, mockResult)
        }
    }

    @Test
    fun `decrementUserAttribute with missing key does not crash`() {
        plugin.onAttachedToEngine(mockFlutterPluginBinding)

        val call = MethodCall("decrementUserAttribute", mapOf("value" to 5))

        assertDoesNotThrow {
            plugin.onMethodCall(call, mockResult)
        }
    }

    @Test
    fun `userAttribute with missing key does not crash`() {
        plugin.onAttachedToEngine(mockFlutterPluginBinding)

        val call = MethodCall("userAttribute", mapOf<String, Any?>())

        assertDoesNotThrow {
            plugin.onMethodCall(call, mockResult)
        }
    }

    @Test
    fun `clearUserAttribute with missing key does not crash`() {
        plugin.onAttachedToEngine(mockFlutterPluginBinding)

        val call = MethodCall("clearUserAttribute", mapOf<String, Any?>())

        assertDoesNotThrow {
            plugin.onMethodCall(call, mockResult)
        }
    }

    @Test
    fun `revokeDataProcessingConsent with missing purposes does not crash`() {
        plugin.onAttachedToEngine(mockFlutterPluginBinding)

        val call = MethodCall("revokeDataProcessingConsent", mapOf<String, Any?>())

        assertDoesNotThrow {
            plugin.onMethodCall(call, mockResult)
        }
    }

    // endregion

    // region FlutterPLYAttribute Enum Tests

    @Test
    fun `FlutterPLYAttribute enum has correct ordinal for firebase_app_instance_id`() {
        assertEquals(0, PurchaselyFlutterPlugin.Companion.FlutterPLYAttribute.firebase_app_instance_id.ordinal)
    }

    @Test
    fun `FlutterPLYAttribute enum has correct ordinal for airship_channel_id`() {
        assertEquals(1, PurchaselyFlutterPlugin.Companion.FlutterPLYAttribute.airship_channel_id.ordinal)
    }

    @Test
    fun `FlutterPLYAttribute enum has correct ordinal for adjust_id`() {
        assertEquals(4, PurchaselyFlutterPlugin.Companion.FlutterPLYAttribute.adjust_id.ordinal)
    }

    @Test
    fun `FlutterPLYAttribute enum has correct ordinal for appsflyer_id`() {
        assertEquals(5, PurchaselyFlutterPlugin.Companion.FlutterPLYAttribute.appsflyer_id.ordinal)
    }

    @Test
    fun `FlutterPLYAttribute enum has correct ordinal for mixpanel_distinct_id`() {
        assertEquals(6, PurchaselyFlutterPlugin.Companion.FlutterPLYAttribute.mixpanel_distinct_id.ordinal)
    }

    @Test
    fun `FlutterPLYAttribute enum has correct ordinal for oneSignalExternalId`() {
        assertEquals(19, PurchaselyFlutterPlugin.Companion.FlutterPLYAttribute.oneSignalExternalId.ordinal)
    }

    @Test
    fun `FlutterPLYAttribute enum has correct ordinal for batchCustomUserId`() {
        assertEquals(20, PurchaselyFlutterPlugin.Companion.FlutterPLYAttribute.batchCustomUserId.ordinal)
    }

    @Test
    fun `FlutterPLYAttribute enum has 21 values`() {
        assertEquals(21, PurchaselyFlutterPlugin.Companion.FlutterPLYAttribute.values().size)
    }

    // endregion

    // region Helper method to assert no exceptions
    private inline fun <T> assertDoesNotThrow(block: () -> T): T {
        return try {
            block()
        } catch (e: Exception) {
            fail("Expected no exception but got: ${e.message}")
            throw e
        }
    }

    // endregion
}
