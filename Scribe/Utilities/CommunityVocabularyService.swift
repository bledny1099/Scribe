import Foundation
import SwiftUI
import OSLog
import FirebaseCore
import FirebaseFirestore

private let logger = Logger(subsystem: "com.aleksei.scribe", category: "CommunityVocabularyService")

public struct CommunityTerm: Codable, Identifiable, Hashable, Sendable {
    public var id: String { term.lowercased() }
    public let term: String
    public let aliases: [String]

    public init(term: String, aliases: [String]) {
        self.term = term
        // Strict deduplication of aliases: case-insensitive & trimmed
        var seen = Set<String>()
        var cleanAliases: [String] = []
        for alias in aliases {
            let trimmed = alias.trimmingCharacters(in: .whitespacesAndNewlines)
            let lower = trimmed.lowercased()
            if !trimmed.isEmpty && lower != term.lowercased() && !seen.contains(lower) {
                seen.insert(lower)
                cleanAliases.append(trimmed)
            }
        }
        self.aliases = cleanAliases
    }
}

public struct CommunityCategory: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let languages: [String]?
    public let terms: [CommunityTerm]

    public init(id: String, name: String, languages: [String]?, terms: [CommunityTerm]) {
        self.id = id
        self.name = name
        self.languages = languages
        // Deduplicate terms inside category
        var seen = Set<String>()
        var cleanTerms: [CommunityTerm] = []
        for t in terms {
            let lower = t.term.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if !lower.isEmpty && !seen.contains(lower) {
                seen.insert(lower)
                cleanTerms.append(t)
            }
        }
        self.terms = cleanTerms
    }
}

public struct CommunityDictionaryPayload: Codable, Sendable {
    public let version: Int
    public let lastUpdated: String
    public let description: String
    public let repository: String?
    public let contributing: String?
    public let categories: [CommunityCategory]
}

