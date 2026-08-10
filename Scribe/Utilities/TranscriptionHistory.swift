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
    
    // MARK: - Stats
    
    var totalWords: Int {
        records.reduce(0) { $0 + $1.text.split(separator: " ").count }
    }
    
    var totalDuration: TimeInterval {
        records.reduce(0) { $0 + $1.duration }
    }
    
    /// Estimated time saved in seconds assuming 40 words per minute typing speed
    var timeSaved: TimeInterval {
        let typingTimeMinutes = Double(totalWords) / 40.0
        let typingTimeSeconds = typingTimeMinutes * 60.0
        return max(0, typingTimeSeconds - totalDuration)
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
        case 1...5: return .cyan
        case 6...10: return .blue.opacity(0.8) // Soft blue for rain shower, etc
        case 11...20: return .blue
        case 21...30: return .indigo
        case 31...40: return .purple
        case 41...49: return .pink
        default: return .red
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
        saveToDisk()
        logger.info("Saved transcription (\(record.text.prefix(50))…), total: \(self.records.count)")
    }

    /// Delete a record by ID.
    func delete(id: UUID) {
        records.removeAll { $0.id == id }
        saveToDisk()
    }

    /// Delete records at given offsets (for SwiftUI onDelete).
    func delete(at offsets: IndexSet) {
        records.remove(atOffsets: offsets)
        saveToDisk()
    }

    /// Clear all history.
    func clearAll() {
        records.removeAll()
        saveToDisk()
    }

    /// Calculate statistics summary for a given time frame.
    func stats(for timeFrame: StatsTimeFrame) -> StatsSummary {
        let calendar = Calendar.current
        let now = Date()

        let filtered = records.filter { record in
            switch timeFrame {
            case .today:
                return calendar.isDateInToday(record.date)
            case .week:
                // Use a rolling 7-day window instead of calendar week to prevent boundary issues
                if let startOfToday = calendar.startOfDay(for: now) as Date?,
                   let weekAgo = calendar.date(byAdding: .day, value: -6, to: startOfToday) {
                    return record.date >= weekAgo
                }
                return false
            case .allTime:
                return true
            }
        }

        let words = filtered.reduce(0) { total, rec in
            total + rec.text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
        }
        let chars = filtered.reduce(0) { total, rec in
            total + rec.text.count
        }
        let totalDuration = filtered.reduce(0.0) { total, rec in
            total + rec.duration
        }

        return StatsSummary(
            wordCount: words,
            charCount: chars,
            duration: totalDuration,
            sessionCount: filtered.count
        )
    }

    // MARK: - Persistence

    private func loadFromDisk() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            logger.info("No history file found, starting fresh")
            return
        }

        do {
            let data = try Data(contentsOf: fileURL)
            records = try JSONDecoder().decode([TranscriptionRecord].self, from: data)
            logger.info("Loaded \(self.records.count) history records")
        } catch {
            logger.error("Failed to load history: \(error.localizedDescription)")
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
