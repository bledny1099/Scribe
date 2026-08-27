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

/// Manages 5-minute background bi-directional syncing of the open community dictionary from GitHub and Firestore.
/// Clean public dictionary stores terms only; phonetic speech recognition mappings are stored and loaded separately.
public final class CommunityVocabularyService: ObservableObject, @unchecked Sendable {
    public static let shared = CommunityVocabularyService()

    public static let remoteDictionaryURL = URL(string: "https://raw.githubusercontent.com/bledny1099/Scribe/main/vocabulary/community_dictionary.json")!
    public static let remotePhoneticMapURL = URL(string: "https://raw.githubusercontent.com/bledny1099/Scribe/main/vocabulary/phonetic_recognizer_map.json")!
    public static let githubDictionaryPageURL = URL(string: "https://github.com/bledny1099/Scribe/blob/main/vocabulary/community_dictionary.json")!
    public static let githubContributeURL = URL(string: "https://github.com/bledny1099/Scribe/issues/new?title=%5BVocabulary%5D+Propose+new+word&body=Word%2FTerm%3A%0ACategory%3A")!

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
        // 1. Pull latest community dictionary and phonetic recognizer map from GitHub
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
        // 0. Load phonetic recognizer map (transliterations & acoustic recognition mappings)
        var phoneticMap: [String: String] = [:]

        if let pCacheURL = phoneticCacheFileURL,
           let pData = try? Data(contentsOf: pCacheURL),
           let pPayload = try? JSONDecoder().decode(PhoneticRecognizerPayload.self, from: pData),
           let trans = pPayload.transliterations {
            phoneticMap = trans
        } else if let bundleURL = Bundle.main.url(forResource: "phonetic_recognizer_map", withExtension: "json"),
                  let pData = try? Data(contentsOf: bundleURL),
                  let pPayload = try? JSONDecoder().decode(PhoneticRecognizerPayload.self, from: pData),
                  let trans = pPayload.transliterations {
            phoneticMap = trans
        } else {
            let devPhoneticURL = URL(fileURLWithPath: "/Users/aleksei/Documents/Scribe/vocabulary/phonetic_recognizer_map.json")
            if let pData = try? Data(contentsOf: devPhoneticURL),
               let pPayload = try? JSONDecoder().decode(PhoneticRecognizerPayload.self, from: pData),
               let trans = pPayload.transliterations {
                phoneticMap = trans
            }
        }

        // 1. Try Cache File first for clean terms dictionary
        if let cacheURL = cacheFileURL,
           let data = try? Data(contentsOf: cacheURL),
           let payload = try? JSONDecoder().decode(CommunityDictionaryPayload.self, from: data) {
            applyPayload(payload, basePhoneticMap: phoneticMap)
            return
        }

        // 2. Fallback to bundled json in App bundle
        if let bundleURL = Bundle.main.url(forResource: "community_dictionary", withExtension: "json"),
           let data = try? Data(contentsOf: bundleURL),
           let payload = try? JSONDecoder().decode(CommunityDictionaryPayload.self, from: data) {
            applyPayload(payload, basePhoneticMap: phoneticMap)
            return
        }