/// Manages 5-minute background bi-directional syncing of the open community dictionary from GitHub and Firestore.
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
    @Published public var lastContributionMessage: String? = nil

    private let lock = NSLock()
    private var _cachedAllTerms: [String] = []
    private var _cachedTransliterationMap: [String: String] = [:]
    private var syncTask: Task<Void, Never>? = nil

    private let cacheFileName = "community_dictionary_cache.json"

    private var db: Firestore? {
        return FirebaseApp.app() != nil ? Firestore.firestore() : nil
    }

    private var cacheFileURL: URL? {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        let dir = appSupport.appendingPathComponent("com.aleksei.scribe", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(cacheFileName)
    }

    private init() {
        loadCachedOrBundled()
        startPeriodicSync()
    }

    deinit {
        syncTask?.cancel()
    }

    // MARK: - 5-Minute Periodic Bi-Directional Sync

    public func startPeriodicSync() {
        syncTask?.cancel()
        syncTask = Task { [weak self] in
            // Initial sync on launch
            await self?.performBiDirectionalSync()

            // Recurring 5-minute loop (300 seconds)
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 300_000_000_000)
                guard !Task.isCancelled else { break }
                await self?.performBiDirectionalSync()
            }
        }
    }

    public func performBiDirectionalSync() async {
        // 1. Pull latest community dictionary from GitHub
        await refreshFromGitHub()

        // 2. Anonymously push unique new words to community pool if allowed
        _ = await pushLocalContributionsIfAllowed()
    }

    /// Triggers manual sync and returns count of downloaded terms and newly uploaded words
    @MainActor
    public func manualSyncAndContribute() async -> (downloaded: Int, uploaded: Int) {
        await refreshFromGitHub()
        let uploadedCount = await pushLocalContributionsIfAllowed()
        if uploadedCount > 0 {
            lastContributionMessage = "Uploaded \(uploadedCount) new terms to community pool"
        } else {
            lastContributionMessage = "Dictionary up to date (\(totalTermsCount) active words)"
        }
        return (totalTermsCount, uploadedCount)
    }

    // MARK: - Thread-safe accessors for Audio & Transcription Pipelines

    /// Thread-safe flattened list of all community terms (strictly deduplicated)
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

    private func getCachedTermsSetLower() -> Set<String> {
        lock.lock()
        defer { lock.unlock() }
        return Set(_cachedAllTerms.map { $0.lowercased() })
    }

    private func updateCache(terms: [String], map: [String: String]) {
        lock.lock()
        _cachedAllTerms = terms
        _cachedTransliterationMap = map
        lock.unlock()
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

    // MARK: - Anonymous Local Contributions Push

    @discardableResult
    public func pushLocalContributionsIfAllowed() async -> Int {
        guard UserDefaults.standard.bool(forKey: "allowAnonymousVocabularyContribution") else { return 0 }

        // Gather all local words from active vocabulary
        let rawVocab = UserDefaults.standard.string(forKey: "vocabulary") ?? ""
        var localWords = rawVocab.components(separatedBy: CharacterSet(charactersIn: ",\n;"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count >= 2 }

        // Also gather words from presets
        if let presetsData = UserDefaults.standard.data(forKey: "customVocabularyPresets"),
           let presets = try? JSONDecoder().decode([VocabularyPreset].self, from: presetsData) {
            for preset in presets {
                for w in preset.words {
                    let trimmed = w.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmed.count >= 2 {
                        localWords.append(trimmed)
                    }
                }
            }
        }

        guard !localWords.isEmpty else { return 0 }

        // Deduplicate against existing community dictionary
        let existingTermsLower = getCachedTermsSetLower()
        var previouslySubmitted = Set(UserDefaults.standard.stringArray(forKey: "submittedCommunityWordsHistory") ?? [])

        var wordsToSubmit: [String] = []
        for word in localWords {
            let lower = word.lowercased()
            if !existingTermsLower.contains(lower) && !previouslySubmitted.contains(lower) {
                wordsToSubmit.append(word)
                previouslySubmitted.insert(lower)
            }
        }

        guard !wordsToSubmit.isEmpty else { return 0 }

        // Save submitted history so we never send duplicates
        UserDefaults.standard.set(Array(previouslySubmitted), forKey: "submittedCommunityWordsHistory")

        // 1. Push to Firestore community contributions pool
        if let firestore = self.db {
            for word in wordsToSubmit {
                let docId = word.lowercased().addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? UUID().uuidString
                try? await firestore.collection("community_contributions").document(docId).setData([
                    "term": word,
                    "count": FieldValue.increment(Int64(1)),
                    "lastSeen": FieldValue.serverTimestamp()
                ], merge: true)
            }
        }

        // 2. Also append directly to local dev repository dictionary if accessible
        let localRepoPath = "/Users/aleksei/Documents/Scribe/vocabulary/community_dictionary.json"
        let localRepoURL = URL(fileURLWithPath: localRepoPath)
        if FileManager.default.fileExists(atPath: localRepoPath),
           let fileData = try? Data(contentsOf: localRepoURL),
           var payload = try? JSONDecoder().decode(CommunityDictionaryPayload.self, from: fileData) {
            var updatedCategories = payload.categories
            if let firstCatIndex = updatedCategories.firstIndex(where: { $0.id == "dev_tech_ai" || $0.id == "general_modern" }) {
                var terms = updatedCategories[firstCatIndex].terms
                for w in wordsToSubmit {
                    if !terms.contains(where: { $0.term.caseInsensitiveCompare(w) == .orderedSame }) {
                        terms.append(CommunityTerm(term: w, aliases: []))
                    }
                }
                let updatedCat = CommunityCategory(
                    id: updatedCategories[firstCatIndex].id,
                    name: updatedCategories[firstCatIndex].name,
                    languages: updatedCategories[firstCatIndex].languages,
                    terms: terms
                )
                updatedCategories[firstCatIndex] = updatedCat

                let newPayload = CommunityDictionaryPayload(
                    version: payload.version + 1,
                    lastUpdated: ISO8601DateFormatter().string(from: Date()),
                    description: payload.description,
                    repository: payload.repository,
                    contributing: payload.contributing,
                    categories: updatedCategories
                )
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                if let encoded = try? encoder.encode(newPayload) {
                    try? encoded.write(to: localRepoURL, options: .atomic)
                }
            }
        }

        logger.info("Successfully pushed \(wordsToSubmit.count) unique words to community dictionary pool")
        return wordsToSubmit.count
    }

    // MARK: - Strict Deduplication & Payload Application

    private func applyPayload(_ payload: CommunityDictionaryPayload) {
        var map: [String: String] = [:]
        var termsSeen = Set<String>()
        var uniqueTerms: [String] = []
        var cleanCategories: [CommunityCategory] = []

        for cat in payload.categories {
            var catTerms: [CommunityTerm] = []

            for t in cat.terms {
                let trimmed = t.term.trimmingCharacters(in: .whitespacesAndNewlines)
                let lower = trimmed.lowercased()

                if !trimmed.isEmpty && !termsSeen.contains(lower) {
                    termsSeen.insert(lower)
                    uniqueTerms.append(trimmed)

                    // Deduplicate aliases for this term
                    var cleanAliases: [String] = []
                    var aliasSeen = Set<String>()

                    for alias in t.aliases {
                        let aTrimmed = alias.trimmingCharacters(in: .whitespacesAndNewlines)
                        let aLower = aTrimmed.lowercased()
                        if !aTrimmed.isEmpty && aLower != lower && !aliasSeen.contains(aLower) {
                            aliasSeen.insert(aLower)
                            cleanAliases.append(aTrimmed)
                            map[aLower] = trimmed
                        }
                    }

                    map[lower] = trimmed
                    catTerms.append(CommunityTerm(term: trimmed, aliases: cleanAliases))
                }
            }

            if !catTerms.isEmpty {
                cleanCategories.append(CommunityCategory(
                    id: cat.id,
                    name: cat.name,
                    languages: cat.languages,
                    terms: catTerms
                ))
            }
        }

        updateCache(terms: uniqueTerms, map: map)

        Task { @MainActor in
            self.categories = cleanCategories
            self.totalTermsCount = uniqueTerms.count
            if let savedDate = UserDefaults.standard.object(forKey: "communityDictionaryLastSync") as? Date {
                self.lastSyncDate = savedDate
            } else {
                self.lastSyncDate = Date()
            }
        }
    }
}
