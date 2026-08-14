import Foundation
import os.log
import SwiftUI

private let logger = Logger(subsystem: "com.aleksei.scribe", category: "TranscriptionHistory")

// MARK: - Model

/// A single transcription record.
struct TranscriptionRecord: Codable, Identifiable {
    let id: UUID
    let text: String
    let date: Date
    let duration: TimeInterval
    let language: String
    let model: String

    init(text: String, duration: TimeInterval, language: String, model: String) {
        self.id = UUID()
        self.text = text
        self.date = Date()
        self.duration = duration
        self.language = language
        self.model = model
    }

    /// Formatted duration string (e.g. "0:05").
    var formattedDuration: String {
        let mins = Int(duration) / 60
        let secs = Int(duration) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - Statistics Model

enum StatsTimeFrame: String, CaseIterable, Identifiable {
    case today = "Today"
    case week = "This Week"
    case allTime = "All Time"

    var id: String { rawValue }
}

struct StatsSummary {
    let wordCount: Int
    let charCount: Int
    let duration: TimeInterval
    let sessionCount: Int
}

// MARK: - Storage Manager

/// Persists transcription history to a JSON file in Application Support.
@MainActor
final class TranscriptionHistory: ObservableObject {
    static let shared = TranscriptionHistory()

    @Published var records: [TranscriptionRecord] = []
    
    // MARK: - Precomputed Cached Stats
    @Published private(set) var totalWords: Int = 0
    @Published private(set) var totalDuration: TimeInterval = 0
    @Published private(set) var dayStreak: Int = 0
    @Published private(set) var cachedTodayStats = StatsSummary(wordCount: 0, charCount: 0, duration: 0, sessionCount: 0)
    @Published private(set) var cachedWeekStats = StatsSummary(wordCount: 0, charCount: 0, duration: 0, sessionCount: 0)
    @Published private(set) var cachedAllTimeStats = StatsSummary(wordCount: 0, charCount: 0, duration: 0, sessionCount: 0)
    @Published private(set) var topSpokenWords: [(word: String, count: Int)] = []

    /// Estimated time saved in seconds assuming 40 words per minute typing speed
    var timeSaved: TimeInterval {
        let typingTimeMinutes = Double(totalWords) / 40.0
        let typingTimeSeconds = typingTimeMinutes * 60.0
        return max(0, typingTimeSeconds - totalDuration)
    }

    /// Calculate statistics summary for a given time frame (instant cached lookup).
    func stats(for timeFrame: StatsTimeFrame) -> StatsSummary {
        switch timeFrame {
        case .today:   return cachedTodayStats
        case .week:    return cachedWeekStats
        case .allTime: return cachedAllTimeStats
        }
    }

    /// Recomputes all stats and caches them in memory ONCE when records change.
    private func recomputeAllStatsCache() {
        let calendar = Calendar.current
        let now = Date()

        // 1. Total Words & Total Duration
        var totalW = 0
        var totalD: TimeInterval = 0
        for rec in records {
            let wordsCount = rec.text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
            totalW += wordsCount
            totalD += rec.duration
        }
        self.totalWords = totalW
        self.totalDuration = totalD

        // 2. Day Streak
        if records.isEmpty {
            self.dayStreak = 0
        } else {
            let today = calendar.startOfDay(for: now)
            let uniqueDates = Set(records.map { calendar.startOfDay(for: $0.date) })
            var sortedDates = Array(uniqueDates).sorted(by: >)
            var streak = 0
            var dateToCheck = today
            if sortedDates.first == today {
                streak = 1
                sortedDates.removeFirst()
                dateToCheck = calendar.date(byAdding: .day, value: -1, to: today)!
            } else if sortedDates.first == calendar.date(byAdding: .day, value: -1, to: today)! {
                dateToCheck = sortedDates.first!
            }
            if streak > 0 || sortedDates.first == dateToCheck {
                for date in sortedDates {
                    if date == dateToCheck {
                        streak += 1
                        dateToCheck = calendar.date(byAdding: .day, value: -1, to: dateToCheck)!
                    } else {
                        break
                    }
                }
            }
            self.dayStreak = streak
        }

        // 3. TimeFrame Summaries
        let startOfToday = calendar.startOfDay(for: now)
        let weekAgo = calendar.date(byAdding: .day, value: -6, to: startOfToday) ?? now

        var todayW = 0, todayC = 0, todayS = 0; var todayDur: TimeInterval = 0
        var weekW = 0, weekC = 0, weekS = 0; var weekDur: TimeInterval = 0
        var allC = 0

        for rec in records {
            let w = rec.text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
            let c = rec.text.count
            let dur = rec.duration

            allC += c

            if calendar.isDateInToday(rec.date) {
                todayW += w
                todayC += c
                todayDur += dur
                todayS += 1
            }

            if rec.date >= weekAgo {
                weekW += w
                weekC += c
                weekDur += dur
                weekS += 1
            }
        }

        self.cachedTodayStats = StatsSummary(wordCount: todayW, charCount: todayC, duration: todayDur, sessionCount: todayS)
        self.cachedWeekStats = StatsSummary(wordCount: weekW, charCount: weekC, duration: weekDur, sessionCount: weekS)
        self.cachedAllTimeStats = StatsSummary(wordCount: totalW, charCount: allC, duration: totalD, sessionCount: records.count)

        // 4. Top Spoken Words
        let stopWords: Set<String> = [
            "the", "be", "to", "of", "and", "a", "in", "that", "have", "i", "it", "for", "not", "on", "with", "he", "as", "you", "do", "at",
            "this", "but", "his", "by", "from", "they", "we", "say", "her", "she", "or", "an", "will", "my", "one", "all", "would", "there",
            "their", "what", "so", "up", "out", "if", "about", "who", "get", "which", "go", "me", "is", "are", "was", "were", "been",
            "и", "в", "во", "не", "что", "он", "на", "я", "с", "со", "как", "а", "то", "все", "она", "так", "его", "но", "да", "ты", "к",
            "у", "же", "вы", "за", "бы", "по", "только", "ее", "мне", "было", "вот", "от", "меня", "еще", "нет", "о", "из", "ему", "теперь",
            "когда", "даже", "ну", "вдруг", "ли", "если", "уже", "или", "ни", "быть", "был", "него", "до", "вас", "нибудь", "опять", "уж"
        ]

        var wordCounts: [String: Int] = [:]
        for record in records {
            let words = record.text
                .lowercased()
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { $0.count > 2 && !stopWords.contains($0) }

            for word in words {
                wordCounts[word, default: 0] += 1
            }
        }

        self.topSpokenWords = wordCounts.sorted { $0.value > $1.value }.prefix(12).map { (word: $0.key, count: $0.value) }
    }

    private let levelNames = [
        "Drip", "Trickle", "Puddle", "Drinking Fountain", "Leaky Faucet",
        "Garden Hose", "Sprinkler", "Kitchen Tap", "Rain Shower", "Spring",
        "Brook", "Creek", "Rivulet", "Stream", "Runoff",
        "Storm Drain", "Fountain", "Mill Race", "Cascade", "Rapids",
        "Tributary", "River", "Delta", "Estuary", "Reservoir",
        "Lake", "Bay", "Sound", "Gulf", "Inland Sea",
        "Sea", "Open Ocean", "Deep Current", "Geyser", "Waterfall",
        "Niagara Falls", "Broken Dam", "Storm Surge", "Whirlpool", "Maelstrom",
        "Rogue Wave", "Monsoon", "Flash Flood", "Deluge", "Hurricane",
        "Typhoon", "Tidal Wave", "Tsunami", "Category 5", "Force of Nature"
    ]
    
    /// Words required for a specific level using an arithmetic progression
    func requiredWords(for level: Int) -> Int {
        if level <= 1 { return 0 }
        let n = level - 1
        return (n * (200 + (n - 1) * 50)) / 2
    }
    
    var currentLevel: Int {
        for level in (1...50).reversed() {
            if totalWords >= requiredWords(for: level) {
                return level
            }
        }
        return 1
    }
    
    var currentLevelName: String {
        let index = max(0, min(currentLevel - 1, levelNames.count - 1))
        return levelNames[index]
    }
    
    var currentLevelColor: Color {
        switch currentLevel {
        case 1...5: return Color(red: 0.0, green: 0.85, blue: 0.95) // Neon Cyan
        case 6...10: return Color(red: 0.1, green: 0.70, blue: 1.0) // Vibrant Sky Blue
        case 11...15: return Color(red: 0.25, green: 0.5, blue: 1.0) // Deep Electric Blue
        case 16...20: return Color(red: 0.55, green: 0.35, blue: 1.0) // Electric Purple
        case 21...30: return Color(red: 0.85, green: 0.3, blue: 1.0) // Neon Magenta
        case 31...40: return Color(red: 1.0, green: 0.3, blue: 0.65) // Hot Pink
        case 41...49: return Color(red: 1.0, green: 0.55, blue: 0.1) // Amber Gold
        default: return Color(red: 1.0, green: 0.25, blue: 0.25) // Crimson Flame
        }
    }
    
    var wordsToNextLevel: Int {
        if currentLevel >= 50 { return 0 }
        return requiredWords(for: currentLevel + 1) - totalWords
    }
    
    var currentLevelProgress: Double {
        if currentLevel >= 50 { return 1.0 }
        let currentLevelWords = requiredWords(for: currentLevel)
        let nextLevelWords = requiredWords(for: currentLevel + 1)
        let wordsInThisLevel = nextLevelWords - currentLevelWords
        let wordsEarned = totalWords - currentLevelWords
        return Double(wordsEarned) / Double(wordsInThisLevel)
    }

    private let fileURL: URL

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let scribeDir = appSupport.appendingPathComponent("Scribe", isDirectory: true)

        // Ensure directory exists
        try? FileManager.default.createDirectory(at: scribeDir, withIntermediateDirectories: true)

        fileURL = scribeDir.appendingPathComponent("history.json")
        loadFromDisk()
    }

    // MARK: - Public API

    /// Add a new transcription record and persist.
    func add(_ record: TranscriptionRecord) {
        records.insert(record, at: 0) // newest first
        recomputeAllStatsCache()
        saveToDisk()
        logger.info("Saved transcription (\(record.text.prefix(50))…), total: \(self.records.count)")
    }

    /// Delete a record by ID.
    func delete(id: UUID) {
        records.removeAll { $0.id == id }
        recomputeAllStatsCache()
        saveToDisk()
    }

    /// Delete records at given offsets (for SwiftUI onDelete).
    func delete(at offsets: IndexSet) {
        records.remove(atOffsets: offsets)
        recomputeAllStatsCache()
        saveToDisk()
    }

    /// Clear all history.
    func clearAll() {
        records.removeAll()
        recomputeAllStatsCache()
        saveToDisk()
    }

    // MARK: - Persistence

    private func loadFromDisk() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            logger.info("No history file found, starting fresh")
            recomputeAllStatsCache()
            return
        }

        do {
            let data = try Data(contentsOf: fileURL)
            records = try JSONDecoder().decode([TranscriptionRecord].self, from: data)
            recomputeAllStatsCache()
            logger.info("Loaded \(self.records.count) history records")
        } catch {
            logger.error("Failed to load history: \(error.localizedDescription)")
            recomputeAllStatsCache()
        }
    }

    private func saveToDisk() {
        do {
            let data = try JSONEncoder().encode(records)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            logger.error("Failed to save history: \(error.localizedDescription)")
        }
    }
}
