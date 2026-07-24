package io.purchasely.purchasely_flutter

import android.content.Context
import android.os.Bundle
import android.util.Log
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.fragment.app.Fragment
import io.flutter.FlutterInjector
import io.flutter.embedding.android.FlutterTextureView
import io.flutter.embedding.android.FlutterView
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineGroup
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** Hosts one Flutter-authored Custom Screen inside the native Purchasely flow. */
class PurchaselyCustomScreenFragment : Fragment() {
    private var engine: FlutterEngine? = null
    private var flutterView: FlutterView? = null
    private var customScreenChannel: MethodChannel? = null

    private val customScreenId: String
        get() = requireArguments().getString(ARG_CUSTOM_SCREEN_ID).orEmpty()

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?,
    ): View {
        val args = requireArguments()
        val entrypoint = args.getString(ARG_ENTRYPOINT).orEmpty()
        val libraryUri = args.getString(ARG_LIBRARY_URI)
        val context = requireContext()
        val loader = FlutterInjector.instance().flutterLoader()
        val dartEntrypoint = if (libraryUri.isNullOrBlank()) {
            DartExecutor.DartEntrypoint(loader.findAppBundlePath(), entrypoint)
        } else {
            DartExecutor.DartEntrypoint(loader.findAppBundlePath(), libraryUri, entrypoint)
        }
        val createdEngine = engineGroup(context).createAndRunEngine(
            FlutterEngineGroup.Options(context)
                .setDartEntrypoint(dartEntrypoint)
                .setDartEntrypointArgs(listOf(customScreenId))
                .setAutomaticallyRegisterPlugins(false)
        )
        engine = createdEngine
        customScreenChannel = MethodChannel(
            createdEngine.dartExecutor.binaryMessenger,
            CUSTOM_SCREEN_CHANNEL,
        ).also { channel ->
            channel.setMethodCallHandler(::handleCustomScreenCall)
        }

        return FlutterView(context, FlutterTextureView(context)).also { view ->
            flutterView = view
            view.attachToFlutterEngine(createdEngine)
            view.layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
            )
        }
    }

    override fun onResume() {
        super.onResume()
        engine?.lifecycleChannel?.appIsResumed()
    }

    override fun onPause() {
        engine?.lifecycleChannel?.appIsInactive()
        super.onPause()
    }

    override fun onStop() {
        engine?.lifecycleChannel?.appIsPaused()
        super.onStop()
    }

    override fun onDestroyView() {
        customScreenChannel?.setMethodCallHandler(null)
        customScreenChannel = null
        flutterView?.detachFromFlutterEngine()
        flutterView = null
        engine?.destroy()
        engine = null
        // Free the retained native presentation on every teardown EXCEPT a
        // configuration change, where the fragment is recreated and re-fetches
        // the same customScreenId. Gating only on isRemoving/isFinishing (as
        // before) leaked the entry on system-initiated, process-retained
        // destroys.
        if (activity?.isChangingConfigurations != true) {
            PurchaselyFlutterPlugin.removeCustomScreenPresentation(customScreenId)
        }
        super.onDestroyView()
    }

    private fun handleCustomScreenCall(call: MethodCall, result: MethodChannel.Result) {
        @Suppress("UNCHECKED_CAST")
        val args = call.arguments as? Map<String, Any?>
        val requestedId = args?.get("customScreenId") as? String
        if (requestedId != customScreenId) {
            result.error("STALE_CUSTOM_SCREEN", "Custom Screen id does not match this engine", null)
            return
        }
        when (call.method) {
            "getCustomScreenPresentation" -> {
                result.success(PurchaselyFlutterPlugin.customScreenPresentationToMap(customScreenId))
            }
            "customScreenExecuteConnection" -> {
                val connectionId = args?.get("connectionId") as? String
                runOnMain {
                    PurchaselyFlutterPlugin.executeCustomScreenConnection(customScreenId, connectionId)
                }
                result.success(true)
            }
            "customScreenBack" -> {
                runOnMain {
                    PurchaselyFlutterPlugin.customScreenPresentations[customScreenId]?.back()
                        ?: Log.w(TAG, "Custom Screen $customScreenId is no longer available")
                }
                result.success(true)
            }
            "customScreenClose" -> {
                runOnMain {
                    PurchaselyFlutterPlugin.customScreenPresentations[customScreenId]?.close()
                        ?: Log.w(TAG, "Custom Screen $customScreenId is no longer available")
                }
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    private fun runOnMain(action: () -> Unit) {
        val activity = activity
        if (activity != null) activity.runOnUiThread(action) else action()
    }

    companion object {
        private const val TAG = "PurchaselyFlutter"
        private const val CUSTOM_SCREEN_CHANNEL = "purchasely-custom-screen"
        private const val ARG_CUSTOM_SCREEN_ID = "customScreenId"
        private const val ARG_ENTRYPOINT = "entrypoint"
        private const val ARG_LIBRARY_URI = "libraryUri"

        @Volatile
        private var sharedEngineGroup: FlutterEngineGroup? = null

        private fun engineGroup(context: Context): FlutterEngineGroup =
            sharedEngineGroup ?: synchronized(this) {
                sharedEngineGroup ?: FlutterEngineGroup(context.applicationContext).also {
                    sharedEngineGroup = it
                }
            }

        fun newInstance(
            customScreenId: String,
            entrypoint: String,
            libraryUri: String?,
        ) = PurchaselyCustomScreenFragment().apply {
            arguments = Bundle().apply {
                putString(ARG_CUSTOM_SCREEN_ID, customScreenId)
                putString(ARG_ENTRYPOINT, entrypoint)
                putString(ARG_LIBRARY_URI, libraryUri)
            }
        }
    }
}
