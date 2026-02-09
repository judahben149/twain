import Foundation
import UIKit

public class WallpaperStorageManager {
    public static let shared = WallpaperStorageManager()

    private let appGroupIdentifier = "group.com.judahben149.twain"
    private let wallpaperFileName = "current_wallpaper.jpg"
    private let versionKey = "twain_wallpaper_version"
    private let updatedAtKey = "twain_wallpaper_updated_at"
    private let lastAppliedKey = "twain_wallpaper_last_applied"
    private let shortcutSetupKey = "twain_shortcut_setup_complete"

    private var sharedDefaults: UserDefaults? {
        return UserDefaults(suiteName: appGroupIdentifier)
    }

    private var containerURL: URL? {
        return FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        )
    }

    private init() {}

    /// Copies image to the App Group container and updates version metadata.
    public func saveWallpaper(fromPath path: String, version: String) -> Bool {
        guard let containerURL = containerURL else {
            print("WallpaperStorageManager: App Group container not available")
            return false
        }

        let sourceURL = URL(fileURLWithPath: path)
        let destinationURL = containerURL.appendingPathComponent(wallpaperFileName)

        do {
            // Remove existing file if present
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }

            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)

            // Update shared defaults
            sharedDefaults?.set(version, forKey: versionKey)
            sharedDefaults?.set(Date().timeIntervalSince1970, forKey: updatedAtKey)
            sharedDefaults?.synchronize()

            print("WallpaperStorageManager: Wallpaper saved to App Group (version: \(version))")
            return true
        } catch {
            print("WallpaperStorageManager: Failed to save wallpaper: \(error)")
            return false
        }
    }

    /// Returns the file URL of the current wallpaper if it exists.
    public func currentWallpaperURL() -> URL? {
        guard let containerURL = containerURL else { return nil }
        let fileURL = containerURL.appendingPathComponent(wallpaperFileName)
        return FileManager.default.fileExists(atPath: fileURL.path) ? fileURL : nil
    }

    /// Returns the current wallpaper version string.
    public func currentVersion() -> String? {
        return sharedDefaults?.string(forKey: versionKey)
    }

    /// Returns true if a new wallpaper is available that hasn't been applied via Shortcuts.
    public func hasNewWallpaper() -> Bool {
        guard let current = sharedDefaults?.string(forKey: versionKey) else {
            return false
        }
        let lastApplied = sharedDefaults?.string(forKey: lastAppliedKey)
        return current != lastApplied
    }

    /// Marks the current wallpaper version as applied (called after Shortcut use).
    public func markAsApplied() {
        guard let current = sharedDefaults?.string(forKey: versionKey) else { return }
        sharedDefaults?.set(current, forKey: lastAppliedKey)
        sharedDefaults?.synchronize()
        print("WallpaperStorageManager: Marked version \(current) as applied")
    }

    /// Returns diagnostic info about the App Group state.
    public func debugInfo() -> [String: Any?] {
        let wallpaperURL = currentWallpaperURL()
        var fileSize: Int64? = nil
        if let url = wallpaperURL,
           let attrs = try? FileManager.default.attributesOfItem(atPath: url.path) {
            fileSize = attrs[.size] as? Int64
        }

        let containerExists = containerURL != nil
        let defaultsExist = sharedDefaults != nil

        return [
            "containerExists": containerExists,
            "containerPath": containerURL?.path as Any,
            "defaultsExist": defaultsExist,
            "wallpaperExists": wallpaperURL != nil,
            "wallpaperPath": wallpaperURL?.path as Any,
            "wallpaperFileSize": fileSize as Any,
            "currentVersion": sharedDefaults?.string(forKey: versionKey) as Any,
            "lastApplied": sharedDefaults?.string(forKey: lastAppliedKey) as Any,
            "updatedAt": sharedDefaults?.double(forKey: updatedAtKey) as Any,
            "hasNewWallpaper": hasNewWallpaper(),
            "shortcutSetupComplete": isShortcutSetupComplete,
        ]
    }

    /// Whether the user has completed the Shortcuts setup flow.
    public var isShortcutSetupComplete: Bool {
        get { sharedDefaults?.bool(forKey: shortcutSetupKey) ?? false }
        set {
            sharedDefaults?.set(newValue, forKey: shortcutSetupKey)
            sharedDefaults?.synchronize()
        }
    }
}
