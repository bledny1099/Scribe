import Foundation
import os.log

private let logger = Logger(subsystem: "com.aleksei.scribe", category: "UserFrequencyDictionary")

/// Maintains a dynamically updated dictionary of the user's most frequently spoken words (Top 100+).
/// This enables phonetic and linguistic validators to prioritize the user's personal lexicon over rare dictionary words.
public final class UserFrequencyDictionary: @unchecked Sendable {
    public static let shared = UserFrequencyDictionary()

    private let lock = NSLock()
    private var wordFrequencies: [String: Int] = [:]
    private var cachedTopWords: [String] = []
    private var cachedTopWordsSet: Set<String> = []
    private var isDirty = false
    private var saveTask: Task<Void, Never>?

    private let fileURL: URL

    /// Stop words that are generic grammatical particles and shouldn't dominate vocabulary prioritization
    private let stopWords: Set<String> = [
        "the", "be", "to", "of", "and", "a", "in", "that", "have", "i", "it", "for", "not", "on", "with", "he", "as", "you", "do", "at",
        "this", "but", "his", "by", "from", "they", "we", "say", "her", "she", "or", "an", "will", "my", "one", "all", "would", "there",
        "their", "what", "so", "up", "out", "if", "about", "who", "get", "which", "go", "me", "is", "are", "was", "were", "been",
        "и", "в", "во", "не", "что", "он", "на", "я", "с", "со", "как", "а", "то", "все", "она", "так", "его", "но", "да", "ты", "к",
        "у", "же", "вы", "за", "бы", "по", "только", "ее", "мне", "было", "вот", "от", "меня", "еще", "нет", "о", "из", "ему", "теперь",
        "когда", "даже", "ну", "вдруг", "ли", "если", "уже", "или", "ни", "быть", "был", "него", "до", "вас", "нибудь", "опять", "уж"
    ]

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let scribeDir = appSupport.appendingPathComponent("Scribe", isDirectory: true)
        try? FileManager.default.createDirectory(at: scribeDir, withIntermediateDirectories: true)
        self.fileURL = scribeDir.appendingPathComponent("user_frequency_dictionary.json")

