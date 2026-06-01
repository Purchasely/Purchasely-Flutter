package io.purchasely.purchasely_flutter

import android.content.Context
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

class NativeViewFactory : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        @Suppress("UNCHECKED_CAST")
        val creationParams = args as Map<String?, Any?>?
        // The inline view surfaces its outcome through the plugin's shared
        // `purchasely-presentation-events` sink (see NativeView), not a dedicated
        // MethodChannel, so no per-view channel is needed.
        return NativeView(context, viewId, creationParams)
    }

    companion object {

        const val VIEW_TYPE_ID = "io.purchasely.purchasely_flutter/native_view"
    }
}