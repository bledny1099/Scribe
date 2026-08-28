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
    
    /// Words required for a specific level using an engaging quadratic progression scaling up to ~283,000 words at level 50
    func requiredWords(for level: Int) -> Int {
        if level <= 1 { return 0 }
        let n = level - 1
        return n * 150 + Int(Double(n * n) * 115)
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
    
    private static let levelThematicColors: [Color] = [
        Color(red: 0.65, green: 0.88, blue: 0.98), // 1. Drip (Капля - кристальный ледяной)
        Color(red: 0.52, green: 0.82, blue: 0.96), // 2. Trickle (Струйка - мягкий аква)
        Color(red: 0.40, green: 0.78, blue: 0.94), // 3. Puddle (Лужица - рябь воды)
        Color(red: 0.32, green: 0.84, blue: 0.88), // 4. Drinking Fountain (Питьевой фонтанчик - свежий бирюзовый)
        Color(red: 0.22, green: 0.80, blue: 0.82), // 5. Leaky Faucet (Капающий кран - прохладный тил)
        Color(red: 0.38, green: 0.86, blue: 0.52), // 6. Garden Hose (Садовый шланг - весенняя зелень)
        Color(red: 0.46, green: 0.88, blue: 0.58), // 7. Sprinkler (Дождеватель - нежный травяной)
        Color(red: 0.26, green: 0.84, blue: 0.92), // 8. Kitchen Tap (Кухонный кран - чистая лазурь)
        Color(red: 0.28, green: 0.76, blue: 0.96), // 9. Rain Shower (Грибной дождь - дождевой синий)
        Color(red: 0.18, green: 0.86, blue: 0.84), // 10. Spring (Родник - горный родник)
        Color(red: 0.22, green: 0.84, blue: 0.48), // 11. Brook (Лесной ручей - изумрудный лес)
        Color(red: 0.18, green: 0.80, blue: 0.42), // 12. Creek (Ручей - лесной поток)
        Color(red: 0.24, green: 0.82, blue: 0.64), // 13. Rivulet (Речушка - мятная заводь)
        Color(red: 0.12, green: 0.80, blue: 0.92), // 14. Stream (Поток - быстрый циан)
        Color(red: 0.22, green: 0.84, blue: 0.78), // 15. Runoff (Талая вода - ледниковая бирюза)
        Color(red: 0.38, green: 0.58, blue: 0.84), // 16. Storm Drain (Ливнесток - сланцевый шторм)
        Color(red: 0.22, green: 0.72, blue: 1.00), // 17. Fountain (Фонтан - искрящийся лазурный)
        Color(red: 0.16, green: 0.74, blue: 0.62), // 18. Mill Race (Жерновой поток - замшелый поток)
        Color(red: 0.28, green: 0.76, blue: 1.00), // 19. Cascade (Каскад - водопадный лед)
        Color(red: 0.10, green: 0.86, blue: 0.96), // 20. Rapids (Пороги - пенящийся циан)
        Color(red: 0.16, green: 0.66, blue: 0.96), // 21. Tributary (Приток - речной приток)
        Color(red: 0.20, green: 0.56, blue: 0.98), // 22. River (Река - глубокая река)
        Color(red: 0.32, green: 0.78, blue: 0.44), // 23. Delta (Дельта - камышовая дельта)
        Color(red: 0.24, green: 0.74, blue: 0.68), // 24. Estuary (Эстуарий - приливной эстуарий)
        Color(red: 0.16, green: 0.50, blue: 0.96), // 25. Reservoir (Водохранилище - кобальтовая глубина)
        Color(red: 0.24, green: 0.60, blue: 0.96), // 26. Lake (Озеро - альпийское озеро)
        Color(red: 0.18, green: 0.46, blue: 0.94), // 27. Bay (Залив - сапфировая бухта)
        Color(red: 0.28, green: 0.42, blue: 0.96), // 28. Sound (Пролив - морской индиго)
        Color(red: 0.12, green: 0.74, blue: 0.86), // 29. Gulf (Морской залив - тропический залив)
        Color(red: 0.08, green: 0.64, blue: 0.82), // 30. Inland Sea (Внутреннее море - глубинное море)
        Color(red: 0.10, green: 0.52, blue: 0.96), // 31. Sea (Море - средиземноморский синий)
        Color(red: 0.14, green: 0.36, blue: 0.96), // 32. Open Ocean (Открытый океан - ультрамариновая бездна)
        Color(red: 0.34, green: 0.32, blue: 0.96), // 33. Deep Current (Глубинное течение - ночное течение)
        Color(red: 0.58, green: 0.32, blue: 0.96), // 34. Geyser (Гейзер - термальный фиолетовый)
        Color(red: 0.10, green: 0.84, blue: 1.00), // 35. Waterfall (Водопад - мощный водопад)
        Color(red: 0.05, green: 0.70, blue: 1.00), // 36. Niagara Falls (Ниагарский водопад - ниагарский электрик)
        Color(red: 0.66, green: 0.28, blue: 0.96), // 37. Broken Dam (Прорыв плотины - грозовой фиолетовый)
        Color(red: 0.76, green: 0.26, blue: 0.92), // 38. Storm Surge (Штормовой нагон - напор шторма)
        Color(red: 0.86, green: 0.22, blue: 0.86), // 39. Whirlpool (Водоворот - неоновая маджента)
        Color(red: 0.96, green: 0.16, blue: 0.76), // 40. Maelstrom (Мальстрём - электрическая фуксия)
        Color(red: 0.98, green: 0.30, blue: 0.44), // 41. Rogue Wave (Волна-убийца - коралловый прибой)
        Color(red: 0.82, green: 0.22, blue: 0.82), // 42. Monsoon (Муссон - тропический муссон)
        Color(red: 1.00, green: 0.46, blue: 0.16), // 43. Flash Flood (Внезапный паводок - янтарный поток)
        Color(red: 1.00, green: 0.36, blue: 0.12), // 44. Deluge (Великий потоп - огненный потоп)
        Color(red: 1.00, green: 0.26, blue: 0.36), // 45. Hurricane (Ураган - алый ураган)
        Color(red: 1.00, green: 0.16, blue: 0.32), // 46. Typhoon (Тайфун - рубиновый тайфун)
        Color(red: 1.00, green: 0.76, blue: 0.12), // 47. Tidal Wave (Приливная волна - сияющее золото)
        Color(red: 1.00, green: 0.52, blue: 0.08), // 48. Tsunami (Цунами - солнечный взрыв)
        Color(red: 0.96, green: 0.22, blue: 0.48), // 49. Category 5 (5-я категория - супернова)
        Color(red: 1.00, green: 0.20, blue: 0.20)  // 50. Force of Nature (Сила природы - первородный огонь)
    ]

    static func levelColor(for level: Int) -> Color {
        let index = max(0, min(level - 1, levelThematicColors.count - 1))
        return levelThematicColors[index]
    }
    
    static func levelName(for level: Int) -> String {
        let names = shared.levelNames
        let index = max(0, min(level - 1, names.count - 1))
        return names[index]
    }

    var currentLevelColor: Color {
        Self.levelColor(for: currentLevel)
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
        UserFrequencyDictionary.shared.record(text: record.text)
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

// MARK: - Donation Verification Service

/// 5-Level Supporter Tiers based on contribution amount
enum SupporterTier: Int, CaseIterable, Codable, Sendable {
    case none = 0
    case tier1 = 1 // до $5: Aether Initiate
    case tier2 = 2 // $5 - $10: Voice Vanguard
    case tier3 = 3 // $10 - $30: Astral Chronicler
    case tier4 = 4 // $30 - $50: Celestial Archon
    case tier5 = 5 // > $50: Immortal Sovereign

    static func tier(for amountInUSD: Double) -> SupporterTier {
        if amountInUSD <= 0 { return .none }
        if amountInUSD <= 5.0 { return .tier1 }
        if amountInUSD <= 10.0 { return .tier2 }
        if amountInUSD <= 30.0 { return .tier3 }
        if amountInUSD <= 50.0 { return .tier4 }
        return .tier5
    }

    var title: String {
        switch self {
        case .none: return ""
        case .tier1: return "Aether Initiate"
        case .tier2: return "Voice Vanguard"
        case .tier3: return "Astral Chronicler"
        case .tier4: return "Celestial Archon"
        case .tier5: return "Immortal Sovereign"
        }
    }

    var badgeText: String {
        switch self {
        case .none: return ""
        case .tier1: return "INITIATE SUPPORTER"
        case .tier2: return "VANGUARD SUPPORTER"
        case .tier3: return "CHRONICLER SUPPORTER"
        case .tier4: return "ARCHON SUPPORTER"
        case .tier5: return "SOVEREIGN SUPPORTER"
        }
    }

    var icon: String {
        switch self {
        case .none: return "star"
        case .tier1: return "sparkles"
        case .tier2: return "shield.fill"
        case .tier3: return "crown.fill"
        case .tier4: return "sun.max.fill"
        case .tier5: return "diamond.fill"
        }
    }

    var gradientColors: [Color] {
        switch self {
        case .none: return [.secondary]
        case .tier1: return [Color(red: 0.88, green: 0.60, blue: 0.38), Color(red: 0.68, green: 0.42, blue: 0.25)] // Warm Amber Bronze
        case .tier2: return [Color(white: 0.94), Color(red: 0.65, green: 0.78, blue: 0.88)] // Moonlight Silver
        case .tier3: return [Color(red: 1.0, green: 0.84, blue: 0.0), Color(red: 1.0, green: 0.55, blue: 0.0)] // Radiant Gold
        case .tier4: return [Color(red: 0.30, green: 0.90, blue: 1.0), Color(red: 0.15, green: 0.60, blue: 0.95)] // Celestial Cyan
        case .tier5: return [Color(red: 0.85, green: 0.45, blue: 1.0), Color(red: 0.45, green: 0.75, blue: 1.0), Color(red: 1.0, green: 0.85, blue: 0.3)] // Cosmic Sovereign
        }
    }
}

/// Result of a verified donation
struct DonationVerificationResult: Sendable {
    let network: String
    let amount: Double
    let currency: String
    let txHash: String
    let senderAddress: String
    let date: Date?

    var tier: SupporterTier {
        SupporterTier.tier(for: amount)
    }
}

/// Service that securely checks incoming donations across multiple public blockchain networks
/// without embedding any private API keys or secret credentials.
final class DonationVerificationService: @unchecked Sendable {
    static let shared = DonationVerificationService()

    // Scribe official deposit addresses
    static let trc20DepositAddress = "TDxy3x7N33wCgyTCKzsNHnfPu5kAyqk4EX"
    static let tonDepositAddress   = "UQDGb_rPU7i3gJ5mzrofTHxM13hEKAeoBRtZdCRRmb8UV6fE"
    static let btcDepositAddress   = "16L68nCPuXGUfecU6oxKGgmFPyvz2om5iT"
    static let ethDepositAddress   = "0x89bb769cc0636720f0544634bd6a3de33b73150f"

    private init() {}

    /// Checks if a given sender address or transaction hash corresponds to an incoming donation.
    func verifyDonation(input: String) async throws -> DonationVerificationResult? {
        let query = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return nil }

        // Run verification checks across networks
        // 1. Tron (USDT TRC20)
        if query.hasPrefix("T") || query.count == 64 {
            if let result = try? await checkTronTRC20(query: query) {
                return result
            }
        }

        // 2. TON (USDT TON / TON)
        if query.hasPrefix("UQ") || query.hasPrefix("EQ") || query.hasPrefix("0:") || query.count == 64 {
            if let result = try? await checkTon(query: query) {
                return result
            }
        }

        // 3. Ethereum (ERC20 / ETH)
        if query.hasPrefix("0x") || query.count == 64 {
            if let result = try? await checkEthereum(query: query) {
                return result
            }
        }

        // 4. Bitcoin (BTC)
        if query.hasPrefix("1") || query.hasPrefix("3") || query.hasPrefix("bc1") || query.count == 64 {
            if let result = try? await checkBitcoin(query: query) {
                return result
            }
        }

        // If not matched by prefix (e.g. bare 64-char hash), try all sequentially
        if let result = try? await checkTronTRC20(query: query) { return result }
        if let result = try? await checkTon(query: query) { return result }
        if let result = try? await checkEthereum(query: query) { return result }
        if let result = try? await checkBitcoin(query: query) { return result }

        return nil
    }

    // MARK: - 1. Tron TRC-20 USDT

    private func checkTronTRC20(query: String) async throws -> DonationVerificationResult? {
        guard let url = URL(string: "https://apilist.tronscanapi.com/api/transfer/trc20?address=\(Self.trc20DepositAddress)&trc20Id=TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t&limit=50") else {
            return nil
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = json["data"] as? [[String: Any]] else {
            return nil
        }

        for item in items {
            let fromAddr = item["from"] as? String ?? (item["from_address"] as? String ?? "")
            let toAddr   = item["to"] as? String ?? (item["to_address"] as? String ?? "")
            let hash     = item["hash"] as? String ?? (item["transaction_id"] as? String ?? "")
            let rawAmount = item["amount"] as? String ?? "0"
            let contractRet = item["contract_ret"] as? String ?? "SUCCESS"

            guard toAddr.caseInsensitiveCompare(Self.trc20DepositAddress) == .orderedSame,
                  contractRet.caseInsensitiveCompare("SUCCESS") == .orderedSame else {
                continue
            }

            let matchesSender = fromAddr.caseInsensitiveCompare(query) == .orderedSame
            let matchesHash   = hash.caseInsensitiveCompare(query) == .orderedSame

            // Anti-spoofing: if searching only by public sender address (and not by exact private TxID),
            // ensure the transfer occurred within the last 48 hours to prevent claiming ancient public ledger transfers.
            let timestamp = (item["block_timestamp"] as? Double).map { Date(timeIntervalSince1970: $0 / 1000.0) }
            if matchesSender && !matchesHash {
                if let date = timestamp, Date().timeIntervalSince(date) > 48 * 3600 {
                    continue
                }
            }

            if matchesSender || matchesHash {
                let amount = (Double(rawAmount) ?? 0) / 1_000_000.0
                return DonationVerificationResult(
                    network: "USDT (TRC20)",
                    amount: max(amount, 1.0),
                    currency: "USDT",
                    txHash: hash,
                    senderAddress: fromAddr,
                    date: timestamp
                )
            }
        }

        return nil
    }

    // MARK: - 2. TON (USDT, TON Jettons, & Native TON with Memo)

    private func checkTon(query: String) async throws -> DonationVerificationResult? {
        let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

        // 1. Check TON Events API (includes TonTransfer & JettonTransfer with decoded comments)
        if let eventsResult = try? await checkTonEvents(query: cleanQuery) {
            return eventsResult
        }

        // 2. Check Jettons History
        guard let url = URL(string: "https://tonapi.io/v2/accounts/\(Self.tonDepositAddress)/jettons/history?limit=30") else {
            return nil
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let operations = json["operations"] as? [[String: Any]] else {
            return nil
        }

        for op in operations {
            let txHash = op["transaction_hash"] as? String ?? ""
            let source = op["source"] as? [String: Any]
            let fromAddr = source?["address"] as? String ?? ""
            let rawAmount = op["amount"] as? String ?? "0"
            let decimals = (op["jetton"] as? [String: Any])?["decimals"] as? Int ?? 6
            let comment = (op["comment"] as? String) ?? (op["payload"] as? String ?? "")

            let matchesSender = !fromAddr.isEmpty && (fromAddr.caseInsensitiveCompare(cleanQuery) == .orderedSame || cleanQuery.contains(fromAddr) || fromAddr.contains(cleanQuery))
            let matchesHash   = !txHash.isEmpty && txHash.caseInsensitiveCompare(cleanQuery) == .orderedSame
            let matchesComment = !comment.isEmpty && comment.localizedCaseInsensitiveContains(cleanQuery)

            let utime = op["utime"] as? Double
            let txDate = utime.map { Date(timeIntervalSince1970: $0) }

            // Anti-spoofing for public sender address without TxID or Memo
            if matchesSender && !matchesHash && !matchesComment {
                if let date = txDate, Date().timeIntervalSince(date) > 48 * 3600 {
                    continue
                }
            }

            if matchesSender || matchesHash || matchesComment {
                let divisor = pow(10.0, Double(decimals))
                let amount = (Double(rawAmount) ?? 0) / divisor
                return DonationVerificationResult(
                    network: "USDT (TON)",
                    amount: max(amount, 1.0),
                    currency: "USDT",
                    txHash: txHash.isEmpty ? "ton_\(Int(utime ?? 0))" : txHash,
                    senderAddress: fromAddr,
                    date: txDate
                )
            }
        }

        return nil
    }

    private func checkTonEvents(query: String) async throws -> DonationVerificationResult? {
        guard let url = URL(string: "https://tonapi.io/v2/accounts/\(Self.tonDepositAddress)/events?limit=30") else {
            return nil
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let events = json["events"] as? [[String: Any]] else {
            return nil
        }

        for event in events {
            let eventId = event["event_id"] as? String ?? ""
            let timestamp = (event["timestamp"] as? Double).map { Date(timeIntervalSince1970: $0) }
            let actions = event["actions"] as? [[String: Any]] ?? []

            for action in actions {
                let status = action["status"] as? String ?? "ok"
                guard status == "ok" else { continue }

                // Check Jetton Transfer
                if let jettonTransfer = action["JettonTransfer"] as? [String: Any] {
                    let recipient = (jettonTransfer["recipient"] as? [String: Any])?["address"] as? String ?? ""
                    let sender = (jettonTransfer["sender"] as? [String: Any])?["address"] as? String ?? ""
                    let comment = jettonTransfer["comment"] as? String ?? ""
                    let rawAmount = jettonTransfer["amount"] as? String ?? "0"
                    let decimals = (jettonTransfer["jetton"] as? [String: Any])?["decimals"] as? Int ?? 6

                    guard recipient.caseInsensitiveCompare(Self.tonDepositAddress) == .orderedSame ||
                          recipient.contains(Self.tonDepositAddress) || Self.tonDepositAddress.contains(recipient) else {
                        continue
                    }

                    let matchesHash = !eventId.isEmpty && eventId.caseInsensitiveCompare(query) == .orderedSame
                    let matchesSender = !sender.isEmpty && sender.caseInsensitiveCompare(query) == .orderedSame
                    let matchesComment = !comment.isEmpty && comment.localizedCaseInsensitiveContains(query)

                    if matchesHash || matchesSender || matchesComment {
                        let divisor = pow(10.0, Double(decimals))
                        let amount = (Double(rawAmount) ?? 0) / divisor
                        return DonationVerificationResult(
                            network: "USDT (TON)",
                            amount: max(amount, 1.0),
                            currency: "USDT",
                            txHash: eventId,
                            senderAddress: sender,
                            date: timestamp
                        )
                    }
                }

                // Check Native TON Transfer
                if let tonTransfer = action["TonTransfer"] as? [String: Any] {
                    let recipient = (tonTransfer["recipient"] as? [String: Any])?["address"] as? String ?? ""
                    let sender = (tonTransfer["sender"] as? [String: Any])?["address"] as? String ?? ""
                    let comment = tonTransfer["comment"] as? String ?? ""
                    let rawAmount = tonTransfer["amount"] as? Double ?? Double(tonTransfer["amount"] as? String ?? "0") ?? 0

                    guard recipient.caseInsensitiveCompare(Self.tonDepositAddress) == .orderedSame ||
                          recipient.contains(Self.tonDepositAddress) || Self.tonDepositAddress.contains(recipient) else {
                        continue
                    }

                    let matchesHash = !eventId.isEmpty && eventId.caseInsensitiveCompare(query) == .orderedSame
                    let matchesSender = !sender.isEmpty && sender.caseInsensitiveCompare(query) == .orderedSame
                    let matchesComment = !comment.isEmpty && comment.localizedCaseInsensitiveContains(query)

                    if matchesHash || matchesSender || matchesComment {
                        let tonAmount = rawAmount / 1_000_000_000.0
                        let approxUsd = tonAmount * 3.0 // Approximate TON to USD
                        return DonationVerificationResult(
                            network: "TON (Native)",
                            amount: max(approxUsd, 1.0),
                            currency: "TON",
                            txHash: eventId,
                            senderAddress: sender,
                            date: timestamp
                        )
                    }
                }
            }
        }

        return nil
    }

    // MARK: - 3. Ethereum ERC-20

    private func checkEthereum(query: String) async throws -> DonationVerificationResult? {
        guard let url = URL(string: "https://eth.blockscout.com/api/v2/addresses/\(Self.ethDepositAddress)/token-transfers") else {
            return nil
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 8

        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = json["items"] as? [[String: Any]] else {
            return nil
        }

        for item in items {
            let txHash = item["tx_hash"] as? String ?? (item["transaction_hash"] as? String ?? "")
            let fromObj = item["from"] as? [String: Any]
            let fromAddr = fromObj?["hash"] as? String ?? ""
            let totalObj = item["total"] as? [String: Any]
            let rawValue = totalObj?["value"] as? String ?? "0"
            let decimalsStr = totalObj?["decimals"] as? String ?? "6"
            let decimals = Int(decimalsStr) ?? 6

            let matchesSender = !fromAddr.isEmpty && fromAddr.caseInsensitiveCompare(query) == .orderedSame
            let matchesHash   = !txHash.isEmpty && txHash.caseInsensitiveCompare(query) == .orderedSame

            if matchesSender || matchesHash {
                let divisor = pow(10.0, Double(decimals))
                let amount = (Double(rawValue) ?? 0) / divisor
                return DonationVerificationResult(
                    network: "Ethereum (ERC20)",
                    amount: max(amount, 1.0),
                    currency: "USDT",
                    txHash: txHash,
                    senderAddress: fromAddr,
                    date: Date()
                )
            }
        }

        return nil
    }

    // MARK: - 4. Bitcoin

    private func checkBitcoin(query: String) async throws -> DonationVerificationResult? {
        guard let url = URL(string: "https://blockchain.info/rawaddr/\(Self.btcDepositAddress)?limit=20") else {
            return nil
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 8

        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let txs = json["txs"] as? [[String: Any]] else {
            return nil
        }

        for tx in txs {
            let hash = tx["hash"] as? String ?? ""
            let inputs = tx["inputs"] as? [[String: Any]] ?? []

            var matchedInput = false
            var senderAddr = ""
            for inp in inputs {
                if let prevOut = inp["prev_out"] as? [String: Any],
                   let addr = prevOut["addr"] as? String {
                    if addr.caseInsensitiveCompare(query) == .orderedSame {
                        matchedInput = true
                        senderAddr = addr
                        break
                    }
                }
            }

            let matchesHash = !hash.isEmpty && hash.caseInsensitiveCompare(query) == .orderedSame

            if matchedInput || matchesHash {
                let resultSat = tx["result"] as? Double ?? 0
                let btcAmount = abs(resultSat) / 100_000_000.0
                let time = (tx["time"] as? Double).map { Date(timeIntervalSince1970: $0) }
                return DonationVerificationResult(
                    network: "Bitcoin",
                    amount: btcAmount > 0 ? btcAmount : 0.001,
                    currency: "BTC",
                    txHash: hash,
                    senderAddress: senderAddr.isEmpty ? query : senderAddr,
                    date: time
                )
            }
        }

        return nil
    }
}
