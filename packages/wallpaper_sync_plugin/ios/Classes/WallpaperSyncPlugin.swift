import Flutter
import UIKit
import CommonCrypto
import UserNotifications

public class WallpaperSyncPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "com.twain.app/wallpaper",
            binaryMessenger: registrar.messenger()
        )
        let instance = WallpaperSyncPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "ping":
            result("pong")

        case "setWallpaper":
            handleSetWallpaper(call: call, result: result)

        case "saveWallpaperForShortcuts":
            handleSaveWallpaperForShortcuts(call: call, result: result)

        case "showNotification":
            handleShowNotification(call: call, result: result)

        case "getShortcutSetupStatus":
            result(WallpaperStorageManager.shared.isShortcutSetupComplete)

        case "markShortcutSetupComplete":
            WallpaperStorageManager.shared.isShortcutSetupComplete = true
            result(nil)

        case "openShortcutsApp":
            handleOpenShortcutsApp(result: result)

        case "hasNewWallpaper":
            result(WallpaperStorageManager.shared.hasNewWallpaper())

        case "getDebugInfo":
            result(WallpaperStorageManager.shared.debugInfo())

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - setWallpaper (on iOS, saves to App Group instead of setting)

    private func handleSetWallpaper(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let imagePath = args["imagePath"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "imagePath is required", details: nil))
            return
        }

        let version = imagePath.md5Hash
        let success = WallpaperStorageManager.shared.saveWallpaper(fromPath: imagePath, version: version)

        if success {
            result(nil)
        } else {
            result(FlutterError(
                code: "SAVE_FAILED",
                message: "Failed to save wallpaper to App Group container",
                details: nil
            ))
        }
    }

    // MARK: - saveWallpaperForShortcuts (explicit save with caller-provided version)

    private func handleSaveWallpaperForShortcuts(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let imagePath = args["imagePath"] as? String,
              let version = args["version"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "imagePath and version are required", details: nil))
            return
        }

        let success = WallpaperStorageManager.shared.saveWallpaper(fromPath: imagePath, version: version)
        result(success)
    }

    // MARK: - showNotification

    private func handleShowNotification(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let title = args["title"] as? String,
              let body = args["body"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "title and body are required", details: nil))
            return
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                result(FlutterError(code: "NOTIFICATION_FAILED", message: error.localizedDescription, details: nil))
            } else {
                result(nil)
            }
        }
    }

    // MARK: - openShortcutsApp

    private func handleOpenShortcutsApp(result: @escaping FlutterResult) {
        guard let url = URL(string: "shortcuts://") else {
            result(false)
            return
        }

        DispatchQueue.main.async {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:]) { success in
                    result(success)
                }
            } else {
                result(false)
            }
        }
    }
}

// MARK: - MD5 Hash Extension

extension String {
    var md5Hash: String {
        let data = Data(self.utf8)
        var digest = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
        data.withUnsafeBytes { buffer in
            _ = CC_MD5(buffer.baseAddress, CC_LONG(data.count), &digest)
        }
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
