package io.purchasely.purchasely_flutter

import android.app.Activity
import android.content.Context
import android.os.Looper
import android.widget.FrameLayout
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.mockk.every
import io.mockk.mockk
import io.mockk.mockkObject
import io.mockk.mockkStatic
import io.mockk.slot
import io.mockk.unmockkAll
import io.mockk.verify
import io.purchasely.ext.Purchasely
import io.purchasely.ext.presentation.PLYPresentationBase
import io.purchasely.ext.presentation.PLYPresentationOutcome
import io.purchasely.ext.presentation.PLYPresentationState
import io.purchasely.ext.presentation.PLYPresentationType
import io.purchasely.ext.presentation.PLYPurchaseResult
import io.purchasely.models.PLYError
import io.purchasely.views.presentation.PLYPresentationView
import kotlinx.coroutines.flow.MutableStateFlow
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config

/**
 * The inline view's dismissal reaches Dart once, also when the native SDK ends the session
 * without calling the buildView callback (it skips the callback of a destroyed host).
 * The view builds the paywall when it attaches, so each test attaches it first.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class NativeViewDisposeTest {

    private val requestId = "req-inline"
    private val state = MutableStateFlow<PLYPresentationState>(PLYPresentationState.Displayed)
    private val callback = slot<(PLYPresentationOutcome) -> Unit>()
    private val events = mutableListOf<Map<String, Any?>>()
    private lateinit var root: FrameLayout

    @Before
    fun setup() {
        val activity = Robolectric.buildActivity(Activity::class.java).setup().get()
        root = FrameLayout(activity)
        activity.setContentView(root)
        val presentation = mockk<PLYPresentationBase.Loaded>(relaxed = true)
        every { presentation.state } returns state
        val inline = mockk<PLYPresentationView>(relaxed = true) {
            every { parent } returns null
            // The attached host measures its child: it needs FrameLayout params, not the relaxed default.
            every { layoutParams } returns FrameLayout.LayoutParams(0, 0)
        }
        every { presentation.buildView(any<Context>(), capture(callback)) } returns inline
        mockkObject(PurchaselyFlutterPlugin.Companion)
        every { PurchaselyFlutterPlugin.emitPresentationEvent(any()) } answers { events += firstArg<Map<String, Any?>>() }
        every { PurchaselyFlutterPlugin.presentationToMap(any()) } returns emptyMap()
        every { PurchaselyFlutterPlugin.outcomeToMap(any()) } answers {
            mapOf("purchaseResult" to firstArg<PLYPresentationOutcome>().purchaseResult?.name?.lowercase())
        }
        PurchaselyFlutterPlugin.loadedPresentations[requestId] = presentation
        PurchaselyFlutterPlugin.displayCallbacks[requestId] = {}
    }

    @After
    fun tearDown() {
        PurchaselyFlutterPlugin.loadedPresentations.clear()
        PurchaselyFlutterPlugin.displayCallbacks.clear()
        unmockkAll()
    }

    @Test
    fun `dispose after the SDK dismissed without calling back sends onDismissed and drops the entries`() {
        val view = attachedView()
        state.value = PLYPresentationState.Dismissed(PLYPresentationOutcome(purchaseResult = PLYPurchaseResult.CANCELLED))

        view.dispose()

        assertDismissedOnce()
    }

    @Test
    fun `dispose after the callback does not send onDismissed again`() {
        val view = attachedView()
        val outcome = PLYPresentationOutcome(purchaseResult = PLYPurchaseResult.CANCELLED)
        callback.captured(outcome)
        state.value = PLYPresentationState.Dismissed(outcome)

        view.dispose()

        assertDismissedOnce()
    }

    @Test
    fun `dispose of a presentation still on screen sends no onDismissed`() {
        val view = attachedView()

        view.dispose()

        verify(exactly = 0) { PurchaselyFlutterPlugin.outcomeToMap(any()) }
        assertTrue(events.none { it["event"] == "onDismissed" })
    }

    @Test
    fun `a presentation with no native view reports its outcome once and keeps its preload handle`() {
        val error = PLYError.Unknown(IllegalStateException("cannot be embedded as a view"))
        val outcome = PLYPresentationOutcome(error = error)
        val presentation = presentationWithoutView(outcome)
        every { PurchaselyFlutterPlugin.outcomeToMap(any()) } answers {
            mapOf("error" to (firstArg<PLYPresentationOutcome>().error === error))
        }
        PurchaselyFlutterPlugin.loadedPresentations[requestId] = presentation

        val view = attachedView()

        assertEquals(0, (view.view as FrameLayout).childCount)
        assertTrue(events.none { it["event"] == "onPresented" })

        view.dispose()

        val dismissed = events.filter { it["event"] == "onDismissed" }
        assertEquals("onDismissed events: $dismissed", 1, dismissed.size)
        assertEquals(true, (dismissed.single()["outcome"] as Map<*, *>)["error"])
        assertEquals(presentation, PurchaselyFlutterPlugin.loadedPresentations[requestId])
    }

    @Test
    fun `no-view retention evicts completed handles without consuming active or replacement preloads`() {
        val loaded = PurchaselyFlutterPlugin.loadedPresentations
        val active = loaded[requestId]
        attachedView()

        val outcome = PLYPresentationOutcome(error = PLYError.Unknown(IllegalStateException("cannot embed")))
        loaded["oldest"] = presentationWithoutView(outcome)
        attachedView("oldest").dispose()

        loaded["replaced"] = presentationWithoutView(outcome)
        attachedView("replaced").dispose()
        val replacement = mockk<PLYPresentationBase.Loaded>()
        loaded["replaced"] = replacement

        val retained = (1..64).associate { index ->
            val id = "no-view-$index"
            val presentation = presentationWithoutView(outcome)
            loaded[id] = presentation
            attachedView(id).dispose()
            id to presentation
        }

        assertFalse(loaded.containsKey("oldest"))
        assertEquals(replacement, loaded["replaced"])
        assertEquals(active, loaded[requestId])
        assertEquals(retained, loaded.filterKeys { it in retained })
    }

    @Test
    fun `an opened inline client presentation survives eviction until its close reaches native`() {
        val loaded = PurchaselyFlutterPlugin.loadedPresentations
        val outcome = PLYPresentationOutcome(error = PLYError.Unknown(IllegalStateException("cannot embed")))
        val clientId = "client-open"
        val client = presentationWithoutView(outcome, PLYPresentationType.CLIENT)
        loaded[clientId] = client
        attachedView(clientId).dispose()
        mockkStatic(Purchasely::class)
        every { Purchasely.clientPresentationDisplayed(any()) } returns Unit
        every { Purchasely.clientPresentationClosed(any()) } returns Unit
        val plugin = PurchaselyFlutterPlugin()

        notifyClient(plugin, "clientPresentationDisplayed", clientId)
        mountNoViewBatch("while-client-open", outcome)
        notifyClient(plugin, "clientPresentationClosed", clientId)

        verify(exactly = 1) { Purchasely.clientPresentationDisplayed(client) }
        verify(exactly = 1) { Purchasely.clientPresentationClosed(client) }
        assertEquals(client, loaded[clientId])

        mountNoViewBatch("after-client-closed", outcome)
        assertFalse(loaded.containsKey(clientId))
    }

    @Test
    fun `closing an opened inline client uses its own handle even after a replacement preload`() {
        val loaded = PurchaselyFlutterPlugin.loadedPresentations
        val outcome = PLYPresentationOutcome(error = PLYError.Unknown(IllegalStateException("cannot embed")))
        val clientId = "client-replaced"
        val client = presentationWithoutView(outcome, PLYPresentationType.CLIENT)
        loaded[clientId] = client
        attachedView(clientId).dispose()
        mockkStatic(Purchasely::class)
        every { Purchasely.clientPresentationDisplayed(any()) } returns Unit
        every { Purchasely.clientPresentationClosed(any()) } returns Unit
        val plugin = PurchaselyFlutterPlugin()

        notifyClient(plugin, "clientPresentationDisplayed", clientId)
        val replacement = mockk<PLYPresentationBase.Loaded>()
        loaded[clientId] = replacement
        notifyClient(plugin, "clientPresentationClosed", clientId)

        verify(exactly = 1) { Purchasely.clientPresentationClosed(client) }
        verify(exactly = 0) { Purchasely.clientPresentationClosed(replacement) }
        assertEquals(replacement, loaded[clientId])
    }

    private fun notifyClient(plugin: PurchaselyFlutterPlugin, method: String, requestId: String) {
        val result = mockk<MethodChannel.Result>(relaxed = true)
        val arguments = mapOf("presentation" to mapOf("requestId" to requestId))
        plugin.onMethodCall(MethodCall(method, arguments), result)
        verify(exactly = 1) { result.success(true) }
    }

    private fun mountNoViewBatch(prefix: String, outcome: PLYPresentationOutcome) {
        repeat(64) { index ->
            val id = "$prefix-$index"
            PurchaselyFlutterPlugin.loadedPresentations[id] = presentationWithoutView(outcome)
            attachedView(id).dispose()
        }
    }

    private fun presentationWithoutView(
        outcome: PLYPresentationOutcome,
        presentationType: PLYPresentationType = PLYPresentationType.DEACTIVATED,
    ): PLYPresentationBase.Loaded =
        mockk<PLYPresentationBase.Loaded>(relaxed = true) {
            every { state } returns this@NativeViewDisposeTest.state
            every { type } returns presentationType
            // The native SDK calls back synchronously, then returns null.
            every { buildView(any<Context>(), any()) } answers {
                secondArg<(PLYPresentationOutcome) -> Unit>().invoke(outcome)
                null
            }
        }

    private fun attachedView(requestId: String = this.requestId): NativeView {
        val view = NativeView(root.context, 1, mapOf("requestId" to requestId))
        root.addView(view.view)
        shadowOf(Looper.getMainLooper()).idle()
        return view
    }

    private fun assertDismissedOnce() {
        val dismissed = events.filter { it["event"] == "onDismissed" }
        assertEquals("onDismissed events: $dismissed", 1, dismissed.size)
        assertEquals(requestId, dismissed.single()["requestId"])
        assertEquals("cancelled", (dismissed.single()["outcome"] as Map<*, *>)["purchaseResult"])
        assertFalse(PurchaselyFlutterPlugin.loadedPresentations.containsKey(requestId))
        assertFalse(PurchaselyFlutterPlugin.displayCallbacks.containsKey(requestId))
    }
}
