package io.purchasely.purchasely_flutter

import android.app.Activity
import android.os.Looper
import android.widget.FrameLayout
import io.flutter.plugin.common.EventChannel
import io.purchasely.ext.presentation.PLYPresentationBase
import org.junit.After
import org.junit.Before
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config

/**
 * Real SDK path: `buildView` + `PLYPresentationView` attach/detach. Hybrid Composition creates
 * every platform view of a frame (`NativeView.init`) before it adds any of them to the window.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34]) // SDK 36 needs JDK internals that the test JVM does not open
class NativeViewTest {

    private val events = mutableListOf<Map<*, *>>()
    private lateinit var activity: Activity
    private lateinit var root: FrameLayout

    @Before
    fun setUp() {
        setPresentationSink(object : EventChannel.EventSink {
            override fun success(event: Any?) { events.add(event as Map<*, *>) }
            override fun error(code: String?, message: String?, details: Any?) = Unit
            override fun endOfStream() = Unit
        })
        activity = Robolectric.buildActivity(Activity::class.java).setup().get()
        root = FrameLayout(activity)
        activity.setContentView(root)
        PurchaselyFlutterPlugin.loadedPresentations["req-A"] = loaded("screen-A")
        PurchaselyFlutterPlugin.loadedPresentations["req-B"] = loaded("screen-B")
    }

    @After
    fun tearDown() {
        root.removeAllViews() // detach: the SDK keeps attached views in a global list
        idle()
        setPresentationSink(null)
        PurchaselyFlutterPlugin.loadedPresentations.clear()
        PurchaselyFlutterPlugin.displayCallbacks.clear()
    }

    @Test
    fun `an inline view created before another one attaches reports its own dismissal`() {
        // Two PurchaselyView widgets in one frame: both factories run before any attach.
        val viewA = NativeView(activity, 1, mapOf("requestId" to "req-A"))
        NativeView(activity, 2, mapOf("requestId" to "req-B"))

        root.addView(viewA.view)
        idle()
        root.removeView(viewA.view)
        idle()

        assertEquals("onDismissed requestIds after view A is removed", listOf("req-A"), requestIds("onDismissed"))
    }

    @Test
    fun `a view disposed before it attaches builds nothing`() {
        val view = NativeView(activity, 1, mapOf("requestId" to "req-A"))
        view.dispose()

        root.addView(view.view)
        idle()

        assertEquals("children of the disposed layout", 0, (view.view as FrameLayout).childCount)
        assertEquals("events after a dispose before attach", emptyList<Map<*, *>>(), events)
    }

    @Test
    fun `onPresented is sent once, when the view first attaches`() {
        val view = NativeView(activity, 1, mapOf("requestId" to "req-A"))
        idle()
        assertEquals("onPresented before attach", emptyList<Any?>(), requestIds("onPresented"))

        root.addView(view.view)
        idle()
        root.removeView(view.view)
        root.addView(view.view)
        idle()

        assertEquals("onPresented after attach, detach and attach", listOf("req-A"), requestIds("onPresented"))
    }

    private fun idle() = shadowOf(Looper.getMainLooper()).idle()

    private fun requestIds(event: String) = events.filter { it["event"] == event }.map { it["requestId"] }

    private fun setPresentationSink(sink: EventChannel.EventSink?) {
        PurchaselyFlutterPlugin::class.java.getDeclaredField("activePresentationSink").apply {
            isAccessible = true
            set(null, sink)
        }
    }

    /** `Loaded` has an internal constructor: call its Kotlin defaults constructor with only `screenId`. */
    private fun loaded(screenId: String): PLYPresentationBase.Loaded {
        val ctor = PLYPresentationBase.Loaded::class.java.declaredConstructors.first {
            it.parameterTypes.lastOrNull()?.name == "kotlin.jvm.internal.DefaultConstructorMarker"
        }
        val types = ctor.parameterTypes
        val masks = (types.size - 1 + 32) / 33 // n params + ceil(n / 32) masks + marker
        val n = types.size - 1 - masks
        val args = arrayOfNulls<Any>(types.size)
        for (i in 0 until n) args[i] = when (types[i]) {
            Int::class.javaPrimitiveType -> 0
            Boolean::class.javaPrimitiveType -> false
            else -> null
        }
        for (m in 0 until masks) args[n + m] = -1
        args[1] = screenId
        args[n] = -1 and (1 shl 1).inv() // screenId is parameter 1: not defaulted
        return ctor.newInstance(*args) as PLYPresentationBase.Loaded
    }
}
