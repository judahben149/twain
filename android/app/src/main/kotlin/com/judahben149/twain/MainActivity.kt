package com.judahben149.twain

import android.app.WallpaperManager
import android.graphics.BitmapFactory
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.twain.app/wallpaper"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "setWallpaper" -> {
                    val imagePath = call.argument<String>("imagePath")
                    if (imagePath != null) {
                        val success = setWallpaper(imagePath)
                        if (success) {
                            result.success(null)
                        } else {
                            result.error("WALLPAPER_ERROR", "Failed to set wallpaper", null)
                        }
                    } else {
                        result.error("INVALID_ARGUMENT", "Image path is null", null)
                    }
                }
                "ping" -> {
                    result.success("pong")
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun setWallpaper(imagePath: String): Boolean {
        return try {
            val wallpaperManager = WallpaperManager.getInstance(applicationContext)
            val bitmap = BitmapFactory.decodeFile(imagePath)

            if (bitmap == null) {
                android.util.Log.e("MainActivity", "Failed to decode image file: $imagePath")
                return false
            }

            wallpaperManager.setBitmap(bitmap)
            android.util.Log.i("MainActivity", "Wallpaper set successfully")
            true
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Error setting wallpaper", e)
            e.printStackTrace()
            false
        }
    }
}
