package com.judahben149.twain

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val navigationChannelName = "com.twain.app/navigation"
    private val batteryChannelName = "com.judahben149.twain/battery"
    private var navigationChannel: MethodChannel? = null
    private var pendingNotificationPayload: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Navigation channel
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

        // Battery optimization channel
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            batteryChannelName
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isIgnoringBatteryOptimizations" -> {
                    result.success(isIgnoringBatteryOptimizations())
                }
                "openBatteryOptimizationSettings" -> {
                    result.success(openBatteryOptimizationSettings())
                }
                "requestIgnoreBatteryOptimizations" -> {
                    result.success(requestIgnoreBatteryOptimizations())
                }
                else -> result.notImplemented()
            }
        }

        intent?.let { captureNotificationPayload(it) }
    }

    private fun isIgnoringBatteryOptimizations(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            return true // Not applicable on older versions
        }
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        return powerManager.isIgnoringBatteryOptimizations(packageName)
    }

    private fun openBatteryOptimizationSettings(): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                startActivity(intent)
                true
            } else {
                false
            }
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    private fun requestIgnoreBatteryOptimizations(): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                    data = Uri.parse("package:$packageName")
                }
                startActivity(intent)
                true
            } else {
                false
            }
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
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
