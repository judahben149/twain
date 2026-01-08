package com.judahben149.wallpaper_sync_plugin

import android.app.PendingIntent
import android.app.WallpaperManager
import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.os.Build
import android.util.Log
import androidx.annotation.NonNull
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry

/** Registers the wallpaper method channel so Dart can trigger native wallpaper changes. */
class WallpaperSyncPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var appContext: Context
    private var channel: MethodChannel? = null

    override fun onAttachedToEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        appContext = binding.applicationContext
        setupChannel(binding.binaryMessenger)
        ensureNotificationChannel()
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        teardownChannel()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "setWallpaper" -> {
                val imagePath = call.argument<String>("imagePath")
                if (imagePath.isNullOrEmpty()) {
                    result.error("INVALID_ARGUMENT", "Image path is null or empty", null)
                    return
                }

                val success = applyWallpaper(imagePath)
                if (success) {
                    result.success(null)
                } else {
                    result.error("WALLPAPER_ERROR", "Failed to set wallpaper", null)
                }
            }

            "ping" -> result.success("pong")
            "showNotification" -> {
                val title = call.argument<String>("title") ?: ""
                val body = call.argument<String>("body") ?: ""
                showNotification(title, body)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun setupChannel(messenger: BinaryMessenger) {
        channel = MethodChannel(messenger, CHANNEL_NAME).also {
            it.setMethodCallHandler(this)
        }
    }

    private fun teardownChannel() {
        channel?.setMethodCallHandler(null)
        channel = null
    }

    private fun applyWallpaper(imagePath: String): Boolean {
        return try {
            val bitmap = BitmapFactory.decodeFile(imagePath)
            if (bitmap == null) {
                Log.e(LOG_TAG, "Failed to decode wallpaper image at $imagePath")
                return false
            }

            val wallpaperManager = WallpaperManager.getInstance(appContext)
            wallpaperManager.setBitmap(bitmap)
            Log.i(LOG_TAG, "Wallpaper applied successfully")
            true
        } catch (error: Exception) {
            Log.e(LOG_TAG, "Error applying wallpaper", error)
            false
        }
    }

    private fun showNotification(title: String, body: String) {
        val intent = appContext.packageManager.getLaunchIntentForPackage(appContext.packageName)
        val pendingIntent = intent?.let {
            it.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            val flags =
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
            PendingIntent.getActivity(appContext, 0, it, flags)
        }

        val notification = NotificationCompat.Builder(appContext, CHANNEL_ID)
            .setSmallIcon(appContext.applicationInfo.icon)
            .setContentTitle(title.ifEmpty { DEFAULT_TITLE })
            .setContentText(body.ifEmpty { DEFAULT_BODY })
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .apply {
                if (pendingIntent != null) {
                    setContentIntent(pendingIntent)
                }
            }
            .build()

        NotificationManagerCompat.from(appContext).notify(
            notificationId.incrementAndGet(),
            notification
        )
    }

    private fun ensureNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val manager = NotificationManagerCompat.from(appContext)
        val channel = manager.getNotificationChannel(CHANNEL_ID)
        if (channel != null) return

        val newChannel = android.app.NotificationChannel(
            CHANNEL_ID,
            CHANNEL_NAME,
            android.app.NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = CHANNEL_DESCRIPTION
        }

        manager.createNotificationChannel(newChannel)
    }

    companion object {
        private const val CHANNEL_NAME = "com.twain.app/wallpaper"
        private const val CHANNEL_ID = "twain_wallpaper_updates"
        private const val CHANNEL_DESCRIPTION =
            "Notifications when your partner sends a new wallpaper."
        private const val DEFAULT_TITLE = "Twain Wallpaper"
        private const val DEFAULT_BODY = "You have a new wallpaper from your partner."
        private const val LOG_TAG = "WallpaperSyncPlugin"
        private val notificationId = java.util.concurrent.atomic.AtomicInteger(1000)

        @JvmStatic
        fun registerWith(registrar: PluginRegistry.Registrar) {
            val plugin = WallpaperSyncPlugin()
            plugin.appContext = registrar.context().applicationContext
            plugin.setupChannel(registrar.messenger())
            plugin.ensureNotificationChannel()
            registrar.publish(plugin)
        }
    }
}