        // 3. Fallback to local repository path if accessible
        let devURL = URL(fileURLWithPath: "/Users/aleksei/Documents/Scribe/vocabulary/community_dictionary.json")
        if let data = try? Data(contentsOf: devURL),
           let payload = try? JSONDecoder().decode(CommunityDictionaryPayload.self, from: data) {
            applyPayload(payload, basePhoneticMap: phoneticMap)
            return
        }
    }

    @MainActor
    public func refreshFromGitHub() async {
        guard !isSyncing else { return }
        isSyncing = true
        syncError = nil

        do {
            // 1. Fetch clean dictionary
            var request = URLRequest(url: Self.remoteDictionaryURL)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.timeoutInterval = 10

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                throw URLError(.badServerResponse)
            }

            let payload = try JSONDecoder().decode(CommunityDictionaryPayload.self, from: data)

            // 2. Fetch separate phonetic recognizer map
            var phoneticMap: [String: String] = [:]
            var pRequest = URLRequest(url: Self.remotePhoneticMapURL)
            pRequest.cachePolicy = .reloadIgnoringLocalCacheData
            pRequest.timeoutInterval = 10

            if let (pData, pResponse) = try? await URLSession.shared.data(for: pRequest),
               let pHttp = pResponse as? HTTPURLResponse, (200...299).contains(pHttp.statusCode),
               let pPayload = try? JSONDecoder().decode(PhoneticRecognizerPayload.self, from: pData),
               let trans = pPayload.transliterations {
                phoneticMap = trans
                if let pCache = phoneticCacheFileURL {
                    try? pData.write(to: pCache, options: .atomic)
                }
            }

            applyPayload(payload, basePhoneticMap: phoneticMap)

            // Cache to disk
            if let cacheURL = cacheFileURL {
                try? data.write(to: cacheURL, options: .atomic)
            }

            lastSyncDate = Date()
            UserDefaults.standard.set(lastSyncDate, forKey: "communityDictionaryLastSync")
            logger.info("Successfully refreshed clean community dictionary (\(self.totalTermsCount) terms)")
        } catch {
            logger.warning("Failed to refresh community dictionary: \(error.localizedDescription)")
            syncError = error.localizedDescription
        }

        isSyncing = false
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

        let localRepoPath = "/Users/aleksei/Documents/Scribe/vocabulary/community_dictionary.json"
        let bundledPath = "/Users/aleksei/Documents/Scribe/Scribe/community_dictionary.json"
        let localRepoURL = URL(fileURLWithPath: localRepoPath)
        let bundledURL = URL(fileURLWithPath: bundledPath)

        let localPhoneticRepoPath = "/Users/aleksei/Documents/Scribe/vocabulary/phonetic_recognizer_map.json"
        let bundledPhoneticPath = "/Users/aleksei/Documents/Scribe/Scribe/phonetic_recognizer_map.json"
        let localPhoneticURL = URL(fileURLWithPath: localPhoneticRepoPath)
        let bundledPhoneticURL = URL(fileURLWithPath: bundledPhoneticPath)

        // Read current dictionary
        var currentData: Data? = nil
        if FileManager.default.fileExists(atPath: localRepoPath), let data = try? Data(contentsOf: localRepoURL) {
            currentData = data
        } else if let cacheURL = cacheFileURL, let data = try? Data(contentsOf: cacheURL) {
            currentData = data
        } else if let bundleURL = Bundle.main.url(forResource: "community_dictionary", withExtension: "json"), let data = try? Data(contentsOf: bundleURL) {
            currentData = data
        }

        guard let data = currentData,
              let payload = try? JSONDecoder().decode(CommunityDictionaryPayload.self, from: data) else {
            return 0
        }

        // Read current phonetic recognizer map
        var currentPhoneticPayload: PhoneticRecognizerPayload? = nil
        if FileManager.default.fileExists(atPath: localPhoneticRepoPath), let pData = try? Data(contentsOf: localPhoneticURL) {
            currentPhoneticPayload = try? JSONDecoder().decode(PhoneticRecognizerPayload.self, from: pData)
        } else if let pCacheURL = phoneticCacheFileURL, let pData = try? Data(contentsOf: pCacheURL) {
            currentPhoneticPayload = try? JSONDecoder().decode(PhoneticRecognizerPayload.self, from: pData)
        }

        var allExistingTermsLower = Set<String>()
        for cat in payload.categories {
            for t in cat.terms {
                allExistingTermsLower.insert(t.lowercased())
            }
        }

        var updatedPhoneticMap = currentPhoneticPayload?.transliterations ?? transliterationMap
        var newWordsAdded = 0
        var updatedCategories = payload.categories

        for word in localWords {
            let lower = word.lowercased()
            if !allExistingTermsLower.contains(lower) {
                let aliases = generatePhoneticAliases(for: word)
                for a in aliases {
                    updatedPhoneticMap[a.lowercased()] = word
                }

                // Pick best category
                let catIndex: Int
                let wordLower = lower
                if wordLower.contains("хоккей") || wordLower.contains("мам") || wordLower.contains("пап") || wordLower.contains("бат") || wordLower.contains("мих") {
                    if let idx = updatedCategories.firstIndex(where: { $0.id == "slang_and_culture" || $0.id == "social_media_services" }) {
                        catIndex = idx
                    } else {
                        catIndex = 0
                    }
                } else if wordLower.contains("push") || wordLower.contains("пуш") || wordLower.contains("фикс") || wordLower.contains("code") || wordLower.contains("ide") {
                    catIndex = updatedCategories.firstIndex(where: { $0.id == "developer_tools" }) ?? 0
                } else if wordLower.contains("scribe") || wordLower.contains("aether") || wordLower.contains("транскриб") {
                    catIndex = updatedCategories.firstIndex(where: { $0.id == "scribe_ecosystem" }) ?? 0
                } else {
                    catIndex = updatedCategories.firstIndex(where: { $0.id == "slang_and_culture" }) ?? 0
                }

                updatedCategories[catIndex].terms.append(word)
                allExistingTermsLower.insert(lower)
                newWordsAdded += 1
            }
        }

        guard newWordsAdded > 0 else { return 0 }

        // Save clean words-only dictionary
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
            try? encoded.write(to: bundledURL, options: .atomic)
            if let cacheURL = cacheFileURL {
                try? encoded.write(to: cacheURL, options: .atomic)
            }
        }

        // Save separate phonetic recognizer map
        let newPhoneticPayload = PhoneticRecognizerPayload(
            version: (currentPhoneticPayload?.version ?? 1) + 1,
            lastUpdated: ISO8601DateFormatter().string(from: Date()),
            description: "Phonetic mappings, transliterations, and acoustic rules for speech recognition alignment.",
            transliterations: updatedPhoneticMap,
            acousticRules: currentPhoneticPayload?.acousticRules
        )

        if let pEncoded = try? encoder.encode(newPhoneticPayload) {
            try? pEncoded.write(to: localPhoneticURL, options: .atomic)
            try? pEncoded.write(to: bundledPhoneticURL, options: .atomic)
            if let pCache = phoneticCacheFileURL {
                try? pEncoded.write(to: pCache, options: .atomic)
            }
        }

        applyPayload(newPayload, basePhoneticMap: updatedPhoneticMap)
        logger.info("Successfully synced \(newWordsAdded) new local words into clean community dictionary")
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
