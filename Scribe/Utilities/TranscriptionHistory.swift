import Foundation
import os.log

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

// MARK: - Storage Manager

/// Persists transcription history to a JSON file in Application Support.
@MainActor
final class TranscriptionHistory: ObservableObject {
    static let shared = TranscriptionHistory()

    @Published var records: [TranscriptionRecord] = []

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
