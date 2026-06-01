package io.purchasely.purchasely_flutter

import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import io.flutter.plugin.common.MethodChannel

class NativeViewFactory(binaryMessenger: BinaryMessenger) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    private val channel: MethodChannel

    init {
        channel = MethodChannel(binaryMessenger, CHANNEL_ID)
    }

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val creationParams = args as Map<String?, Any?>?
        return NativeView(context, viewId, creationParams, channel)
    }

    companion object {

        const val VIEW_TYPE_ID = "io.purchasely.purchasely_flutter/native_view"
        const val CHANNEL_ID = "native_view_channel"
    }
}