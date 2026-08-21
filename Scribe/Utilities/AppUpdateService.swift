import Foundation
import SwiftUI
import AppKit

/// Service for monitoring GitHub releases and automatically updating Scribe.
@MainActor
public final class AppUpdateService: ObservableObject {
    public static let shared = AppUpdateService()

    public static let repoOwner = "bledny1099"
    public static let repoName = "Scribe"

    @Published public var isChecking: Bool = false
    @Published public var updateAvailable: Bool = false
    @Published public var latestVersion: String = ""
    @Published public var currentVersion: String = ""
    @Published public var releaseTitle: String = ""
    @Published public var releaseNotes: String = ""
    @Published public var releasePageURL: URL? = nil
    @Published public var downloadURL: URL? = nil
    @Published public var isDownloading: Bool = false
    @Published public var downloadProgress: Double = 0.0
    @Published public var statusMessage: String = ""
    @Published public var lastCheckTime: Date? = nil

    @Published public var justCheckedUpToDate: Bool = false
    private var feedbackResetTask: Task<Void, Never>? = nil

    private var timer: Timer?
    private let checkInterval: TimeInterval = 30.0

    private init() {
        self.currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "2.4.3"
        startPeriodicChecks()
    }

    /// Starts periodic 30-second check for new GitHub releases.
    public func startPeriodicChecks() {
        timer?.invalidate()
        // Check immediately on startup
        Task {
            await checkForUpdates(silent: true)
        }
        // Then poll every 30 seconds
        timer = Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.checkForUpdates(silent: true)
            }
        }
    }

    public func stopPeriodicChecks() {
        timer?.invalidate()
        timer = nil
    }

    /// Checks the GitHub API for newer releases.
    public func checkForUpdates(silent: Bool = false) async {
        guard !isChecking else { return }
        isChecking = true
        if !silent {
            feedbackResetTask?.cancel()
            justCheckedUpToDate = false
            statusMessage = "Checking for updates..."
        }

        defer {
            isChecking = false
            lastCheckTime = Date()
        }

        let apiURLString = "https://api.github.com/repos/\(Self.repoOwner)/\(Self.repoName)/releases/latest"
        guard let url = URL(string: apiURLString) else {
            if !silent { statusMessage = "Invalid update URL" }
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.setValue("ScribeApp-UpdateChecker", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 6

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                if !silent { statusMessage = "No response from server" }
                return
            }

            if httpResponse.statusCode == 200 {
                guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    if !silent { statusMessage = "Could not parse release data" }
                    return
                }

                let tagName = (json["tag_name"] as? String ?? "")
                    .trimmingCharacters(in: CharacterSet(charactersIn: "vV "))
                let title = json["name"] as? String ?? "v\(tagName)"
                let body = json["body"] as? String ?? ""
                let htmlUrlString = json["html_url"] as? String
                let htmlUrl = htmlUrlString != nil ? URL(string: htmlUrlString!) : nil

                // Check for DMG / Zip assets
                var assetDownloadURL: URL? = nil
                if let assets = json["assets"] as? [[String: Any]] {
                    for asset in assets {
                        if let name = asset["name"] as? String,
                           let downloadStr = asset["browser_download_url"] as? String,
                           (name.hasSuffix(".dmg") || name.hasSuffix(".zip") || name.hasSuffix(".app.zip")) {
                            assetDownloadURL = URL(string: downloadStr)
                            break
                        }
                    }
                }

                self.latestVersion = tagName
                self.releaseTitle = title
                self.releaseNotes = body
                self.releasePageURL = htmlUrl
                self.downloadURL = assetDownloadURL

                if isNewerVersion(remote: tagName, current: currentVersion) {
                    self.updateAvailable = true
                    self.justCheckedUpToDate = false
                    self.statusMessage = "Update available: v\(tagName)"
                } else {
                    self.updateAvailable = false
                    if !silent {
                        self.statusMessage = "Scribe is up to date (v\(currentVersion))"
                        self.justCheckedUpToDate = true
                        feedbackResetTask?.cancel()
                        feedbackResetTask = Task { @MainActor [weak self] in
                            try? await Task.sleep(nanoseconds: 2_500_000_000)
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                self?.justCheckedUpToDate = false
                            }
                        }
                    }
                }
            } else if httpResponse.statusCode == 404 {
                // If releases are not yet published, fallback to tags API
                await checkTagsFallback(silent: silent)
            } else {
                if !silent {
                    statusMessage = "Server returned status \(httpResponse.statusCode)"
                }
            }
        } catch {
            if !silent {
                statusMessage = "Update check failed: \(error.localizedDescription)"
            }
        }
    }

    private func checkTagsFallback(silent: Bool) async {
        let tagsURLString = "https://api.github.com/repos/\(Self.repoOwner)/\(Self.repoName)/tags"
        guard let url = URL(string: tagsURLString) else { return }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.setValue("ScribeApp-UpdateChecker", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
                  let tags = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                  let firstTag = tags.first,
                  let tagNameRaw = firstTag["name"] as? String else {
                if !silent { statusMessage = "Scribe is up to date (v\(currentVersion))" }
                return
            }

            let tagName = tagNameRaw.trimmingCharacters(in: CharacterSet(charactersIn: "vV "))
            self.latestVersion = tagName
            self.releaseTitle = "Version \(tagName)"
            self.releasePageURL = URL(string: "https://github.com/\(Self.repoOwner)/\(Self.repoName)/releases")

            if isNewerVersion(remote: tagName, current: currentVersion) {
                self.updateAvailable = true
                self.statusMessage = "Update available: v\(tagName)"
            } else {
                self.updateAvailable = false
                if !silent {
                    self.statusMessage = "Scribe is up to date (v\(currentVersion))"
                }
            }
        } catch {
            if !silent {
                statusMessage = "Tag check failed: \(error.localizedDescription)"
            }
        }
    }

    /// Compares two semantic version strings (e.g. "2.1.1" vs "2.1.0").
    public func isNewerVersion(remote: String, current: String) -> Bool {
        let remoteParts = remote.split(separator: ".").compactMap { Int($0.filter { $0.isNumber }) }
        let currentParts = current.split(separator: ".").compactMap { Int($0.filter { $0.isNumber }) }

        let maxCount = max(remoteParts.count, currentParts.count)
        for i in 0..<maxCount {
            let r = i < remoteParts.count ? remoteParts[i] : 0
            let c = i < currentParts.count ? currentParts[i] : 0
            if r > c { return true }
            if r < c { return false }
        }
        return false
    }

    /// Performs the update: either downloads and launches installer or opens GitHub release.
    public func performUpdate() {
        if let directDownload = downloadURL {
            downloadAndInstall(from: directDownload)
        } else if let releasePage = releasePageURL {
            NSWorkspace.shared.open(releasePage)
        } else if let fallback = URL(string: "https://github.com/\(Self.repoOwner)/\(Self.repoName)/releases") {
            NSWorkspace.shared.open(fallback)
        }
    }

    /// Downloads and automatically triggers update installation.
    private func downloadAndInstall(from url: URL) {
        guard !isDownloading else { return }
        
        // Security check: Only allow downloads from official GitHub domain
        guard let host = url.host?.lowercased(),
              host == "github.com" || host.hasSuffix(".github.com") || host.hasSuffix(".githubusercontent.com") else {
            statusMessage = "Untrusted update source"
            if let page = self.releasePageURL {
                NSWorkspace.shared.open(page)
            }
            return
        }

        isDownloading = true
        downloadProgress = 0.0
        statusMessage = "Downloading update..."

        Task {
            do {
                let (tempURL, response) = try await URLSession.shared.download(from: url)
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    await MainActor.run {
                        self.isDownloading = false
                        self.statusMessage = "Failed to download update file"
                        if let page = self.releasePageURL {
                            NSWorkspace.shared.open(page)
                        }
                    }
                    return
                }

                let tempDMGName = "Scribe_v\(self.latestVersion.isEmpty ? "latest" : self.latestVersion).dmg"
                let targetDMG = FileManager.default.temporaryDirectory.appendingPathComponent(tempDMGName)
                try? FileManager.default.removeItem(at: targetDMG)
                try FileManager.default.moveItem(at: tempURL, to: targetDMG)

                await MainActor.run {
                    self.isDownloading = false
                    self.statusMessage = "Opening update package..."
                    NSWorkspace.shared.open(targetDMG)
                }
            } catch {
                await MainActor.run {
                    self.isDownloading = false
                    self.statusMessage = "Download failed, opening browser..."
                    if let page = self.releasePageURL {
                        NSWorkspace.shared.open(page)
                    }
                }
            }
        }
    }
}
