import Foundation
import AppKit
import ApplicationServices
import os.log

private let logger = Logger(subsystem: "com.aleksei.scribe", category: "PersonalVocabularyMonitor")

/// Non-intrusive, privacy-first background monitor that observes user-written text across macOS apps
/// (Telegram, Browser, Messengers, Notes, IDE) for a specified duration (1 week, 2 weeks, or 1 month).
/// Automatically extracts personal rare terms and syntactic directives ("сделай", "давай", "пофикси")
/// and updates the active vocabulary and speech model conditioning in real-time.
public final class PersonalVocabularyMonitor: ObservableObject, @unchecked Sendable {
    public static let shared = PersonalVocabularyMonitor()

    @Published public private(set) var isRunning: Bool = false
    @Published public private(set) var durationDays: Int = 14 // 7, 14 (Recommended), 30
    @Published public private(set) var startDate: Date? = nil
    @Published public private(set) var endDate: Date? = nil
    @Published public private(set) var wordsAnalyzedCount: Int = 0
    @Published public private(set) var rareWordsLearnedCount: Int = 0
    @Published public private(set) var constructionsLearnedCount: Int = 0
    @Published public private(set) var recentlyLearnedWords: [String] = []

    private let lock = NSLock()
    private var globalEventMonitor: Any? = nil
    private var appSwitchObserver: NSObjectProtocol? = nil
    private var checkTimer: Timer? = nil
    private var candidateFrequencies: [String: Int] = [:]
    private var lastProcessedHash: Int = 0
    private var processingQueue = DispatchQueue(label: "com.aleksei.scribe.vocabulary_monitor", qos: .utility)

    private let spellChecker = NSSpellChecker.shared

    /// Apps strictly excluded from any text observation for user privacy & security
    private let excludedBundleIdentifiers: Set<String> = [
        "com.1password.1password",
        "com.1password.1password7",
        "com.bitwarden.desktop",
        "org.keepassxc.keepassxc",
        "com.apple.keychainaccess",
        "com.lastpass.lastpass",
        "com.apple.Preferences",
        "com.apple.systempreferences"
    ]

    private init() {
        loadPersistedState()
        if isRunning {
            if isExpired {
                stopMonitoring()
            } else {
                startEventMonitors()
            }
        }
    }

    // MARK: - Public Controls

    /// Starts or resumes monitoring with a specific duration in days (7, 14, 30)
    public func startMonitoring(days: Int = 14) {
        lock.lock()
        self.durationDays = days
        let now = Date()
        self.startDate = now
        self.endDate = Calendar.current.date(byAdding: .day, value: days, to: now)
        self.isRunning = true
        savePersistedStateUnderLock()
        lock.unlock()

        startEventMonitors()
        logger.info("Started PersonalVocabularyMonitor for \(days) days (until \(String(describing: self.endDate)))")
    }

    /// Stops monitoring, keeping all learned words and constructions intact
    public func stopMonitoring() {
        lock.lock()
        self.isRunning = false
        savePersistedStateUnderLock()
        lock.unlock()

        stopEventMonitors()
        logger.info("Stopped PersonalVocabularyMonitor")
    }

    /// Toggle monitoring state
    public func toggleMonitoring(days: Int? = nil) {
        if isRunning {
            stopMonitoring()
        } else {
            startMonitoring(days: days ?? self.durationDays)
        }
    }

    /// True if duration has elapsed
    public var isExpired: Bool {
        guard let end = endDate else { return false }
        return Date() >= end
    }

    /// Formatted countdown string (e.g. "13 дн. 21 ч." / "13d 21h")
    public var remainingTimeFormatted: String {
        guard let end = endDate, isRunning, !isExpired else {
            return isExpired ? "Завершено" : "Не активно"
        }
        let remaining = end.timeIntervalSince(Date())
        let days = Int(remaining) / 86400
        let hours = (Int(remaining) % 86400) / 3600
        if days > 0 {
            return "\(days) дн. \(hours) ч."
        } else {
            let minutes = (Int(remaining) % 3600) / 60
            return "\(hours) ч. \(minutes) мин."
        }
    }

    // MARK: - Event Observers

