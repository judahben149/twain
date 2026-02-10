import UserNotifications
import Foundation
import CommonCrypto

class NotificationService: UNNotificationServiceExtension {

    // Must match WallpaperStorageManager.swift and TwainWallpaperIntent.swift
    private let appGroupID = "group.com.judahben149.twain"
    private let wallpaperFileName = "current_wallpaper.jpg"
    private let versionKey = "twain_wallpaper_version"
    private let updatedAtKey = "twain_wallpaper_updated_at"

    private var contentHandler: ((UNNotificationContent) -> Void)?
    private var bestAttemptContent: UNMutableNotificationContent?

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)

        guard let bestAttemptContent = bestAttemptContent else {
            contentHandler(request.content)
            return
        }

        let userInfo = request.content.userInfo

        // Only process wallpaper_sync notifications
        guard let type = userInfo["type"] as? String,
              type == "wallpaper_sync",
              let imageURLString = userInfo["image_url"] as? String,
              let imageURL = URL(string: imageURLString) else {
            contentHandler(bestAttemptContent)
            return
        }

        downloadAndSaveWallpaper(from: imageURL) { [weak self] localFileURL in
            guard let self = self else {
                contentHandler(bestAttemptContent)
                return
            }

            // Attach image to notification for rich preview
            if let localFileURL = localFileURL {
                if let attachment = try? UNNotificationAttachment(
                    identifier: "wallpaper",
                    url: localFileURL,
                    options: [UNNotificationAttachmentOptionsTypeHintKey: "public.jpeg"]
                ) {
                    bestAttemptContent.attachments = [attachment]
                }
            }

            contentHandler(bestAttemptContent)
        }
    }

    override func serviceExtensionTimeWillExpire() {
        // Deliver best-effort content before the system kills us
        if let contentHandler = contentHandler, let bestAttemptContent = bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }

    // MARK: - Private

    private func downloadAndSaveWallpaper(from url: URL, completion: @escaping (URL?) -> Void) {
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self,
                  let data = data,
                  error == nil,
                  let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                completion(nil)
                return
            }

            // Save to App Group container
            guard let containerURL = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: self.appGroupID
            ) else {
                completion(nil)
                return
            }

            let destinationURL = containerURL.appendingPathComponent(self.wallpaperFileName)

            do {
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }
                try data.write(to: destinationURL)
            } catch {
                completion(nil)
                return
            }

            // Update shared UserDefaults with version (MD5 of URL) and timestamp
            let version = self.md5Hash(of: url.absoluteString)
            let defaults = UserDefaults(suiteName: self.appGroupID)
            defaults?.set(version, forKey: self.versionKey)
            defaults?.set(Date().timeIntervalSince1970, forKey: self.updatedAtKey)
            defaults?.synchronize()

            // Copy to temp file for notification attachment (system moves the file)
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("jpg")
            do {
                try data.write(to: tempURL)
                completion(tempURL)
            } catch {
                completion(nil)
            }
        }
        task.resume()
    }

    private func md5Hash(of string: String) -> String {
        guard let data = string.data(using: .utf8) else { return UUID().uuidString }
        var digest = [UInt8](repeating: 0, count: 16)
        _ = data.withUnsafeBytes { bytes in
            CC_MD5(bytes.baseAddress, CC_LONG(data.count), &digest)
        }
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
