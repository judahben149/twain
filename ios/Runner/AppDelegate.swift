import CoreLocation
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, CLLocationManagerDelegate {
  private let locationChannelName = "com.judahben149.twain/location"
  private var locationManager: CLLocationManager?
  private var locationPermissionResult: FlutterResult?
  private var locationRequestResult: FlutterResult?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    if let controller = window?.rootViewController as? FlutterViewController {
      let locationChannel = FlutterMethodChannel(
        name: locationChannelName,
        binaryMessenger: controller.binaryMessenger
      )

      locationChannel.setMethodCallHandler { [weak self] call, result in
        guard let self = self else { return }

        switch call.method {
        case "checkPermission":
          result(self.currentPermissionStatus())
        case "requestPermission":
          self.requestPermission(result: result)
        case "isLocationEnabled":
          result(CLLocationManager.locationServicesEnabled())
        case "getCurrentLocation":
          self.fetchCurrentLocation(result: result)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func ensureLocationManager() -> CLLocationManager {
    if let manager = locationManager {
      return manager
    }
    let manager = CLLocationManager()
    manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    manager.delegate = self
    locationManager = manager
    return manager
  }

  private func currentPermissionStatus() -> String {
    let status: CLAuthorizationStatus
    if #available(iOS 14.0, *) {
      status = CLLocationManager().authorizationStatus
    } else {
      status = CLLocationManager.authorizationStatus()
    }

    switch status {
    case .authorizedAlways, .authorizedWhenInUse:
      return "granted"
    case .denied:
      return "denied_forever"
    case .restricted:
      return "restricted"
    case .notDetermined:
      return "not_determined"
    @unknown default:
      return "denied"
    }
  }

  private func requestPermission(result: @escaping FlutterResult) {
    let status = currentPermissionStatus()
    if status == "granted" {
      result("granted")
      return
    }

    if status == "denied_forever" || status == "restricted" {
      result(status)
      return
    }

    if locationPermissionResult != nil {
      result(FlutterError(code: "PENDING", message: "Location permission request already in progress", details: nil))
      return
    }

    locationPermissionResult = result
    ensureLocationManager().requestWhenInUseAuthorization()
  }

  private func fetchCurrentLocation(result: @escaping FlutterResult) {
    let status = currentPermissionStatus()
    guard status == "granted" else {
      result(FlutterError(code: "PERMISSION_DENIED", message: "Location permission not granted", details: nil))
      return
    }

    guard CLLocationManager.locationServicesEnabled() else {
      result(FlutterError(code: "LOCATION_DISABLED", message: "Location services are disabled", details: nil))
      return
    }

    if locationRequestResult != nil {
      result(FlutterError(code: "PENDING", message: "Location request already in progress", details: nil))
      return
    }

    locationRequestResult = result
    ensureLocationManager().requestLocation()
  }

  private func resolvePermissionResult(status: CLAuthorizationStatus) {
    guard let result = locationPermissionResult else { return }

    switch status {
    case .authorizedAlways, .authorizedWhenInUse:
      result("granted")
      locationPermissionResult = nil
    case .denied:
      result("denied_forever")
      locationPermissionResult = nil
    case .restricted:
      result("restricted")
      locationPermissionResult = nil
    case .notDetermined:
      break
    @unknown default:
      result("denied")
      locationPermissionResult = nil
    }
  }

  // CLLocationManagerDelegate methods
  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    if #available(iOS 14.0, *) {
      resolvePermissionResult(status: manager.authorizationStatus)
    }
  }

  func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
    resolvePermissionResult(status: status)
  }

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    guard let result = locationRequestResult else { return }
    locationRequestResult = nil

    if let location = locations.last {
      result([
        "latitude": location.coordinate.latitude,
        "longitude": location.coordinate.longitude,
        "accuracy": location.horizontalAccuracy,
        "timestamp": Date().timeIntervalSince1970 * 1000
      ])
    } else {
      result(FlutterError(code: "LOCATION_UNAVAILABLE", message: "No location data available", details: nil))
    }
  }

  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    guard let result = locationRequestResult else { return }
    locationRequestResult = nil
    result(FlutterError(code: "LOCATION_ERROR", message: error.localizedDescription, details: nil))
  }
}
