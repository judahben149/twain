package com.judahben149.twain

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.LocationManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.google.android.gms.location.FusedLocationProviderClient
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import com.google.android.gms.tasks.CancellationTokenSource
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val navigationChannelName = "com.twain.app/navigation"
    private val batteryChannelName = "com.judahben149.twain/battery"
    private val locationChannelName = "com.judahben149.twain/location"

    private val fusedLocationClient: FusedLocationProviderClient by lazy {
        LocationServices.getFusedLocationProviderClient(this)
    }

    private val sharedPrefs by lazy {
        getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    }

    private var navigationChannel: MethodChannel? = null
    private var locationPermissionResult: MethodChannel.Result? = null
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

        // Location channel
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            locationChannelName
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkPermission" -> result.success(currentLocationPermissionStatus())
                "requestPermission" -> requestLocationPermission(result)
                "isLocationEnabled" -> result.success(isLocationServicesEnabled())
                "getCurrentLocation" -> fetchCurrentLocation(result)
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

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)

        if (requestCode == LOCATION_PERMISSION_REQUEST_CODE) {
            val result = locationPermissionResult ?: return
            locationPermissionResult = null

            val granted = grantResults.any { it == PackageManager.PERMISSION_GRANTED }
            if (granted) {
                result.success("granted")
                return
            }

            val shouldShowFine =
                ActivityCompat.shouldShowRequestPermissionRationale(this, Manifest.permission.ACCESS_FINE_LOCATION)
            val shouldShowCoarse =
                ActivityCompat.shouldShowRequestPermissionRationale(this, Manifest.permission.ACCESS_COARSE_LOCATION)
            val status = if (!shouldShowFine && !shouldShowCoarse) {
                "denied_forever"
            } else {
                "denied"
            }
            result.success(status)
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

    private fun currentLocationPermissionStatus(): String {
        val fineGranted =
            ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
        val coarseGranted =
            ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED
        if (fineGranted || coarseGranted) {
            return "granted"
        }

        val hasRequestedBefore = sharedPrefs.getBoolean(KEY_LOCATION_PERMISSION_REQUESTED, false)
        val shouldShowFine =
            ActivityCompat.shouldShowRequestPermissionRationale(this, Manifest.permission.ACCESS_FINE_LOCATION)
        val shouldShowCoarse =
            ActivityCompat.shouldShowRequestPermissionRationale(this, Manifest.permission.ACCESS_COARSE_LOCATION)

        return if (!shouldShowFine && !shouldShowCoarse && hasRequestedBefore) {
            "denied_forever"
        } else if (!hasRequestedBefore) {
            "not_determined"
        } else {
            "denied"
        }
    }

    private fun requestLocationPermission(result: MethodChannel.Result) {
        val status = currentLocationPermissionStatus()
        if (status == "granted") {
            result.success("granted")
            return
        }

        if (locationPermissionResult != null) {
            result.error("PENDING", "Location permission request already in progress", null)
            return
        }

        sharedPrefs.edit()
            .putBoolean(KEY_LOCATION_PERMISSION_REQUESTED, true)
            .apply()

        locationPermissionResult = result
        ActivityCompat.requestPermissions(
            this,
            arrayOf(
                Manifest.permission.ACCESS_FINE_LOCATION,
                Manifest.permission.ACCESS_COARSE_LOCATION
            ),
            LOCATION_PERMISSION_REQUEST_CODE
        )
    }

    private fun isLocationServicesEnabled(): Boolean {
        val locationManager = getSystemService(Context.LOCATION_SERVICE) as? LocationManager ?: return false
        return locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER) ||
            locationManager.isProviderEnabled(LocationManager.NETWORK_PROVIDER)
    }

    private fun fetchCurrentLocation(result: MethodChannel.Result) {
        val status = currentLocationPermissionStatus()
        if (status != "granted") {
            result.error("PERMISSION_DENIED", "Location permission not granted", null)
            return
        }

        if (!isLocationServicesEnabled()) {
            result.error("LOCATION_DISABLED", "Location services are disabled", null)
            return
        }

        try {
            fusedLocationClient.lastLocation
                .addOnSuccessListener { location ->
                    if (location != null) {
                        result.success(location.toResultMap())
                    } else {
                        requestFreshLocation(result)
                    }
                }
                .addOnFailureListener { error ->
                    result.error("LOCATION_ERROR", error.localizedMessage, null)
                }
        } catch (error: SecurityException) {
            result.error("PERMISSION_DENIED", "Missing location permission", null)
        }
    }

    private fun requestFreshLocation(result: MethodChannel.Result) {
        val tokenSource = CancellationTokenSource()
        fusedLocationClient.getCurrentLocation(
            Priority.PRIORITY_BALANCED_POWER_ACCURACY,
            tokenSource.token
        ).addOnSuccessListener { location ->
            if (location != null) {
                result.success(location.toResultMap())
            } else {
                result.error("LOCATION_UNAVAILABLE", "Unable to acquire location", null)
            }
        }.addOnFailureListener { error ->
            result.error("LOCATION_ERROR", error.localizedMessage, null)
        }
    }

    private fun android.location.Location.toResultMap(): Map<String, Any?> {
        return mapOf(
            "latitude" to latitude,
            "longitude" to longitude,
            "accuracy" to accuracy.toDouble(),
            "timestamp" to System.currentTimeMillis()
        )
    }

    companion object {
        private const val EXTRA_NOTIFICATION_PAYLOAD = "notification_payload"
        private const val LOCATION_PERMISSION_REQUEST_CODE = 1001
        private const val PREFS_NAME = "twain_permissions"
        private const val KEY_LOCATION_PERMISSION_REQUESTED = "location_permission_requested"
    }
}