        loadFromDisk()
        seedFromHistoryFileIfNeeded()
    }

    // MARK: - Public API

    /// Records all spoken words from a transcription into the frequency dictionary.
    public func record(text: String) {
        guard !text.isEmpty else { return }

        let words = extractWords(from: text)
        guard !words.isEmpty else { return }

        lock.lock()
        for word in words {
            let lower = word.lowercased()
            if lower.count >= 2 {
                wordFrequencies[lower, default: 0] += 1
            }
        }
        recomputeCacheUnderLock()
        isDirty = true
        lock.unlock()

        scheduleSave()
    }

    /// Returns the Top N most frequently spoken words by this user.
    public func topWords(limit: Int = 100) -> [String] {
        lock.lock()
        defer { lock.unlock() }
        if limit == 100 {
            return cachedTopWords
        }
        let sorted = wordFrequencies
            .filter { !stopWords.contains($0.key) }
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .map { $0.key }
        return Array(sorted)
    }

    /// Returns a Set of Top N most frequently spoken words for O(1) membership checks.
    public func topWordsSet(limit: Int = 100) -> Set<String> {
        lock.lock()
        defer { lock.unlock() }
        if limit == 100 {
            return cachedTopWordsSet
        }
        let top = wordFrequencies
            .filter { !stopWords.contains($0.key) }
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .map { $0.key }
        return Set(top)
    }

    /// Returns top words with their exact frequency counts.
    public func topWordsWithCounts(limit: Int = 100) -> [(word: String, count: Int)] {
        lock.lock()
        defer { lock.unlock() }
        return wordFrequencies
            .filter { !stopWords.contains($0.key) }
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .map { (word: $0.key, count: $0.value) }
    }

    /// Returns the recorded frequency of a specific word.
    public func frequency(of word: String) -> Int {
        lock.lock()
        defer { lock.unlock() }
        return wordFrequencies[word.lowercased()] ?? 0
    }

    /// Checks if a word is in the user's top vocabulary.
    public func isTopUserWord(_ word: String, limit: Int = 100) -> Bool {
        let lower = word.lowercased()
        lock.lock()
        defer { lock.unlock() }
        if limit == 100 {
            return cachedTopWordsSet.contains(lower)
        }
        return cachedTopWords.prefix(limit).contains(lower)
    }

    /// Searches the user's Top 100 words for the closest phonetic/Levenshtein match.
    /// Returns the matched word and its usage frequency if within `maxDistance`.
    public func findBestFuzzyCandidate(
        for word: String,
        maxDistance: Int = 2,
        limit: Int = 100
    ) -> (word: String, count: Int, distance: Int)? {
        let lower = word.lowercased()
        guard lower.count >= 3 else { return nil }

        lock.lock()
        let candidates = Array(cachedTopWords.prefix(limit))
        let freqs = wordFrequencies
        lock.unlock()

        var bestMatch: (word: String, count: Int, distance: Int)? = nil
        var bestScore = Int.max

        for candidate in candidates {
            if abs(candidate.count - lower.count) > 1 { continue }

            let dist = levenshtein(lower, candidate)
            if dist <= maxDistance && dist < lower.count {
                let count = freqs[candidate] ?? 0
                // Score combines lower distance and higher frequency
                let score = dist * 1000 - min(count, 500)
                if score < bestScore {
                    bestScore = score
                    bestMatch = (word: candidate, count: count, distance: dist)
                }
            }
        }

        return bestMatch
    }

    /// Seeds word frequencies from a list of transcription records if the dictionary is currently empty.
    public func seedFromHistory(records: [(text: String, date: Date)]) {
        guard !records.isEmpty else { return }

        lock.lock()
        guard wordFrequencies.isEmpty else {
            lock.unlock()
            return
        }

        for rec in records {
            let words = extractWords(from: rec.text)
            for w in words {
                let lower = w.lowercased()
                if lower.count >= 2 {
                    wordFrequencies[lower, default: 0] += 1
                }
            }
        }
        recomputeCacheUnderLock()
        isDirty = true
        lock.unlock()

        saveToDiskImmediate()
        logger.info("Seeded UserFrequencyDictionary with \(self.wordFrequencies.count) unique words from history")
    }

    // MARK: - Internal Helpers

    private func extractWords(from text: String) -> [String] {
        let pattern = #"[^\p{L}\p{M}0-9'-]+"#
        return text.components(separatedBy: CharacterSet(charactersIn: "!@#$%^&*()_+=[]{}|;:,.<>/?`~\"\\ \t\n\r"))
            .map { $0.trimmingCharacters(in: CharacterSet.punctuationCharacters.union(.whitespacesAndNewlines)) }
            .filter { $0.count >= 2 && !$0.allSatisfy({ $0.isNumber }) }
    }

    private func recomputeCacheUnderLock() {
        let sorted = wordFrequencies
            .filter { !stopWords.contains($0.key) }
            .sorted { $0.value > $1.value }
            .prefix(100)
            .map { $0.key }

        cachedTopWords = Array(sorted)
        cachedTopWordsSet = Set(sorted)
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task.detached(priority: .utility) { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            self?.saveToDiskImmediate()
        }
    }

    private func saveToDiskImmediate() {
        lock.lock()
        guard isDirty else {
            lock.unlock()
            return
        }
        let copy = wordFrequencies
        isDirty = false
        lock.unlock()

        do {
            let data = try JSONEncoder().encode(copy)
            try data.write(to: fileURL, options: .atomic)
            logger.debug("Saved \(copy.count) words to UserFrequencyDictionary")
        } catch {
            logger.error("Failed to save UserFrequencyDictionary: \(error.localizedDescription)")
        }
    }

    private func loadFromDisk() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }

        do {
            let data = try Data(contentsOf: fileURL)
            let decoded = try JSONDecoder().decode([String: Int].self, from: data)
            lock.lock()
            self.wordFrequencies = decoded
            recomputeCacheUnderLock()
            lock.unlock()
            logger.info("Loaded \(decoded.count) words from UserFrequencyDictionary (Top 100 cached: \(self.cachedTopWords.count))")
        } catch {
            logger.error("Failed to load UserFrequencyDictionary: \(error.localizedDescription)")
        }
    }

    private func seedFromHistoryFileIfNeeded() {
        lock.lock()
        let isEmpty = wordFrequencies.isEmpty
        lock.unlock()

        guard isEmpty else { return }

        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let historyURL = appSupport.appendingPathComponent("Scribe/history.json")
        guard FileManager.default.fileExists(atPath: historyURL.path) else { return }

        do {
            let data = try Data(contentsOf: historyURL)
            struct MinimalRecord: Codable { let text: String }
            let records = try JSONDecoder().decode([MinimalRecord].self, from: data)
            guard !records.isEmpty else { return }

            lock.lock()
            for rec in records {
                let words = extractWords(from: rec.text)
                for w in words {
                    let lower = w.lowercased()
                    if lower.count >= 2 {
                        wordFrequencies[lower, default: 0] += 1
                    }
                }
            }
            recomputeCacheUnderLock()
            isDirty = true
            lock.unlock()

            saveToDiskImmediate()
            logger.info("Successfully seeded UserFrequencyDictionary with \(self.wordFrequencies.count) words from history.json")
        } catch {
            logger.error("Failed to seed UserFrequencyDictionary from history: \(error.localizedDescription)")
        }
    }

    private func levenshtein(_ s1: String, _ s2: String) -> Int {
        let a = Array(s1)
        let b = Array(s2)
        var dist = [[Int]](repeating: [Int](repeating: 0, count: b.count + 1), count: a.count + 1)

        for i in 0...a.count { dist[i][0] = i }
        for j in 0...b.count { dist[0][j] = j }

        for i in 1...a.count {
            for j in 1...b.count {
                if a[i - 1] == b[j - 1] {
                    dist[i][j] = dist[i - 1][j - 1]
                } else {
                    dist[i][j] = min(
                        dist[i - 1][j] + 1,
                        dist[i][j - 1] + 1,
                        dist[i - 1][j - 1] + 1
                    )
                }
            }
        }
        return dist[a.count][b.count]
    }
}
