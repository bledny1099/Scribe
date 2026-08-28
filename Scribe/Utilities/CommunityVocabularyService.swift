import Foundation
import SwiftUI
import OSLog
import FirebaseCore
import FirebaseFirestore

private let logger = Logger(subsystem: "com.aleksei.scribe", category: "CommunityVocabularyService")

public struct CommunityCategory: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let languages: [String]?
    public var terms: [String]

    enum CodingKeys: String, CodingKey {
        case id, name, languages, terms
    }

    public init(id: String, name: String, languages: [String]?, terms: [String]) {
        self.id = id
        self.name = name
        self.languages = languages
        var seen = Set<String>()
        var cleanTerms: [String] = []
        for t in terms {
            let trimmed = t.trimmingCharacters(in: .whitespacesAndNewlines)
            let lower = trimmed.lowercased()
            if !trimmed.isEmpty && !seen.contains(lower) {
                seen.insert(lower)
                cleanTerms.append(trimmed)
            }
        }
        self.terms = cleanTerms
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.languages = try container.decodeIfPresent([String].self, forKey: .languages)

        if let stringTerms = try? container.decode([String].self, forKey: .terms) {
            var seen = Set<String>()
            var clean: [String] = []
            for t in stringTerms {
                let trimmed = t.trimmingCharacters(in: .whitespacesAndNewlines)
                let lower = trimmed.lowercased()
                if !trimmed.isEmpty && !seen.contains(lower) {
                    seen.insert(lower)
                    clean.append(trimmed)
                }
            }
            self.terms = clean
        } else if let objectTerms = try? container.decode([LegacyCommunityTerm].self, forKey: .terms) {
            var seen = Set<String>()
            var clean: [String] = []
            for t in objectTerms {
                let trimmed = t.term.trimmingCharacters(in: .whitespacesAndNewlines)
                let lower = trimmed.lowercased()
                if !trimmed.isEmpty && !seen.contains(lower) {
                    seen.insert(lower)
                    clean.append(trimmed)
                }
            }
            self.terms = clean
        } else {
            self.terms = []
        }
    }
}

public struct LegacyCommunityTerm: Codable {
    public let term: String
    public let aliases: [String]?
}

public struct CommunityDictionaryPayload: Codable, Sendable {
    public let version: Int
    public let lastUpdated: String
    public let description: String
    public let repository: String?
    public let contributing: String?
    public let categories: [CommunityCategory]
}

public struct PhoneticRecognizerPayload: Codable, Sendable {
    public let version: Int?
    public let lastUpdated: String?
    public let description: String?
    public let transliterations: [String: String]?
    public let acousticRules: [PhoneticAcousticRule]?

    enum CodingKeys: String, CodingKey {
        case version, lastUpdated, description, transliterations
        case acousticRules = "acoustic_rules"
    }
}

public struct PhoneticAcousticRule: Codable, Sendable {
    public let pattern: String
    public let template: String
}

/// Manages 5-minute background bi-directional syncing of the vocabulary from Firestore and embedded binary definitions.
/// No plain text dictionary files are stored in the public repository.
public final class CommunityVocabularyService: ObservableObject, @unchecked Sendable {
    public static let shared = CommunityVocabularyService()

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
    private let phoneticCacheFileName = "phonetic_recognizer_cache.json"

    private var db: Firestore? {
        return FirebaseApp.app() != nil ? Firestore.firestore() : nil
    }

