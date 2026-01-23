package com.judahben149.wallpaper_sync_plugin

import android.app.PendingIntent
import android.app.WallpaperManager
import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.graphics.Color
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.annotation.NonNull
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import java.util.concurrent.Executors

/**
 * Native implementation backing wallpaper setting and custom notifications.
 */
class WallpaperSyncPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var appContext: Context
    private var channel: MethodChannel? = null
    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onAttachedToEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        appContext = binding.applicationContext
        setupChannel(binding.binaryMessenger)
        ensureNotificationChannel(
            DEFAULT_CHANNEL_ID,
            DEFAULT_CHANNEL_NAME,
            DEFAULT_CHANNEL_DESCRIPTION
        )
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        teardownChannel()
        executor.shutdown()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "setWallpaper" -> {
                val imagePath = call.argument<String>("imagePath")
                if (imagePath.isNullOrEmpty()) {
                    result.error("INVALID_ARGUMENT", "Image path is null or empty", null)
                    return
                }

                // Run wallpaper setting on background thread to prevent ANR
                executor.execute {
                    val success = applyWallpaper(imagePath)
                    mainHandler.post {
                        if (success) {
                            result.success(null)
                        } else {
                            result.error("WALLPAPER_ERROR", "Failed to set wallpaper", null)
                        }
                    }
                }
            }

            "ping" -> result.success("pong")
            "showNotification" -> {
                val title = call.argument<String>("title") ?: ""
                val body = call.argument<String>("body") ?: ""
                val channelId = call.argument<String>("channelId") ?: DEFAULT_CHANNEL_ID
                val channelName = call.argument<String>("channelName") ?: DEFAULT_CHANNEL_NAME
                val channelDescription =
                    call.argument<String>("channelDescription") ?: DEFAULT_CHANNEL_DESCRIPTION
                val payload = call.argument<String>("payload")
                val colorHex = call.argument<String>("color")

                showNotification(
                    title = title,
                    body = body,
                    channelId = channelId,
                    channelName = channelName,
                    channelDescription = channelDescription,
                    payload = payload,
                    colorHex = colorHex
                )
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }

    private fun setupChannel(messenger: BinaryMessenger) {
        channel = MethodChannel(messenger, DEFAULT_METHOD_CHANNEL).also {
            it.setMethodCallHandler(this)
        }
    }

    private fun teardownChannel() {
        channel?.setMethodCallHandler(null)
        channel = null
    }

    private fun applyWallpaper(imagePath: String): Boolean {
        return try {
            Log.i(LOG_TAG, "Loading wallpaper image from: $imagePath")

            // Use BitmapFactory.Options to downsample large images
            val options = BitmapFactory.Options().apply {
                inJustDecodeBounds = true
            }
            BitmapFactory.decodeFile(imagePath, options)

            // Calculate sample size for images larger than 4K
            val maxDimension = 4096
            var sampleSize = 1
            if (options.outHeight > maxDimension || options.outWidth > maxDimension) {
                val halfHeight = options.outHeight / 2
                val halfWidth = options.outWidth / 2
                while ((halfHeight / sampleSize) >= maxDimension && (halfWidth / sampleSize) >= maxDimension) {
                    sampleSize *= 2
                }
            }

            Log.i(LOG_TAG, "Image dimensions: ${options.outWidth}x${options.outHeight}, sampleSize: $sampleSize")

            // Decode with inSampleSize to reduce memory usage
            val decodeOptions = BitmapFactory.Options().apply {
                inSampleSize = sampleSize
                inPreferredConfig = android.graphics.Bitmap.Config.ARGB_8888
            }

            val bitmap = BitmapFactory.decodeFile(imagePath, decodeOptions)
            if (bitmap == null) {
                Log.e(LOG_TAG, "Failed to decode wallpaper image at $imagePath")
                return false
            }

            Log.i(LOG_TAG, "Decoded bitmap: ${bitmap.width}x${bitmap.height}, ${bitmap.byteCount} bytes")

            val wallpaperManager = WallpaperManager.getInstance(appContext)
            wallpaperManager.setBitmap(bitmap)

            // Recycle bitmap to free memory
            bitmap.recycle()

            Log.i(LOG_TAG, "Wallpaper applied successfully")
            true
        } catch (error: Exception) {
            Log.e(LOG_TAG, "Error applying wallpaper", error)
            false
        }
    }

    private fun showNotification(
        title: String,
        body: String,
        channelId: String,
        channelName: String,
        channelDescription: String,
        payload: String?,
        colorHex: String?
    ) {
        ensureNotificationChannel(channelId, channelName, channelDescription)

        val intent =
            appContext.packageManager.getLaunchIntentForPackage(appContext.packageName)?.apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                payload?.let { putExtra(EXTRA_NOTIFICATION_PAYLOAD, it) }
            }

        val pendingIntent = intent?.let {
            val flags =
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
            PendingIntent.getActivity(appContext, 0, it, flags)
        }

        val notification = NotificationCompat.Builder(appContext, channelId)
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
                colorHex?.let { hex ->
                    parseColorSafely(hex)?.let { parsedColor ->
                        setColor(parsedColor)
                    }
                }
            }
            .build()

        NotificationManagerCompat.from(appContext).notify(
            notificationId.incrementAndGet(),
            notification
        )
    }

    private fun ensureNotificationChannel(
        channelId: String,
        channelName: String,
        channelDescription: String
    ) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val manager = NotificationManagerCompat.from(appContext)
        val existing = manager.getNotificationChannel(channelId)
        if (existing != null) return

        val newChannel = android.app.NotificationChannel(
            channelId,
            channelName,
            android.app.NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = channelDescription
        }

        manager.createNotificationChannel(newChannel)
    }

    private fun parseColorSafely(hex: String): Int? {
        return try {
            val normalized = if (hex.startsWith("#")) hex else "#$hex"
            Color.parseColor(normalized)
        } catch (error: IllegalArgumentException) {
            Log.e(LOG_TAG, "Invalid color provided for notification: $hex")
            null
        }
    }

    companion object {
        private const val DEFAULT_METHOD_CHANNEL = "com.twain.app/wallpaper"
        private const val DEFAULT_CHANNEL_ID = "twain_wallpaper_updates"
        private const val DEFAULT_CHANNEL_NAME = "Wallpaper Updates"
        private const val DEFAULT_CHANNEL_DESCRIPTION =
            "Notifications when your partner sends a new wallpaper."
        private const val DEFAULT_TITLE = "Twain Wallpaper"
        private const val DEFAULT_BODY = "You have a new wallpaper from your partner."
        private const val EXTRA_NOTIFICATION_PAYLOAD = "notification_payload"
        private const val LOG_TAG = "WallpaperSyncPlugin"
        private val notificationId = java.util.concurrent.atomic.AtomicInteger(1000)

        @JvmStatic
        fun registerWith(registrar: PluginRegistry.Registrar) {
            val plugin = WallpaperSyncPlugin()
            plugin.appContext = registrar.context().applicationContext
            plugin.setupChannel(registrar.messenger())
            plugin.ensureNotificationChannel(
                DEFAULT_CHANNEL_ID,
                DEFAULT_CHANNEL_NAME,
                DEFAULT_CHANNEL_DESCRIPTION
            )
            registrar.publish(plugin)
        }
    }
}
