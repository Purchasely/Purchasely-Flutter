package io.purchasely.purchasely_flutter

import android.content.Context
import io.mockk.every
import io.mockk.mockk
import io.mockk.mockkObject
import io.mockk.slot
import io.mockk.unmockkAll
import io.mockk.verify
import io.purchasely.ext.presentation.PLYPresentationBase
import io.purchasely.ext.presentation.PLYPresentationOutcome
import io.purchasely.ext.presentation.PLYPresentationState
import io.purchasely.ext.presentation.PLYPurchaseResult
import io.purchasely.views.presentation.PLYPresentationView
import kotlinx.coroutines.flow.MutableStateFlow
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

/**
 * The inline view's dismissal reaches Dart once, also when the native SDK ends the session
 * without calling the buildView callback (it skips the callback of a destroyed host).
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class NativeViewTest {

    private val requestId = "req-inline"
    private val state = MutableStateFlow<PLYPresentationState>(PLYPresentationState.Displayed)
    private val callback = slot<(PLYPresentationOutcome) -> Unit>()
    private val events = mutableListOf<Map<String, Any?>>()

    @Before
    fun setup() {
        val presentation = mockk<PLYPresentationBase.Loaded>(relaxed = true)
        every { presentation.state } returns state
        val inline = mockk<PLYPresentationView>(relaxed = true) { every { parent } returns null }
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
        val view = NativeView(RuntimeEnvironment.getApplication(), 1, mapOf("requestId" to requestId))
        state.value = PLYPresentationState.Dismissed(PLYPresentationOutcome(purchaseResult = PLYPurchaseResult.CANCELLED))

        view.dispose()

        assertDismissedOnce()
    }

    @Test
    fun `dispose after the callback does not send onDismissed again`() {
        val view = NativeView(RuntimeEnvironment.getApplication(), 1, mapOf("requestId" to requestId))
        val outcome = PLYPresentationOutcome(purchaseResult = PLYPurchaseResult.CANCELLED)
        callback.captured(outcome)
        state.value = PLYPresentationState.Dismissed(outcome)

        view.dispose()

        assertDismissedOnce()
    }

    @Test
    fun `dispose of a presentation still on screen sends no onDismissed`() {
        val view = NativeView(RuntimeEnvironment.getApplication(), 1, mapOf("requestId" to requestId))

        view.dispose()

        verify(exactly = 0) { PurchaselyFlutterPlugin.outcomeToMap(any()) }
        assertTrue(events.none { it["event"] == "onDismissed" })
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
