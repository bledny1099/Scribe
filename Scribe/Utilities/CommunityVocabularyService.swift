import Foundation
import SwiftUI
import OSLog

private let logger = Logger(subsystem: "com.aleksei.scribe", category: "CommunityVocabularyService")

public struct CommunityTerm: Codable, Identifiable, Hashable, Sendable {
    public var id: String { term }
    public let term: String
    public let aliases: [String]
}

public struct CommunityCategory: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let terms: [CommunityTerm]
}

public struct CommunityDictionaryPayload: Codable, Sendable {
    public let version: Int
    public let lastUpdated: String
    public let description: String
    public let repository: String?
    public let contributing: String?
    public let categories: [CommunityCategory]
}

/// Manages loading and syncing the open community dictionary from GitHub.
/// Thread-safe for audio worker pipelines.
public final class CommunityVocabularyService: ObservableObject, @unchecked Sendable {
    public static let shared = CommunityVocabularyService()

    public static let remoteDictionaryURL = URL(string: "https://raw.githubusercontent.com/bledny1099/Scribe/main/vocabulary/community_dictionary.json")!
    public static let githubDictionaryPageURL = URL(string: "https://github.com/bledny1099/Scribe/blob/main/vocabulary/community_dictionary.json")!
    public static let githubContributeURL = URL(string: "https://github.com/bledny1099/Scribe/issues/new?title=%5BVocabulary%5D+Propose+new+word&body=Word%2FTerm%3A%0AAliases%2FPhonetics%3A%0ACategory%3A")!

    @Published public var categories: [CommunityCategory] = []
    @Published public var totalTermsCount: Int = 0
    @Published public var lastSyncDate: Date? = nil
    @Published public var isSyncing: Bool = false
    @Published public var syncError: String? = nil

    private let lock = NSLock()
    private var _cachedAllTerms: [String] = []
    private var _cachedTransliterationMap: [String: String] = [:]

    private let cacheFileName = "community_dictionary_cache.json"

    private var cacheFileURL: URL? {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        let dir = appSupport.appendingPathComponent("com.aleksei.scribe", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(cacheFileName)
    }

    private init() {
        loadCachedOrBundled()
        Task { @MainActor in
            await self.refreshFromGitHub()
        }
    }

    // MARK: - Thread-safe accessors for Audio & Transcription Pipelines

    /// Thread-safe flattened list of all community terms
    public var allTerms: [String] {
        lock.lock()
        defer { lock.unlock() }
        return _cachedAllTerms
    }

    /// Thread-safe mapping of alias -> Canonical Term (e.g. "чат гпт" -> "ChatGPT")
    public var transliterationMap: [String: String] {
        lock.lock()
        defer { lock.unlock() }
        return _cachedTransliterationMap
    }

    // MARK: - Loading & Syncing

    public func loadCachedOrBundled() {
        // 1. Try Cache File first
        if let cacheURL = cacheFileURL,
           let data = try? Data(contentsOf: cacheURL),
           let payload = try? JSONDecoder().decode(CommunityDictionaryPayload.self, from: data) {
            applyPayload(payload)
            return
        }

        // 2. Fallback to bundled json if present in Bundle or project directory
        if let bundleURL = Bundle.main.url(forResource: "community_dictionary", withExtension: "json"),
           let data = try? Data(contentsOf: bundleURL),
           let payload = try? JSONDecoder().decode(CommunityDictionaryPayload.self, from: data) {
            applyPayload(payload)
            return
        }
    }

    @MainActor
    public func refreshFromGitHub() async {
        guard !isSyncing else { return }
        isSyncing = true
        syncError = nil

        do {
            var request = URLRequest(url: Self.remoteDictionaryURL)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.timeoutInterval = 10

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                throw URLError(.badServerResponse)
            }

            let payload = try JSONDecoder().decode(CommunityDictionaryPayload.self, from: data)
            applyPayload(payload)

            // Cache to disk
            if let cacheURL = cacheFileURL {
                try? data.write(to: cacheURL, options: .atomic)
            }

            lastSyncDate = Date()
            UserDefaults.standard.set(lastSyncDate, forKey: "communityDictionaryLastSync")
            logger.info("Successfully refreshed community dictionary with \(self.totalTermsCount) terms")
        } catch {
            logger.warning("Failed to refresh community dictionary: \(error.localizedDescription)")
            syncError = error.localizedDescription
        }

        isSyncing = false
    }

    private func applyPayload(_ payload: CommunityDictionaryPayload) {
        var map: [String: String] = [:]
        var terms: [String] = []

        for cat in payload.categories {
            for t in cat.terms {
                terms.append(t.term)
                for alias in t.aliases {
                    map[alias.lowercased()] = t.term
                }
                map[t.term.lowercased()] = t.term
            }
        }

        lock.lock()
        _cachedAllTerms = terms
        _cachedTransliterationMap = map
        lock.unlock()

        Task { @MainActor in
            self.categories = payload.categories
            self.totalTermsCount = terms.count
            if let savedDate = UserDefaults.standard.object(forKey: "communityDictionaryLastSync") as? Date {
                self.lastSyncDate = savedDate
            } else {
                self.lastSyncDate = Date()
            }
        }
    }
}
