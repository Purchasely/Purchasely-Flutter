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
import io.purchasely.ext.*
import io.purchasely.models.PLYPlan
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.*
import org.junit.After
import org.junit.Assert.*
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
        // Clear companion object state
        PurchaselyFlutterPlugin.presentationResult = null
        PurchaselyFlutterPlugin.defaultPresentationResult = null
        PurchaselyFlutterPlugin.paywallActionHandler = null
        PurchaselyFlutterPlugin.paywallAction = null
        PurchaselyFlutterPlugin.productActivity = null
        PurchaselyFlutterPlugin.presentationsLoaded.clear()
    }

    // region Plugin Lifecycle Tests

    @Test
    fun `onAttachedToEngine sets up channels correctly`() {
        plugin.onAttachedToEngine(mockFlutterPluginBinding)

        verify { mockFlutterPluginBinding.binaryMessenger }
        verify { mockFlutterPluginBinding.applicationContext }
    }

    @Test
    fun `onDetachedFromEngine cleans up without exceptions`() {
        plugin.onAttachedToEngine(mockFlutterPluginBinding)

        // Should not throw any exception
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
    fun `userLogin with null userId returns error`() {
        plugin.onAttachedToEngine(mockFlutterPluginBinding)

        val call = MethodCall("userLogin", mapOf<String, Any?>())
        plugin.onMethodCall(call, mockResult)

        verify { mockResult.error("-1", "user id must not be null", null) }
    }

    @Test
    fun `presentProductWithIdentifier with null productId returns error`() {
        plugin.onAttachedToEngine(mockFlutterPluginBinding)

        val call = MethodCall("presentProductWithIdentifier", mapOf<String, Any?>())
        plugin.onMethodCall(call, mockResult)

        verify { mockResult.error("-1", "product vendor id must not be null", null) }
    }

    @Test
    fun `presentPlanWithIdentifier with null planId returns error`() {
        plugin.onAttachedToEngine(mockFlutterPluginBinding)

        val call = MethodCall("presentPlanWithIdentifier", mapOf<String, Any?>())
        plugin.onMethodCall(call, mockResult)

        verify { mockResult.error("-1", "plan vendor id must not be null", null) }
    }

    @Test
    fun `presentPresentation with null presentation returns error`() {
        plugin.onAttachedToEngine(mockFlutterPluginBinding)

        val call = MethodCall("presentPresentation", mapOf<String, Any?>())
        plugin.onMethodCall(call, mockResult)

        verify { mockResult.error("-1", "presentation cannot be null", null) }
    }

    @Test
    fun `presentPresentation with unfetched presentation returns error`() {
        plugin.onAttachedToEngine(mockFlutterPluginBinding)

        val presentationMap = mapOf(
            "id" to "some-id",
            "placementId" to "some-placement"
        )

        val call = MethodCall("presentPresentation", mapOf("presentation" to presentationMap))
        plugin.onMethodCall(call, mockResult)

        verify { mockResult.error("-1", "presentation was not fetched", null) }
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

        // Should not throw, just return early
        assertDoesNotThrow {
            plugin.onMethodCall(call, mockResult)
        }
    }

    @Test
    fun `setUserAttributeWithString with missing value does not crash`() {
        plugin.onAttachedToEngine(mockFlutterPluginBinding)

        val call = MethodCall("setUserAttributeWithString", mapOf("key" to "test"))

        // Should not throw, just return early
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

    // region Companion Object Tests

    @Test
    fun `sendPresentationResult with presentationResult sends correct data for PURCHASED`() {
        val mockPlan = mockk<PLYPlan>(relaxed = true)
        val mockPlanMap = mapOf<String, Any?>("vendorId" to "test-plan")

        every { mockPlan.toMap() } returns mockPlanMap
        every { mockPlan.type } returns DistributionType.RENEWING_SUBSCRIPTION

        PurchaselyFlutterPlugin.presentationResult = mockResult

        PurchaselyFlutterPlugin.sendPresentationResult(PLYProductViewResult.PURCHASED, mockPlan)

        verify {
            mockResult.success(match<Map<String, Any?>> { map ->
                map["result"] == PLYProductViewResult.PURCHASED.ordinal
            })
        }
        assertNull(PurchaselyFlutterPlugin.presentationResult)
    }

    @Test
    fun `sendPresentationResult with presentationResult sends correct data for CANCELLED`() {
        val mockPlan = mockk<PLYPlan>(relaxed = true)
        val mockPlanMap = mapOf<String, Any?>("vendorId" to "test-plan")

        every { mockPlan.toMap() } returns mockPlanMap
        every { mockPlan.type } returns DistributionType.NON_CONSUMABLE

        PurchaselyFlutterPlugin.presentationResult = mockResult

        PurchaselyFlutterPlugin.sendPresentationResult(PLYProductViewResult.CANCELLED, mockPlan)

        verify {
            mockResult.success(match<Map<String, Any?>> { map ->
                map["result"] == PLYProductViewResult.CANCELLED.ordinal
            })
        }
        assertNull(PurchaselyFlutterPlugin.presentationResult)
    }

    @Test
    fun `sendPresentationResult with presentationResult sends correct data for RESTORED`() {
        val mockPlan = mockk<PLYPlan>(relaxed = true)
        val mockPlanMap = mapOf<String, Any?>("vendorId" to "test-plan")

        every { mockPlan.toMap() } returns mockPlanMap
        every { mockPlan.type } returns DistributionType.CONSUMABLE

        PurchaselyFlutterPlugin.presentationResult = mockResult

        PurchaselyFlutterPlugin.sendPresentationResult(PLYProductViewResult.RESTORED, mockPlan)

        verify {
            mockResult.success(match<Map<String, Any?>> { map ->
                map["result"] == PLYProductViewResult.RESTORED.ordinal
            })
        }
        assertNull(PurchaselyFlutterPlugin.presentationResult)
    }

    @Test
    fun `sendPresentationResult with defaultPresentationResult when presentationResult is null`() {
        val mockPlan = mockk<PLYPlan>(relaxed = true)
        val mockPlanMap = mapOf<String, Any?>("vendorId" to "test-plan")

        every { mockPlan.toMap() } returns mockPlanMap
        every { mockPlan.type } returns DistributionType.CONSUMABLE

        PurchaselyFlutterPlugin.presentationResult = null
        PurchaselyFlutterPlugin.defaultPresentationResult = mockResult

        PurchaselyFlutterPlugin.sendPresentationResult(PLYProductViewResult.RESTORED, mockPlan)

        verify {
            mockResult.success(match<Map<String, Any?>> { map ->
                map["result"] == PLYProductViewResult.RESTORED.ordinal
            })
        }
        // defaultPresentationResult should NOT be set to null
        assertNotNull(PurchaselyFlutterPlugin.defaultPresentationResult)
    }

    @Test
    fun `sendPresentationResult with null plan sends empty map`() {
        PurchaselyFlutterPlugin.presentationResult = mockResult

        PurchaselyFlutterPlugin.sendPresentationResult(PLYProductViewResult.CANCELLED, null)

        verify {
            mockResult.success(match<Map<String, Any?>> { map ->
                (map["plan"] as Map<*, *>).isEmpty()
            })
        }
    }

    @Test
    fun `sendPresentationResult with both results null does nothing`() {
        PurchaselyFlutterPlugin.presentationResult = null
        PurchaselyFlutterPlugin.defaultPresentationResult = null

        assertDoesNotThrow {
            PurchaselyFlutterPlugin.sendPresentationResult(PLYProductViewResult.CANCELLED, null)
        }
    }

    @Test
    fun `sendPresentationResult clears presentationResult but not defaultPresentationResult`() {
        val mockPresentationResult = mockk<MethodChannel.Result>(relaxed = true)
        val mockDefaultResult = mockk<MethodChannel.Result>(relaxed = true)

        PurchaselyFlutterPlugin.presentationResult = mockPresentationResult
        PurchaselyFlutterPlugin.defaultPresentationResult = mockDefaultResult

        PurchaselyFlutterPlugin.sendPresentationResult(PLYProductViewResult.PURCHASED, null)

        assertNull(PurchaselyFlutterPlugin.presentationResult)
        assertNotNull(PurchaselyFlutterPlugin.defaultPresentationResult)
        assertEquals(mockDefaultResult, PurchaselyFlutterPlugin.defaultPresentationResult)
    }

    @Test
    fun `sendPresentationResult prefers presentationResult over defaultPresentationResult`() {
        val mockPresentationResult = mockk<MethodChannel.Result>(relaxed = true)
        val mockDefaultResult = mockk<MethodChannel.Result>(relaxed = true)

        PurchaselyFlutterPlugin.presentationResult = mockPresentationResult
        PurchaselyFlutterPlugin.defaultPresentationResult = mockDefaultResult

        PurchaselyFlutterPlugin.sendPresentationResult(PLYProductViewResult.PURCHASED, null)

        verify { mockPresentationResult.success(any()) }
        verify(exactly = 0) { mockDefaultResult.success(any()) }
    }

    // endregion

    // region ProductActivity Tests

    @Test
    fun `ProductActivity relaunch with null flutterActivity returns false`() {
        val productActivity = PurchaselyFlutterPlugin.ProductActivity(
            presentationId = "test-presentation"
        )

        val result = productActivity.relaunch(null)

        assertFalse(result)
    }

    @Test
    fun `ProductActivity properties are correctly stored`() {
        val productActivity = PurchaselyFlutterPlugin.ProductActivity(
            presentationId = "pres-123",
            placementId = "place-456",
            productId = "prod-789",
            planId = "plan-012",
            contentId = "content-345",
            isFullScreen = true,
            loadingBackgroundColor = "#FFFFFF"
        )

        assertEquals("pres-123", productActivity.presentationId)
        assertEquals("place-456", productActivity.placementId)
        assertEquals("prod-789", productActivity.productId)
        assertEquals("plan-012", productActivity.planId)
        assertEquals("content-345", productActivity.contentId)
        assertTrue(productActivity.isFullScreen)
        assertEquals("#FFFFFF", productActivity.loadingBackgroundColor)
    }

    @Test
    fun `ProductActivity default values are correct`() {
        val productActivity = PurchaselyFlutterPlugin.ProductActivity()

        assertNull(productActivity.presentation)
        assertNull(productActivity.presentationId)
        assertNull(productActivity.placementId)
        assertNull(productActivity.productId)
        assertNull(productActivity.planId)
        assertNull(productActivity.contentId)
        assertFalse(productActivity.isFullScreen)
        assertNull(productActivity.loadingBackgroundColor)
        assertNull(productActivity.activity)
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

    // region Presentations Loaded List Tests

    @Test
    fun `presentationsLoaded list is empty initially`() {
        assertTrue(PurchaselyFlutterPlugin.presentationsLoaded.isEmpty())
    }

    @Test
    fun `presentationsLoaded list can be cleared`() {
        // Simulate adding something by checking the clear works
        PurchaselyFlutterPlugin.presentationsLoaded.clear()
        assertTrue(PurchaselyFlutterPlugin.presentationsLoaded.isEmpty())
    }

    // endregion

    // region Paywall Action Handler Tests

    @Test
    fun `paywallActionHandler is null initially`() {
        assertNull(PurchaselyFlutterPlugin.paywallActionHandler)
    }

    @Test
    fun `paywallAction is null initially`() {
        assertNull(PurchaselyFlutterPlugin.paywallAction)
    }

    @Test
    fun `paywallActionHandler can be set and invoked`() {
        var handlerCalled = false
        var receivedValue: Boolean? = null

        PurchaselyFlutterPlugin.paywallActionHandler = { value ->
            handlerCalled = true
            receivedValue = value
        }

        assertNotNull(PurchaselyFlutterPlugin.paywallActionHandler)

        PurchaselyFlutterPlugin.paywallActionHandler?.invoke(true)

        assertTrue(handlerCalled)
        assertEquals(true, receivedValue)
    }

    @Test
    fun `paywallActionHandler can be cleared`() {
        PurchaselyFlutterPlugin.paywallActionHandler = { _ -> }
        assertNotNull(PurchaselyFlutterPlugin.paywallActionHandler)

        PurchaselyFlutterPlugin.paywallActionHandler = null
        assertNull(PurchaselyFlutterPlugin.paywallActionHandler)
    }

    // endregion

    // region onProcessAction Tests

    @Test
    fun `onProcessAction with handler invokes handler on UI thread`() {
        plugin.onAttachedToEngine(mockFlutterPluginBinding)
        plugin.onAttachedToActivity(mockActivityBinding)

        var handlerCalled = false
        var handlerValue: Boolean? = null
        PurchaselyFlutterPlugin.paywallActionHandler = { value ->
            handlerCalled = true
            handlerValue = value
        }

        every { mockActivity.runOnUiThread(any()) } answers {
            firstArg<Runnable>().run()
        }

        val call = MethodCall("onProcessAction", mapOf("processAction" to true))
        plugin.onMethodCall(call, mockResult)

        assertTrue(handlerCalled)
        assertEquals(true, handlerValue)
        verify { mockResult.success(true) }
    }

    @Test
    fun `onProcessAction with false invokes handler with false`() {
        plugin.onAttachedToEngine(mockFlutterPluginBinding)
        plugin.onAttachedToActivity(mockActivityBinding)

        var handlerValue: Boolean? = null
        PurchaselyFlutterPlugin.paywallActionHandler = { value ->
            handlerValue = value
        }

        every { mockActivity.runOnUiThread(any()) } answers {
            firstArg<Runnable>().run()
        }

        val call = MethodCall("onProcessAction", mapOf("processAction" to false))
        plugin.onMethodCall(call, mockResult)

        assertEquals(false, handlerValue)
        verify { mockResult.success(true) }
    }

    @Test
    fun `onProcessAction without activity does not crash`() {
        plugin.onAttachedToEngine(mockFlutterPluginBinding)
        // Note: not attaching to activity

        PurchaselyFlutterPlugin.paywallActionHandler = { _ -> }

        val call = MethodCall("onProcessAction", mapOf("processAction" to true))

        assertDoesNotThrow {
            plugin.onMethodCall(call, mockResult)
        }
        verify { mockResult.success(true) }
    }

    @Test
    fun `onProcessAction without handler does not crash`() {
        plugin.onAttachedToEngine(mockFlutterPluginBinding)
        plugin.onAttachedToActivity(mockActivityBinding)

        PurchaselyFlutterPlugin.paywallActionHandler = null

        every { mockActivity.runOnUiThread(any()) } answers {
            firstArg<Runnable>().run()
        }

        val call = MethodCall("onProcessAction", mapOf("processAction" to true))

        assertDoesNotThrow {
            plugin.onMethodCall(call, mockResult)
        }
        verify { mockResult.success(true) }
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
