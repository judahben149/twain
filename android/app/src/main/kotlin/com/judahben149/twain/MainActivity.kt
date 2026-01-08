package com.judahben149.twain

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val navigationChannelName = "com.twain.app/navigation"
    private var navigationChannel: MethodChannel? = null
    private var pendingNotificationPayload: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        navigationChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            navigationChannelName
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "consumeNotificationPayload" -> {
                        result.success(pendingNotificationPayload)
                        pendingNotificationPayload = null
                    }

                    else -> result.notImplemented()
                }
            }
        }

        intent?.let { captureNotificationPayload(it) }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        captureNotificationPayload(intent)
        dispatchPendingPayload()
    }

    override fun onResume() {
        super.onResume()
        dispatchPendingPayload()
    }

    private fun captureNotificationPayload(intent: Intent) {
        if (intent.hasExtra(EXTRA_NOTIFICATION_PAYLOAD)) {
            pendingNotificationPayload = intent.getStringExtra(EXTRA_NOTIFICATION_PAYLOAD)
        }
    }

  private fun dispatchPendingPayload() {
        val payload = pendingNotificationPayload ?: return
        val channel = navigationChannel ?: return
        channel.invokeMethod("notificationTapped", payload)
        pendingNotificationPayload = null
  }

    companion object {
        private const val EXTRA_NOTIFICATION_PAYLOAD = "notification_payload"
    }
}