    private func startEventMonitors() {
        stopEventMonitors()

        // 1. Listen for Return / Enter key press globally
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            // KeyCode 36 = Return, 76 = Keypad Enter
            if event.keyCode == 36 || event.keyCode == 76 {
                self?.scheduleElementInspection(delay: 0.1)
            }
        }

        // 2. Listen for app switches (e.g. user finished typing in Telegram and switched to Chrome)
        appSwitchObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didDeactivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.scheduleElementInspection(delay: 0.2)
        }

        // 3. Periodic timer to check expiration and update UI countdown (every 60s)
        DispatchQueue.main.async {
            self.checkTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                if self.isRunning && self.isExpired {
                    self.stopMonitoring()
                }
                self.objectWillChange.send()
            }
        }
    }

    private func stopEventMonitors() {
        if let monitor = globalEventMonitor {
            NSEvent.removeMonitor(monitor)
            globalEventMonitor = nil
        }
        if let obs = appSwitchObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(obs)
            appSwitchObserver = nil
        }
        checkTimer?.invalidate()
        checkTimer = nil
    }

    private func scheduleElementInspection(delay: TimeInterval) {
        guard isRunning && !isExpired else { return }
        processingQueue.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.inspectFocusedElement()
        }
    }

    // MARK: - Safe Focused Element Inspection

    private func inspectFocusedElement() {
        guard AXIsProcessTrusted() else { return }

        // Check frontmost app to exclude password managers and settings
        if let frontApp = NSWorkspace.shared.frontmostApplication {
            if let bundleId = frontApp.bundleIdentifier?.lowercased() {
                for excluded in excludedBundleIdentifiers {
                    if bundleId.contains(excluded) { return }
                }
                if bundleId.contains("password") || bundleId.contains("keychain") || bundleId.contains("auth") {
                    return
                }
            }
        }

        let systemWide = AXUIElementCreateSystemWide()
        var focusedElementObj: AnyObject?
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focusedElementObj) == .success,
              let element = focusedElementObj as! AXUIElement? else {
            return
        }

        // 1. STRICT PRIVACY: Verify element is NOT a password/secure field
        var subroleObj: AnyObject?
        if AXUIElementCopyAttributeValue(element, kAXSubroleAttribute as CFString, &subroleObj) == .success,
           let subrole = subroleObj as? String {
            if subrole == "AXSecureTextField" || subrole.contains("Secure") {
                return // NEVER TOUCH SECURE/PASSWORD FIELDS
            }
        }

        var isPasswordObj: AnyObject?
        if AXUIElementCopyAttributeValue(element, "AXIsPassword" as CFString, &isPasswordObj) == .success,
           let isPass = isPasswordObj as? Bool, isPass {
            return // NEVER TOUCH PASSWORD FIELDS
        }

        // 2. Read text value
        var valueObj: AnyObject?
        guard AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &valueObj) == .success,
              let rawString = valueObj as? String, !rawString.isEmpty else {
            return
        }

        // De-duplicate against identical recently processed text
        let hash = rawString.hashValue
        if hash == lastProcessedHash { return }
        lastProcessedHash = hash

        // 3. Process sanitized text
        processExtractedText(rawString)
    }

    // MARK: - Privacy Sanitizer & Incremental Learning Engine

    private func processExtractedText(_ text: String) {
        // Sanitize: strip URLs, emails, long hex/base64 tokens, and credit cards
        var clean = text
        // Strip URLs
        clean = clean.replacingOccurrences(of: "https?://[^\\s]+", with: " ", options: .regularExpression)
        // Strip emails
        clean = clean.replacingOccurrences(of: "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}", with: " ", options: .regularExpression)
        // Strip credit cards (13-19 digits)
        clean = clean.replacingOccurrences(of: "\\b(?:\\d[ -]*?){13,19}\\b", with: " ", options: .regularExpression)
        // Strip long tokens / hashes (32+ chars)
        clean = clean.replacingOccurrences(of: "\\b[a-zA-Z0-9_-]{32,}\\b", with: " ", options: .regularExpression)

        guard clean.count >= 2 else { return }

        // 1. Record Sentences & Directives in UserGrammarProfile
        let sentences = clean.components(separatedBy: CharacterSet(charactersIn: ".!?\n;"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        for sentence in sentences {
            UserGrammarProfile.shared.recordSentence(sentence)
        }

        // 2. Extract Words & Detect Idiosyncratic / Rare Terms
        let wordTokens = clean.components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 3 }

        guard !wordTokens.isEmpty else { return }

        var newlyLearned: [String] = []

        lock.lock()
        wordsAnalyzedCount += wordTokens.count

        for token in wordTokens {
            let lower = token.lowercased().normalizedPlainVocabularyWord()

            // Skip numbers or common generic stop-words
            if CharacterSet.decimalDigits.isSuperset(of: CharacterSet(charactersIn: lower)) { continue }

            // Candidate frequency tracking
            let count = (candidateFrequencies[lower] ?? 0) + 1
            candidateFrequencies[lower] = count

            // Check if this is an idiosyncratic / rare term:
            // Condition A: NSSpellChecker flags it as non-standard / specialized
            // Condition B: Or it's a technical token / mixed language term
            if count >= 2 {
                let range = spellChecker.checkSpelling(of: token, startingAt: 0)
                let isNonStandardOrRare = range.location != NSNotFound || token.contains("-") || token.contains("_") || (token.rangeOfCharacter(from: .uppercaseLetters) != nil && !token.hasPrefix("http"))

                if isNonStandardOrRare {
                    // Normalize to plain letters
                    let normalizedWord = token.normalizedPlainVocabularyWord()
                    UserGrammarProfile.shared.recordIdiosyncraticWord(normalizedWord)
                    UserFrequencyDictionary.shared.record(text: normalizedWord)

                    if !recentlyLearnedWords.contains(normalizedWord) {
                        newlyLearned.append(normalizedWord)
                    }
                }
            }
        }

        if !newlyLearned.isEmpty {
            for w in newlyLearned {
                recentlyLearnedWords.insert(w, at: 0)
            }
            if recentlyLearnedWords.count > 40 {
                recentlyLearnedWords = Array(recentlyLearnedWords.prefix(40))
            }
            rareWordsLearnedCount = UserGrammarProfile.shared.learnedIdiosyncraticWordsCount
            constructionsLearnedCount = UserGrammarProfile.shared.learnedConstructionsCount
        }

        savePersistedStateUnderLock()
        lock.unlock()

        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }

    // MARK: - State Persistence

    private func savePersistedStateUnderLock() {
        let defaults = UserDefaults.standard
        defaults.set(isRunning, forKey: "writingMonitorIsRunning")
        defaults.set(durationDays, forKey: "writingMonitorDurationDays")
        if let s = startDate { defaults.set(s.timeIntervalSince1970, forKey: "writingMonitorStartDate") }
        if let e = endDate { defaults.set(e.timeIntervalSince1970, forKey: "writingMonitorEndDate") }
        defaults.set(wordsAnalyzedCount, forKey: "writingMonitorWordsAnalyzed")
        defaults.set(rareWordsLearnedCount, forKey: "writingMonitorRareWordsCount")
        defaults.set(constructionsLearnedCount, forKey: "writingMonitorConstructionsCount")
        defaults.set(recentlyLearnedWords, forKey: "writingMonitorRecentWords")
    }

    private func loadPersistedState() {
        let defaults = UserDefaults.standard
        self.isRunning = defaults.bool(forKey: "writingMonitorIsRunning")
        let d = defaults.integer(forKey: "writingMonitorDurationDays")
        self.durationDays = d > 0 ? d : 14
        let sTs = defaults.double(forKey: "writingMonitorStartDate")
        if sTs > 0 { self.startDate = Date(timeIntervalSince1970: sTs) }
        let eTs = defaults.double(forKey: "writingMonitorEndDate")
        if eTs > 0 { self.endDate = Date(timeIntervalSince1970: eTs) }
        self.wordsAnalyzedCount = defaults.integer(forKey: "writingMonitorWordsAnalyzed")
        self.rareWordsLearnedCount = defaults.integer(forKey: "writingMonitorRareWordsCount")
        self.constructionsLearnedCount = defaults.integer(forKey: "writingMonitorConstructionsCount")
        self.recentlyLearnedWords = defaults.stringArray(forKey: "writingMonitorRecentWords") ?? []
    }
}
