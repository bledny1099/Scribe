import Foundation
import os.log

private let logger = Logger(subsystem: "com.aleksei.scribe", category: "UserGrammarProfile")

/// Stores and manages the user's habitual syntactic constructions, directives, sentence starters,
/// and collocations (e.g. "сделай", "давай", "пофикси", "напиши").
/// Feeds directly into AetherContextEngine (prompt conditioning) and AetherLinguisticValidator (hypothesis scoring).
public final class UserGrammarProfile: @unchecked Sendable {
    public static let shared = UserGrammarProfile()

    private let lock = NSLock()
    private var directiveFrequencies: [String: Int] = [:]
    private var collocationFrequencies: [String: Int] = [:]
    private var idiosyncraticWordFrequencies: [String: Int] = [:]
    private var canonicalIdiosyncraticWords: [String: String] = [:]
    private var totalProcessedSegments: Int = 0
    private var lastUpdated: Date = Date()
    private var isDirty = false
    private var saveTask: Task<Void, Never>?

    private let fileURL: URL

    /// Common imperative directives and sentence framing patterns in Russian and English
    private let knownDirectiveRoots: Set<String> = [
        "сделай", "сделайте", "давай", "давайте", "пофикси", "пофиксить",
        "напиши", "напишите", "покажи", "покажите", "добавь", "добавьте",
        "удали", "удалите", "запусти", "запустите", "проверь", "проверьте",
        "обнови", "обновите", "настрой", "настройте", "исправь", "исправьте",
        "сгенерируй", "сгенерируйте", "создай", "создайте", "слушай", "слушайте",
        "посмотри", "посмотрите", "скажи", "скажите", "переведи", "переведите",
        "отправь", "отправьте", "скинь", "скиньте", "найди", "найдите",
        "make", "create", "fix", "add", "remove", "run", "check", "update",
        "write", "show", "generate", "look", "tell", "translate", "send", "find"
    ]

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let scribeDir = appSupport.appendingPathComponent("Scribe", isDirectory: true)
        try? FileManager.default.createDirectory(at: scribeDir, withIntermediateDirectories: true)
        self.fileURL = scribeDir.appendingPathComponent("user_grammar_profile.json")

