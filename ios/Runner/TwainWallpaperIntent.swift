import AppIntents
import Foundation
import UniformTypeIdentifiers

// MARK: - Self-contained App Group access (avoids loading the plugin framework)

private let appGroupID = "group.com.judahben149.twain"
private let wallpaperFileName = "current_wallpaper.jpg"
private let versionKey = "twain_wallpaper_version"
private let lastAppliedKey = "twain_wallpaper_last_applied"

private func wallpaperURL() -> URL? {
    guard let container = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: appGroupID
    ) else { return nil }
    let url = container.appendingPathComponent(wallpaperFileName)
    return FileManager.default.fileExists(atPath: url.path) ? url : nil
}

private func sharedDefaults() -> UserDefaults? {
    return UserDefaults(suiteName: appGroupID)
}

// MARK: - Custom Error

@available(iOS 16.0, *)
enum TwainIntentError: Error, CustomLocalizedStringResourceConvertible {
    case noWallpaperAvailable

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .noWallpaperAvailable:
            return "No wallpaper available. Ask your partner to send one via Twain."
        }
    }
}

// MARK: - Get Twain Wallpaper Intent

@available(iOS 16.0, *)
struct GetTwainWallpaperIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Twain Wallpaper"
    static var description = IntentDescription("Returns the latest wallpaper synced from your partner via Twain.")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<IntentFile> {
        guard let url = wallpaperURL() else {
            throw TwainIntentError.noWallpaperAvailable
        }

        let data = try Data(contentsOf: url)
        let file = IntentFile(data: data, filename: "twain_wallpaper.jpg", type: .jpeg)

        // Mark as applied
        if let version = sharedDefaults()?.string(forKey: versionKey) {
            sharedDefaults()?.set(version, forKey: lastAppliedKey)
        }

        return .result(value: file)
    }
}

// MARK: - Check Twain Wallpaper Intent

@available(iOS 16.0, *)
struct CheckTwainWallpaperIntent: AppIntent {
    static var title: LocalizedStringResource = "Check Twain Wallpaper"
    static var description = IntentDescription("Checks if a new wallpaper is available from your partner via Twain.")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
        guard let defaults = sharedDefaults(),
              let current = defaults.string(forKey: versionKey) else {
            return .result(value: false)
        }
        let lastApplied = defaults.string(forKey: lastAppliedKey)
        return .result(value: current != lastApplied)
    }
}

// MARK: - Shortcuts Provider

@available(iOS 16.0, *)
struct TwainShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: GetTwainWallpaperIntent(),
            phrases: [
                "Get my \(.applicationName) wallpaper",
                "Get wallpaper from \(.applicationName)",
            ],
            shortTitle: "Get Twain Wallpaper",
            systemImageName: "photo"
        )
        AppShortcut(
            intent: CheckTwainWallpaperIntent(),
            phrases: [
                "Check \(.applicationName) wallpaper",
                "Is there a new \(.applicationName) wallpaper",
            ],
            shortTitle: "Check Twain Wallpaper",
            systemImageName: "arrow.triangle.2.circlepath"
        )
    }
}