    private var cacheFileURL: URL? {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        let dir = appSupport.appendingPathComponent("com.aleksei.scribe", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(cacheFileName)
    }

    private var phoneticCacheFileURL: URL? {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        let dir = appSupport.appendingPathComponent("com.aleksei.scribe", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(phoneticCacheFileName)
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
        // 1. Pull latest terms from Firestore cloud database
        await refreshFromCloud()

        // 2. Anonymously push unique new words to community pool if allowed
        _ = await pushLocalContributionsIfAllowed()
    }

    /// Triggers manual sync and returns count of downloaded terms and newly uploaded words
    @MainActor
    public func manualSyncAndContribute() async -> (downloaded: Int, uploaded: Int) {
        await refreshFromCloud()
        let uploadedCount = await pushLocalContributionsIfAllowed()
        if uploadedCount > 0 {
            lastContributionMessage = "Uploaded \(uploadedCount) new terms to cloud pool"
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

    public func getCachedTermsSetLower() -> Set<String> {
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
        var phoneticMap: [String: String] = EmbeddedVocabularyData.defaultPhoneticMap

        // Load cached phonetic map updates if available
        if let pCacheURL = phoneticCacheFileURL,
           let pData = try? Data(contentsOf: pCacheURL),
           let pPayload = try? JSONDecoder().decode(PhoneticRecognizerPayload.self, from: pData),
           let trans = pPayload.transliterations {
            for (k, v) in trans {
                phoneticMap[k] = v
            }
        }

        // Try Cache File first for clean terms dictionary
        if let cacheURL = cacheFileURL,
           let data = try? Data(contentsOf: cacheURL),
           let payload = try? JSONDecoder().decode(CommunityDictionaryPayload.self, from: data) {
            applyPayload(payload, basePhoneticMap: phoneticMap)
            return
        }

        // Fallback directly to embedded compiled vocabulary data
        let embeddedPayload = CommunityDictionaryPayload(
            version: 4,
            lastUpdated: "2026-08-28",
            description: "Compiled internal vocabulary.",
            repository: nil,
            contributing: nil,
            categories: EmbeddedVocabularyData.defaultCategories
        )
        applyPayload(embeddedPayload, basePhoneticMap: phoneticMap)
    }

    @MainActor
    public func refreshFromCloud() async {
        guard !isSyncing else { return }
        isSyncing = true
        syncError = nil

        defer { isSyncing = false }

        guard let firestore = self.db else {
            // Offline or Firebase uninitialized — ensure embedded categories are active
            loadCachedOrBundled()
            return
        }

        do {
            // Fetch updated vocabulary categories from Firestore if published
            let snapshot = try await firestore.collection("community_dictionary").document("lexicon").getDocument()
            if let data = snapshot.data(),
               let jsonStr = data["payload"] as? String,
               let jsonData = jsonStr.data(using: .utf8),
               let payload = try? JSONDecoder().decode(CommunityDictionaryPayload.self, from: jsonData) {
                applyPayload(payload, basePhoneticMap: EmbeddedVocabularyData.defaultPhoneticMap)

                // Cache locally
                if let cacheURL = cacheFileURL {
                    try? jsonData.write(to: cacheURL, options: .atomic)
                }
            }

            lastSyncDate = Date()
            UserDefaults.standard.set(lastSyncDate, forKey: "communityDictionaryLastSync")
            logger.info("Successfully refreshed cloud dictionary (\(self.totalTermsCount) terms)")
        } catch {
            logger.warning("Cloud dictionary refresh: \(error.localizedDescription)")
            syncError = error.localizedDescription
        }
    }

    // MARK: - Local & Anonymous Community Synchronization

    @discardableResult
    public func syncLocalWordsToDictionary(rawVocabulary: String? = nil) -> Int {
        let rawVocab = rawVocabulary ?? UserDefaults.standard.string(forKey: "vocabulary") ?? ""
        var localWords = rawVocab.components(separatedBy: CharacterSet(charactersIn: ",\n;"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count >= 2 }

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

        // Read current cached or embedded dictionary
        var currentCategories = categories.isEmpty ? EmbeddedVocabularyData.defaultCategories : categories
        var allExistingTermsLower = Set<String>()
        for cat in currentCategories {
            for t in cat.terms {
                allExistingTermsLower.insert(t.lowercased())
            }
        }

        var updatedPhoneticMap = transliterationMap
        var newWordsAdded = 0

        for word in localWords {
            let lower = word.lowercased()
            if !allExistingTermsLower.contains(lower) {
                let autoAliases = generatePhoneticAliases(for: word)
                for alias in autoAliases {
                    let aLower = alias.lowercased()
                    if updatedPhoneticMap[aLower] == nil {
                        updatedPhoneticMap[aLower] = word
                    }
                }

                // Pick best category
                let catIndex: Int
                let wordLower = lower
                if wordLower.contains("хоккей") || wordLower.contains("мам") || wordLower.contains("пап") || wordLower.contains("бат") || wordLower.contains("мих") {
                    if let idx = currentCategories.firstIndex(where: { $0.id == "slang_and_culture" || $0.id == "social_media_services" }) {
                        catIndex = idx
                    } else {
                        catIndex = 0
                    }
                } else if wordLower.contains("push") || wordLower.contains("пуш") || wordLower.contains("фикс") || wordLower.contains("code") || wordLower.contains("ide") {
                    catIndex = currentCategories.firstIndex(where: { $0.id == "developer_tools" }) ?? 0
                } else if wordLower.contains("scribe") || wordLower.contains("aether") || wordLower.contains("транскриб") {
                    catIndex = currentCategories.firstIndex(where: { $0.id == "scribe_ecosystem" }) ?? 0
                } else {
                    catIndex = currentCategories.firstIndex(where: { $0.id == "slang_and_culture" }) ?? 0
                }

                currentCategories[catIndex].terms.append(word)
                allExistingTermsLower.insert(lower)
                newWordsAdded += 1
            }
        }

        guard newWordsAdded > 0 else { return 0 }

        let newPayload = CommunityDictionaryPayload(
            version: 5,
            lastUpdated: ISO8601DateFormatter().string(from: Date()),
            description: "Locally augmented dictionary.",
            repository: nil,
            contributing: nil,
            categories: currentCategories
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let encoded = try? encoder.encode(newPayload) {
            if let cacheURL = cacheFileURL {
                try? encoded.write(to: cacheURL, options: .atomic)
            }
        }

        applyPayload(newPayload, basePhoneticMap: updatedPhoneticMap)
        logger.info("Successfully updated local runtime cache with \(newWordsAdded) new words")
        return newWordsAdded
    }

    public func generatePhoneticAliases(for term: String) -> [String] {
        var aliases: [String] = []
        let lower = term.lowercased()

        switch lower {
        case "хоккей":
            aliases = ["hockey", "хакей"]
        case "миха":
            aliases = ["мих", "михаил"]
        case "мам":
            aliases = ["мама", "мамка"]
        case "пап":
            aliases = ["папа", "папка"]
        case "батя":
            aliases = ["батяня", "бать"]
        case "пуш":
            aliases = ["push", "пушить", "пушнуть"]
        case "пофикси":
            aliases = ["фикси", "пофиксить", "зафикси"]
        case "транскрибатор":
            aliases = ["транскриптор", "транскрибация", "transcriber"]
        case "aether":
            aliases = ["эфир", "эйтер", "аэтер"]
        case "readme":
            aliases = ["ридми", "редми", "read me"]
        case "buzz":
            aliases = ["базз", "баз"]
        case "paperclip":
            aliases = ["пейперклип", "скрепка", "paper clip"]
        case "kai angel":
            aliases = ["кай энжел", "кай ангел", "кайэнджел"]
        case "9mice":
            aliases = ["девять майс", "9 майс", "найнмайс"]
        case "viperr":
            aliases = ["вайпер", "вайперр"]
        default:
            break
        }
        return aliases
    }

    @discardableResult
    public func pushLocalContributionsIfAllowed() async -> Int {
        // First sync to local dictionary files
        _ = syncLocalWordsToDictionary()

        guard UserDefaults.standard.bool(forKey: "allowAnonymousVocabularyContribution") else { return 0 }

        // Gather all local words from active vocabulary
        let rawVocab = UserDefaults.standard.string(forKey: "vocabulary") ?? ""
        var localWords = rawVocab.components(separatedBy: CharacterSet(charactersIn: ",\n;"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count >= 2 }

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

        var previouslySubmitted = Set(UserDefaults.standard.stringArray(forKey: "submittedCommunityWordsHistory") ?? [])

        var wordsToSubmit: [String] = []
        for word in localWords {
            let lower = word.lowercased()
            if !previouslySubmitted.contains(lower) {
                wordsToSubmit.append(word)
                previouslySubmitted.insert(lower)
            }
        }

        guard !wordsToSubmit.isEmpty else { return 0 }

        UserDefaults.standard.set(Array(previouslySubmitted), forKey: "submittedCommunityWordsHistory")

        // Push to Firestore community contributions pool
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

        logger.info("Successfully pushed \(wordsToSubmit.count) unique words to community dictionary pool")
        return wordsToSubmit.count
    }

    // MARK: - Strict Deduplication & Payload Application

    private func applyPayload(_ payload: CommunityDictionaryPayload, basePhoneticMap: [String: String] = [:]) {
        var map = basePhoneticMap
        var termsSeen = Set<String>()
        var uniqueTerms: [String] = []
        var cleanCategories: [CommunityCategory] = []

        for cat in payload.categories {
            var catTerms: [String] = []

            for t in cat.terms {
                let trimmed = t.trimmingCharacters(in: .whitespacesAndNewlines)
                let lower = trimmed.lowercased()

                if !trimmed.isEmpty && !termsSeen.contains(lower) {
                    termsSeen.insert(lower)
                    uniqueTerms.append(trimmed)
                    catTerms.append(trimmed)

                    map[lower] = trimmed

                    // Generate automatic aliases if not already mapped
                    let autoAliases = generatePhoneticAliases(for: trimmed)
                    for a in autoAliases {
                        let aLower = a.lowercased()
                        if map[aLower] == nil {
                            map[aLower] = trimmed
                        }
                    }
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

        DispatchQueue.main.async {
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