        loadFromDisk()
    }

    // MARK: - Ingestion API

    /// Analyzes an incoming sentence from the user's typed messages or transcriptions.
    public func recordSentence(_ sentence: String) {
        let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Split into words while keeping compound terms (Next.js, AI-стартап) intact
        let tokenRegex = try? NSRegularExpression(
            pattern: #"(?<![\p{L}\p{N}])[\p{L}\p{N}]+(?:[-_.][\p{L}\p{N}]+)*(?![\p{L}\p{N}])"#,
            options: []
        )
        let nsRange = NSRange(location: 0, length: trimmed.utf16.count)
        let matches = tokenRegex?.matches(in: trimmed, options: [], range: nsRange) ?? []
        let tokens: [String]
        if !matches.isEmpty {
            tokens = matches.compactMap { match in
                guard let range = Range(match.range, in: trimmed) else { return nil }
                let s = String(trimmed[range]).trimmingCharacters(in: CharacterSet(charactersIn: "-_."))
                return s.isEmpty ? nil : s.lowercased().normalizedPlainVocabularyWord()
            }
        } else {
            tokens = trimmed.components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { !$0.isEmpty }
                .map { $0.lowercased().normalizedPlainVocabularyWord() }
        }

        guard !tokens.isEmpty else { return }

        lock.lock()
        totalProcessedSegments += 1

        // 1. Detect Sentence Starters / Directives (first 1-2 words)
        if let first = tokens.first, knownDirectiveRoots.contains(first) {
            directiveFrequencies[first, default: 0] += 1
        }

        // 2. Extract Collocations (Bigrams & Trigrams)
        if tokens.count >= 2 {
            for i in 0..<(tokens.count - 1) {
                let first = tokens[i]
                let second = tokens[i + 1]
                guard first.count >= 2, second.count >= 2 else { continue }
                let bigram = "\(first) \(second)"

                // Boost collocations that start with an imperative or frequent starter
                if knownDirectiveRoots.contains(first) || i == 0 {
                    collocationFrequencies[bigram, default: 0] += 1
                }
            }
        }

        lastUpdated = Date()
        isDirty = true
        lock.unlock()

        scheduleSave()
    }

    /// Records an idiosyncratic (rare / personal) word or atomic phrase found in the user's text.
    public func recordIdiosyncraticWord(_ word: String) {
        let clean = word.trimmingCharacters(in: .whitespacesAndNewlines).normalizedPlainVocabularyWord()
        guard clean.count >= 2 else { return }
        let lower = clean.lowercased()

        lock.lock()
        idiosyncraticWordFrequencies[lower, default: 0] += 1
        // Store canonical display casing if term has casing or compounds
        if clean.contains(where: { $0.isUppercase }) || clean.contains(" ") || clean.contains("-") || clean.contains(".") {
            canonicalIdiosyncraticWords[lower] = clean
        }
        lastUpdated = Date()
        isDirty = true
        lock.unlock()

        scheduleSave()
    }

    // MARK: - Query API

    /// Returns top habitual directives/starters ordered by user frequency
    public func topDirectives(limit: Int = 8) -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return directiveFrequencies
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .map { $0.key }
    }

    /// Generates a language-aware prompt hint for Whisper context conditioning.
    /// Never injects Russian prompt labels into English speech contexts.
    public func topDirectivesPromptHint(language: String? = nil) -> String? {
        let directives = topDirectives(limit: 6)
        guard !directives.isEmpty else { return nil }

        let isEnglish = language?.lowercased().starts(with: "en") == true
        let isRussian = language?.lowercased().starts(with: "ru") == true

        if isEnglish {
            let latinDirectives = directives.filter { d in
                d.unicodeScalars.allSatisfy { ($0.value >= 0x0041 && $0.value <= 0x005A) || ($0.value >= 0x0061 && $0.value <= 0x007A) }
            }
            guard !latinDirectives.isEmpty else { return nil }
            return "Speech style and frequent directives: " + latinDirectives.joined(separator: ", ") + "."
        } else if isRussian {
            let cyrillicDirectives = directives.filter { d in
                d.unicodeScalars.contains { ($0.value >= 0x0400 && $0.value <= 0x04FF) || ($0.value >= 0x0500 && $0.value <= 0x052F) }
            }
            guard !cyrillicDirectives.isEmpty else { return nil }
            return "Речевой стиль и частые конструкции: " + cyrillicDirectives.joined(separator: ", ") + "."
        } else {
            // Mixed or auto mode: only output directives without Russian-only bias
            return "Common directives: " + directives.joined(separator: ", ") + "."
        }
    }

    /// Removes a specific idiosyncratic word from the profile
    public func removeIdiosyncraticWord(_ word: String) {
        let lower = word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        lock.lock()
        idiosyncraticWordFrequencies.removeValue(forKey: lower)
        canonicalIdiosyncraticWords.removeValue(forKey: lower)
        lastUpdated = Date()
        isDirty = true
        lock.unlock()
        scheduleSave()
    }

    /// Removes a specific directive from the profile
    public func removeDirective(_ directive: String) {
        let lower = directive.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        lock.lock()
        directiveFrequencies.removeValue(forKey: lower)
        lastUpdated = Date()
        isDirty = true
        lock.unlock()
        scheduleSave()
    }

    /// Purges all learned directives, collocations, and idiosyncratic words
    public func clearAll() {
        lock.lock()
        directiveFrequencies.removeAll()
        collocationFrequencies.removeAll()
        idiosyncraticWordFrequencies.removeAll()
        canonicalIdiosyncraticWords.removeAll()
        totalProcessedSegments = 0
        lastUpdated = Date()
        isDirty = true
        lock.unlock()
        saveToDisk()
    }

    /// Returns top learned collocations/bigrams (e.g. "сделай чтобы", "давай сделаем")
    public func topCollocations(limit: Int = 10) -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return collocationFrequencies
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .map { $0.key }
    }

    /// Returns top learned idiosyncratic/rare words (with preserved canonical casing)
    public func topIdiosyncraticWords(limit: Int = 30) -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return idiosyncraticWordFrequencies
            .filter { $0.value >= 2 }
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .map { canonicalIdiosyncraticWords[$0.key] ?? $0.key }
    }

    /// Returns the frequency score for a candidate bigram to aid linguistic validation
    public func collocationScore(first: String, second: String) -> Int {
        let key = "\(first.lowercased()) \(second.lowercased())"
        lock.lock()
        defer { lock.unlock() }
        return collocationFrequencies[key] ?? 0
    }

    /// Returns total count of learned constructions
    public var learnedConstructionsCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return directiveFrequencies.count + collocationFrequencies.filter { $0.value >= 2 }.count
    }

    /// Returns total count of unique idiosyncratic words learned
    public var learnedIdiosyncraticWordsCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return idiosyncraticWordFrequencies.filter { $0.value >= 2 }.count
    }

    // MARK: - Persistence

    private struct ProfilePayload: Codable {
        let version: Int
        let lastUpdated: Date
        let totalProcessedSegments: Int
        let directives: [String: Int]
        let collocations: [String: Int]
        let idiosyncraticWords: [String: Int]
        var canonicalWords: [String: String]? = nil
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000) // 3s debounce
            guard !Task.isCancelled else { return }
            self?.saveToDisk()
        }
    }

    public func saveToDisk() {
        lock.lock()
        guard isDirty else {
            lock.unlock()
            return
        }
        let payload = ProfilePayload(
            version: 1,
            lastUpdated: self.lastUpdated,
            totalProcessedSegments: self.totalProcessedSegments,
            directives: self.directiveFrequencies,
            collocations: self.collocationFrequencies,
            idiosyncraticWords: self.idiosyncraticWordFrequencies,
            canonicalWords: self.canonicalIdiosyncraticWords
        )
        self.isDirty = false
        lock.unlock()

        do {
            let data = try JSONEncoder().encode(payload)
            try data.write(to: fileURL, options: .atomic)
            logger.debug("Saved UserGrammarProfile (\(payload.directives.count) directives, \(payload.collocations.count) collocations)")
        } catch {
            logger.error("Failed to save UserGrammarProfile: \(error.localizedDescription)")
        }
    }

    private func loadFromDisk() {
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let payload = try? JSONDecoder().decode(ProfilePayload.self, from: data) else {
            return
        }

        lock.lock()
        self.directiveFrequencies = payload.directives
        self.collocationFrequencies = payload.collocations
        self.idiosyncraticWordFrequencies = payload.idiosyncraticWords
        self.canonicalIdiosyncraticWords = payload.canonicalWords ?? [:]
        self.totalProcessedSegments = payload.totalProcessedSegments
        self.lastUpdated = payload.lastUpdated
        self.isDirty = false
        lock.unlock()

        logger.info("Loaded UserGrammarProfile: \(self.directiveFrequencies.count) directives, \(self.collocationFrequencies.count) collocations, \(self.idiosyncraticWordFrequencies.count) rare words")
    }
}
