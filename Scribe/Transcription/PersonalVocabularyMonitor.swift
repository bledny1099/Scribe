import Foundation
import AppKit
import ApplicationServices
import os.log

private let logger = Logger(subsystem: "com.aleksei.scribe", category: "PersonalVocabularyMonitor")

public struct IgnoredApplication: Codable, Identifiable, Hashable, Sendable {
    public var id: String { bundleId }
    public let bundleId: String
    public let name: String

    public init(bundleId: String, name: String) {
        self.bundleId = bundleId
        self.name = name
    }
}

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
    @Published public private(set) var ignoredApplications: [IgnoredApplication] = []

    public static let defaultIgnoredApplications: [IgnoredApplication] = [
        IgnoredApplication(bundleId: "com.apple.Terminal", name: "Terminal"),
        IgnoredApplication(bundleId: "com.mitchellh.ghostty", name: "Ghostty"),
        IgnoredApplication(bundleId: "com.termius.mac", name: "Termius"),
        IgnoredApplication(bundleId: "com.googlecode.iterm2", name: "iTerm2"),
        IgnoredApplication(bundleId: "net.kovidgoyal.kitty", name: "Kitty"),
        IgnoredApplication(bundleId: "org.alacritty", name: "Alacritty"),
        IgnoredApplication(bundleId: "dev.warp.Warp-GKE", name: "Warp"),
        IgnoredApplication(bundleId: "com.github.wez.wezterm", name: "WezTerm"),
        IgnoredApplication(bundleId: "co.zeit.hyper", name: "Hyper"),
        IgnoredApplication(bundleId: "com.1password.1password", name: "1Password"),
        IgnoredApplication(bundleId: "com.bitwarden.desktop", name: "Bitwarden"),
        IgnoredApplication(bundleId: "org.keepassxc.keepassxc", name: "KeePassXC"),
        IgnoredApplication(bundleId: "com.apple.keychainaccess", name: "Keychain Access"),
        IgnoredApplication(bundleId: "com.apple.systempreferences", name: "System Settings")
    ]

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
        "com.apple.systempreferences",
        // Terminal emulators and CLI consoles (never harvest shell, port scan or log dumps)
        "com.apple.terminal",
        "com.googlecode.iterm2",
        "net.kovidgoyal.kitty",
        "org.alacritty",
        "dev.warp.warp-gke",
        "co.zeit.hyper",
        "com.mitchellh.ghostty",
        "org.gnu.emacs"
    ]

    /// Common English and Russian stopwords that should never be marked as idiosyncratic/rare
    private let stopWords: Set<String> = [
        // English
        "the", "a", "an", "and", "or", "but", "in", "on", "at", "to", "for", "of", "with", "by", "from",
        "up", "about", "into", "over", "after", "is", "are", "was", "were", "be", "been", "being",
        "have", "has", "had", "do", "does", "did", "shall", "will", "should", "would", "may", "might",
        "must", "can", "could", "you", "he", "she", "it", "we", "they", "him", "her", "them", "his",
        "their", "our", "what", "which", "who", "whom", "this", "that", "these", "those", "there",
        "here", "when", "where", "why", "how", "all", "any", "both", "each", "few", "more", "most",
        "other", "some", "such", "nor", "not", "only", "own", "same", "than", "too", "very", "just",
        "now", "attached", "last", "next", "first", "pro", "then", "also", "back", "even", "well",
        "sep", "oct", "nov", "dec", "jan", "feb", "mar", "apr", "jun", "jul", "aug",
        "mon", "tue", "wed", "thu", "fri", "sat", "sun",
        // Russian
        "что", "это", "как", "так", "для", "или", "если", "чтобы", "когда", "где", "куда", "откуда",
        "почему", "зачем", "все", "всё", "весь", "вся", "оно", "она", "они", "этот", "эта", "эти",
        "того", "тому", "тем", "том", "при", "про", "без", "под", "над", "перед", "между", "через",
        "после", "из", "от", "по", "на", "об", "обо", "нет", "еще", "ещё", "даже", "вдруг", "тут",
        "там", "потом", "себя", "ничего", "может", "надо", "тебя", "чем", "была", "были", "быть",
        "было", "будет", "тоже", "тогда", "кто", "потому", "этого", "какой", "совсем", "здесь",
        "этом", "один", "почти", "мой", "никогда", "можно", "наконец", "другой", "больше", "тот",
        "всего", "какая", "много", "разве", "моя", "хорошо", "свою", "этой", "иногда", "лучше",
        "нельзя", "такой", "более", "всегда", "конечно", "всю", "вчера", "сегодня", "завтра"
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

    /// Sets or updates the target monitoring duration in days without starting monitoring.
    public func setDuration(days: Int) {
        lock.lock()
        self.durationDays = days
        if isRunning, let start = startDate {
            self.endDate = Calendar.current.date(byAdding: .day, value: days, to: start)
        }
        savePersistedStateUnderLock()
        lock.unlock()

        if Thread.isMainThread {
            self.objectWillChange.send()
        } else {
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        }
        logger.info("Set PersonalVocabularyMonitor duration to \(days) days (isRunning: \(self.isRunning))")
    }

    /// Starts or resumes monitoring with a specific duration in days (7, 14, 30)
    public func startMonitoring(days: Int? = nil) {
        lock.lock()
        let targetDays = days ?? self.durationDays
        self.durationDays = targetDays
        let now = Date()
        self.startDate = now
        self.endDate = Calendar.current.date(byAdding: .day, value: targetDays, to: now)
        self.isRunning = true
        savePersistedStateUnderLock()
        lock.unlock()

        if Thread.isMainThread {
            self.objectWillChange.send()
        } else {
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        }

        startEventMonitors()
        logger.info("Started PersonalVocabularyMonitor for \(targetDays) days (until \(String(describing: self.endDate)))")
    }

    /// Stops monitoring, keeping all learned words and constructions intact
    public func stopMonitoring() {
        lock.lock()
        self.isRunning = false
        savePersistedStateUnderLock()
        lock.unlock()

        if Thread.isMainThread {
            self.objectWillChange.send()
        } else {
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        }

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

    // MARK: - Ignored Applications API

    public func addIgnoredApp(bundleId: String, name: String) {
        let trimmedId = bundleId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedId.isEmpty else { return }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let effectiveName = trimmedName.isEmpty ? trimmedId : trimmedName
        lock.lock()
        if !ignoredApplications.contains(where: { $0.bundleId.caseInsensitiveCompare(trimmedId) == .orderedSame }) {
            ignoredApplications.append(IgnoredApplication(bundleId: trimmedId, name: effectiveName))
            saveIgnoredAppsUnderLock()
        }
        lock.unlock()
        notifyUI()
    }

    public func removeIgnoredApp(bundleId: String) {
        lock.lock()
        ignoredApplications.removeAll { $0.bundleId.caseInsensitiveCompare(bundleId) == .orderedSame }
        saveIgnoredAppsUnderLock()
        lock.unlock()
        notifyUI()
    }

    public func resetIgnoredAppsToDefault() {
        lock.lock()
        ignoredApplications = Self.defaultIgnoredApplications
        saveIgnoredAppsUnderLock()
        lock.unlock()
        notifyUI()
    }

    public func isAppIgnored(bundleId: String?, name: String?) -> Bool {
        let bId = bundleId?.lowercased() ?? ""
        let n = name?.lowercased() ?? ""

        // Check configured user list
        for item in ignoredApplications {
            let itemId = item.bundleId.lowercased()
            let itemName = item.name.lowercased()
            if !bId.isEmpty && (bId == itemId || bId.contains(itemId)) { return true }
            if !n.isEmpty && (n == itemName || n.contains(itemName)) { return true }
        }

        // Automatic security & terminal keyword heuristic
        let terminalKeywords = ["terminal", "ghostty", "termius", "iterm", "alacritty", "kitty", "wezterm", "warp", "hyper", "console", "prompt", "securecrt", "bash", "zsh", "sh"]
        for kw in terminalKeywords {
            if bId.contains(kw) || n.contains(kw) { return true }
        }

        let securityKeywords = ["password", "keychain", "1password", "bitwarden", "keepass", "lastpass", "authenticator", "auth"]
        for kw in securityKeywords {
            if bId.contains(kw) || n.contains(kw) { return true }
        }

        return false
    }

    private func notifyUI() {
        if Thread.isMainThread {
            self.objectWillChange.send()
        } else {
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        }
    }

    // MARK: - Safe Focused Element Inspection

    private func inspectFocusedElement() {
        guard AXIsProcessTrusted() else { return }

        // 0. Check frontmost application
        if let frontApp = NSWorkspace.shared.frontmostApplication {
            if isAppIgnored(bundleId: frontApp.bundleIdentifier, name: frontApp.localizedName) {
                return
            }
        }

        let systemWide = AXUIElementCreateSystemWide()
        var focusedElementObj: AnyObject?
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focusedElementObj) == .success,
              let element = focusedElementObj as! AXUIElement? else {
            return
        }

        // 1. STRICT PRIVACY: Verify element's owning application process is not an ignored/terminal app
        var pid: pid_t = 0
        if AXUIElementGetPid(element, &pid) == .success,
           let app = NSRunningApplication(processIdentifier: pid) {
            if isAppIgnored(bundleId: app.bundleIdentifier, name: app.localizedName) {
                return
            }
        }

        // 2. STRICT PRIVACY: Verify element is NOT a password/secure field or terminal console
        var roleObj: AnyObject?
        if AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleObj) == .success,
           let role = roleObj as? String {
            if role == "AXTerminal" || role == "AXConsole" {
                return // NEVER TOUCH TERMINAL/SHELL CONSOLES
            }
        }

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

        // 3. Read text value (ignoring gigantic buffer dumps > 1500 chars)
        var valueObj: AnyObject?
        guard AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &valueObj) == .success,
              let rawString = valueObj as? String, !rawString.isEmpty, rawString.count <= 1500 else {
            return
        }

        // De-duplicate against identical recently processed text
        let hash = rawString.hashValue
        if hash == lastProcessedHash { return }
        lastProcessedHash = hash

        // 4. Process sanitized text
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
            .filter { $0.count >= 2 }

        guard !wordTokens.isEmpty else { return }

        var newlyLearned: [String] = []

        lock.lock()
        wordsAnalyzedCount += wordTokens.count

        for token in wordTokens {
            let lower = token.lowercased().normalizedPlainVocabularyWord()

            // Skip short tokens, numbers, or stop-words
            if lower.count < 2 { continue }
            if stopWords.contains(lower) { continue }
            if CharacterSet.decimalDigits.isSuperset(of: CharacterSet(charactersIn: lower)) { continue }

            // Strict quality check: tokens of 2-3 characters MUST be uppercase acronyms or recognized dev tools
            let isAcronym = token.count >= 2 && token.count <= 6 && token.allSatisfy { $0.isUppercase || $0.isNumber }
            let isShortDevTool = ["git", "vim", "npm", "pip", "zsh", "aws", "sql", "ssh", "api", "sdk", "mcp"].contains(lower)
            if token.count < 4 && !isAcronym && !isShortDevTool {
                continue // Rejects random typing stubs like "gho", "abc", "xyz"
            }

            // Candidate frequency tracking
            let count = (candidateFrequencies[lower] ?? 0) + 1
            candidateFrequencies[lower] = count

            // CamelCase / internal capitalization (e.g. MacBook, WhisperKit, ChatGPT, AntiGravity)
            let hasInnerCapital = token.dropFirst().contains { $0.isUppercase }
            // Technical compound identifier (e.g. dev_mode, lang-code)
            let isTechnicalCompound = token.contains("-") || token.contains("_")

            // Language-aware bilingual validation:
            // Cyrillic words must be validated ONLY against the Russian dictionary.
            // Latin words must be validated ONLY against the English dictionary.
            let hasCyrillic = token.unicodeScalars.contains { CharacterSet(charactersIn: "\u{0400}"..."\u{04FF}").contains($0) }
            let hasLatin = token.unicodeScalars.contains { (CharacterSet(charactersIn: "a"..."z").union(CharacterSet(charactersIn: "A"..."Z"))).contains($0) }

            var isStandardWord = false
            if hasCyrillic && !hasLatin {
                var ruCount = 0
                let ruRange = spellChecker.checkSpelling(
                    of: token,
                    startingAt: 0,
                    language: "ru",
                    wrap: false,
                    inSpellDocumentWithTag: 0,
                    wordCount: &ruCount
                )
                isStandardWord = (ruRange.location == NSNotFound || ruRange.length == 0)
            } else if hasLatin && !hasCyrillic {
                var enCount = 0
                let enRange = spellChecker.checkSpelling(
                    of: token,
                    startingAt: 0,
                    language: "en",
                    wrap: false,
                    inSpellDocumentWithTag: 0,
                    wordCount: &enCount
                )
                isStandardWord = (enRange.location == NSNotFound || enRange.length == 0)
            } else {
                // Mixed characters (e.g. tech slang mixing scripts) -> non-standard
                isStandardWord = false
            }

            let isNonStandardOrRare = (!isStandardWord) || hasInnerCapital || isAcronym || isTechnicalCompound

            // Technical compounds, acronyms, or CamelCase qualify on 1st occurrence; non-standard words on 2nd
            let frequencyThreshold = (hasInnerCapital || isAcronym || isTechnicalCompound) ? 1 : 2
            if count >= frequencyThreshold && isNonStandardOrRare {
                // Normalize to plain letters
                let normalizedWord = token.normalizedPlainVocabularyWord()
                UserGrammarProfile.shared.recordIdiosyncraticWord(normalizedWord)
                UserFrequencyDictionary.shared.record(text: normalizedWord)

                let lowerNorm = normalizedWord.lowercased()
                let alreadyInRecent = recentlyLearnedWords.contains { $0.lowercased() == lowerNorm }
                let alreadyInNew = newlyLearned.contains { $0.lowercased() == lowerNorm }

                if !alreadyInRecent && !alreadyInNew {
                    newlyLearned.append(normalizedWord)
                }
            }
        }

        if !newlyLearned.isEmpty {
            for w in newlyLearned {
                recentlyLearnedWords.insert(w, at: 0)
            }
            // Strict case-insensitive deduplication
            var seen = Set<String>()
            recentlyLearnedWords = recentlyLearnedWords.filter { w in
                let low = w.lowercased()
                if seen.contains(low) { return false }
                seen.insert(low)
                return true
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

    // MARK: - Learned Vocabulary Deletion & Reset API

    /// Removes an individual learned word from the monitor and profile
    public func removeLearnedWord(_ word: String) {
        let lower = word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        lock.lock()
        recentlyLearnedWords.removeAll { $0.lowercased() == lower }
        candidateFrequencies.removeValue(forKey: lower)
        rareWordsLearnedCount = max(0, rareWordsLearnedCount - 1)
        savePersistedStateUnderLock()
        lock.unlock()

        UserGrammarProfile.shared.removeIdiosyncraticWord(lower)

        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
        logger.info("Removed learned word '\(word)'")
    }

    /// Removes an individual learned directive from the grammar profile
    public func removeLearnedDirective(_ directive: String) {
        UserGrammarProfile.shared.removeDirective(directive)
        lock.lock()
        constructionsLearnedCount = UserGrammarProfile.shared.learnedConstructionsCount
        savePersistedStateUnderLock()
        lock.unlock()

        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
        logger.info("Removed learned directive '\(directive)'")
    }

    /// Clears all learned words, directives, and monitor cache
    public func clearAllLearnedWords() {
        lock.lock()
        recentlyLearnedWords.removeAll()
        candidateFrequencies.removeAll()
        rareWordsLearnedCount = 0
        constructionsLearnedCount = 0
        savePersistedStateUnderLock()
        lock.unlock()

        UserGrammarProfile.shared.clearAll()

        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
        logger.info("Cleared all learned words and directives in PersonalVocabularyMonitor")
    }

    // MARK: - State Persistence

    private func saveIgnoredAppsUnderLock() {
        if let data = try? JSONEncoder().encode(ignoredApplications) {
            UserDefaults.standard.set(data, forKey: "writingMonitorIgnoredApps")
        }
    }

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
        saveIgnoredAppsUnderLock()
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

        // Sanitize: purge "gho" and random short stubs from stored recent words
        self.recentlyLearnedWords.removeAll { w in
            let low = w.lowercased()
            if low == "gho" { return true }
            if w.count < 4 && !w.allSatisfy({ $0.isUppercase }) && !["git", "vim", "npm", "pip", "zsh", "aws", "sql", "ssh"].contains(low) {
                return true
            }
            return false
        }
        UserGrammarProfile.shared.removeIdiosyncraticWord("gho")

        // Load ignored applications
        if let data = defaults.data(forKey: "writingMonitorIgnoredApps"),
           let apps = try? JSONDecoder().decode([IgnoredApplication].self, from: data), !apps.isEmpty {
            self.ignoredApplications = apps
        } else {
            self.ignoredApplications = Self.defaultIgnoredApplications
        }
    }
}
