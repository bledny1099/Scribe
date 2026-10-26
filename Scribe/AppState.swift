import Combine
import KeyboardShortcuts
import SwiftUI
import OSLog
import UserNotifications

extension Array: @retroactive RawRepresentable where Element: Codable {
    public init?(rawValue: String) {
        guard let data = rawValue.data(using: .utf8),
              let result = try? JSONDecoder().decode([Element].self, from: data)
        else { return nil }
        self = result
    }
    public var rawValue: String {
        guard let data = try? JSONEncoder().encode(self),
              let result = String(data: data, encoding: .utf8)
        else { return "[]" }
        return result
    }
}

private let logger = Logger(subsystem: "com.aleksei.scribe", category: "AppState")

// MARK: - Recording Status

/// High-level status shown in the overlay panel.
enum RecordingStatus: Equatable {
    case idle
    case recording
    case loadingModel
    case transcribing
    case done
    case error(String)
}

// MARK: - Overlay Style

/// Visual style for the recording panel.
enum OverlayStyle: String, CaseIterable, Identifiable {
    case classic   // Original square with concentric rings
    case waveform  // Horizontal bar with waveform bars
    case minimal   // Tiny pill with just mic icon and time
    case ecg       // Pulse/oscilloscope line
    case orb       // Bouncy fluid liquid orb sphere

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .classic:  "Classic"
        case .waveform: "Waveform"
        case .minimal:  "Minimal"
        case .ecg:      "Pulse"
        case .orb:      "Orb"
        }
    }

    var icon: String {
        switch self {
        case .classic:  "circle.circle"
        case .waveform: "waveform"
        case .minimal:  "capsule"
        case .ecg:      "waveform.path.ecg"
        case .orb:      "sparkles"
        }
    }

    /// Whether this overlay style supports embedded (inside-card) live preview text.
    var supportsEmbeddedPreview: Bool {
        return true
    }

    /// Whether this overlay style has a square geometry (positioned to the left/right of windows) vs horizontal (positioned below/above windows).
    var isSquareStyle: Bool {
        switch self {
        case .classic, .orb:
            return true
        case .waveform, .minimal, .ecg:
            return false
        }
    }
}

// MARK: - Overlay Size

/// Size/scale variations for the recording panel.
enum OverlaySize: String, CaseIterable, Identifiable {
    case s100 // 100%
    case s90  // 90%
    case s80  // 80%
    case s70  // 70%

    var id: String { rawValue }

    var scale: CGFloat {
        switch self {
        case .s100: 1.00
        case .s90:  0.90
        case .s80:  0.80
        case .s70:  0.70
        }
    }

    var displayName: String {
        switch self {
        case .s100: "100%"
        case .s90:  "90%"
        case .s80:  "80%"
        case .s70:  "70%"
        }
    }

    var shortName: String {
        switch self {
        case .s100: "100%"
        case .s90:  "90%"
        case .s80:  "80%"
        case .s70:  "70%"
        }
    }

    var icon: String { "" }
}

// MARK: - Overlay Position Mode

/// How the overlay panel is positioned on screen during dictation.
public enum OverlayPositionMode: String, CaseIterable, Identifiable {
    case activeWindow = "Active Window"
    case screenBottom = "Screen Bottom"
    case custom = "Free"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .activeWindow: "Active Window"
        case .screenBottom: "Screen Bottom"
        case .custom:       "Free"
        }
    }

    public var shortName: String {
        switch self {
        case .activeWindow: "Active Window"
        case .screenBottom: "Screen Bottom"
        case .custom:       "Free"
        }
    }

    public var icon: String {
        switch self {
        case .activeWindow: "macwindow"
        case .screenBottom: "menubar.dock.rectangle"
        case .custom:       "hand.draw"
        }
    }
}

// MARK: - Panel Appearance

/// Background appearance for the recording panel.
enum PanelAppearance: String, CaseIterable, Identifiable {
    case dark
    case light
    case liquidGlass

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .dark:        "Dark"
        case .light:       "Light"
        case .liquidGlass: "Liquid Glass"
        }
    }

    var shortName: String {
        switch self {
        case .dark:        "Dark"
        case .light:       "Light"
        case .liquidGlass: "Liquid Glass"
        }
    }

    var icon: String {
        switch self {
        case .dark:        "moon.fill"
        case .light:       "sun.max"
        case .liquidGlass: "drop.fill"
        }
    }

    var nsAppearance: NSAppearance {
        switch self {
        case .dark:        NSAppearance(named: .darkAqua)!
        case .light:       NSAppearance(named: .aqua)!
        case .liquidGlass: NSAppearance(named: .vibrantDark)!
        }
    }

    var material: NSVisualEffectView.Material {
        switch self {
        case .dark:        .underWindowBackground
        case .light:       .sheet
        case .liquidGlass: .fullScreenUI
        }
    }

    var backgroundColor: NSColor {
        switch self {
        case .dark:        NSColor(red: 0.05, green: 0.05, blue: 0.07, alpha: 0.88)
        case .light:       NSColor(white: 0.95, alpha: 0.85)
        case .liquidGlass: NSColor.clear
        }
    }
}

// MARK: - Paste Mode

/// How transcribed text is inserted.
enum PasteMode: String, CaseIterable, Identifiable {
    case paste             // Replace clipboard and paste (⌘V)
    case directType        // Direct typing via simulated keystrokes (zero clipboard footprint)
    case append            // Append to current clipboard text and paste
    case integrationsOnly  // Export to notes/integrations only (no active window paste)

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .paste:            return "Paste (⌘V)"
        case .directType:       return "Direct Typing"
        case .append:           return "Append"
        case .integrationsOnly: return "Integrations Only"
        }
    }

    var icon: String {
        switch self {
        case .paste:            return "doc.on.clipboard"
        case .directType:       return "keyboard"
        case .append:           return "text.append"
        case .integrationsOnly: return "link"
        }
    }
}

// MARK: - Subtitle Background

/// Background style for live subtitle window.
enum SubtitleBackground: String, CaseIterable, Identifiable {
    case glass
    case dark
    case transparent

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .glass: "Glass"
        case .dark: "Solid"
        case .transparent: "Transparent"
        }
    }

    var icon: String {
        switch self {
        case .glass: "square.stack.3d.up.fill"
        case .dark: "square.fill"
        case .transparent: "square.dashed"
        }
    }
}

// MARK: - Live Preview Mode

/// Placement mode for Live Preview text (Floating Window, Direct Window Insertion, or Both).
enum LivePreviewMode: String, CaseIterable, Identifiable {
    case external = "external"
    case directInsert = "directInsert"
    case both = "both"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .external:     "Floating Window"
        case .directInsert: "Direct Window Insertion"
        case .both:         "Both"
        }
    }

    var icon: String {
        switch self {
        case .external:     "macwindow.on.rectangle"
        case .directInsert: "cursorarrow.and.square.on.square.dashed"
        case .both:         "square.split.2x1"
        }
    }
}

// MARK: - Constants

struct LanguageOption: Identifiable, Hashable {
    let id: String
    let name: String
    let children: [LanguageOption]?
    
    init(_ id: String, _ name: String, children: [LanguageOption]? = nil) {
        self.id = id
        self.name = name
        self.children = children
    }
}

let supportedLanguages: [LanguageOption] = [
    LanguageOption("auto", "Auto Detect"),
    LanguageOption("en", "English", children: [
        LanguageOption("en-US", "English (United States)"),
        LanguageOption("en-GB", "English (United Kingdom)"),
        LanguageOption("en-AU", "English (Australia)"),
        LanguageOption("en-CA", "English (Canada)"),
        LanguageOption("en-IN", "English (India)"),
        LanguageOption("en-NZ", "English (New Zealand)"),
        LanguageOption("en-ZA", "English (South Africa)"),
        LanguageOption("en-IE", "English (Ireland)")
    ]),
    LanguageOption("ru", "Russian (Русский)"),
    LanguageOption("es", "Spanish (Español)"),
    LanguageOption("de", "German (Deutsch)"),
    LanguageOption("fr", "French (Français)"),
    LanguageOption("it", "Italian (Italiano)"),
    LanguageOption("zh", "Chinese (中文)"),
    LanguageOption("ja", "Japanese (日本語)"),
    LanguageOption("pt", "Portuguese (Português)"),
    LanguageOption("tr", "Turkish (Türkçe)"),
    LanguageOption("uk", "Ukrainian (Українська)"),
    LanguageOption("ar", "Arabic (العربية)"),
    LanguageOption("hi", "Hindi (हिन्दी)"),
    LanguageOption("ko", "Korean (한국어)"),
    LanguageOption("nl", "Dutch (Nederlands)"),
    LanguageOption("pl", "Polish (Polski)"),
    LanguageOption("sv", "Swedish (Svenska)"),
    LanguageOption("fi", "Finnish (Suomi)"),
    LanguageOption("he", "Hebrew (עברית)"),
    LanguageOption("el", "Greek (Ελληνικά)"),
    LanguageOption("cs", "Czech (Čeština)"),
    LanguageOption("da", "Danish (Dansk)"),
    LanguageOption("hu", "Hungarian (Magyar)"),
    LanguageOption("ro", "Romanian (Română)"),
    LanguageOption("no", "Norwegian (Norsk)"),
    LanguageOption("sk", "Slovak (Slovenčina)"),
    LanguageOption("th", "Thai (ไทย)"),
    LanguageOption("vi", "Vietnamese (Tiếng Việt)"),
    LanguageOption("id", "Indonesian (Bahasa Indonesia)"),
    LanguageOption("kk", "Kazakh (Қазақша)"),
    LanguageOption("uz", "Uzbek (Oʻzbekcha)"),
    LanguageOption("az", "Azerbaijani (Azərbaycan)"),
    LanguageOption("ka", "Georgian (ქართული)"),
    LanguageOption("hy", "Armenian (Հայերեն)"),
    LanguageOption("sr", "Serbian (Српски)"),
    LanguageOption("hr", "Croatian (Hrvatski)"),
    LanguageOption("bg", "Bulgarian (Български)"),
    LanguageOption("sl", "Slovenian (Slovenščina)"),
    LanguageOption("lt", "Lithuanian (Lietuvių)"),
    LanguageOption("lv", "Latvian (Latviešu)"),
    LanguageOption("et", "Estonian (Eesti)"),
    LanguageOption("fa", "Persian (فارسی)"),
    LanguageOption("ms", "Malay (Bahasa Melayu)"),
    LanguageOption("tl", "Tagalog / Filipino"),
    LanguageOption("ca", "Catalan (Català)"),
    LanguageOption("is", "Icelandic (Íslenska)"),
    LanguageOption("ta", "Tamil (தமிழ்)"),
    LanguageOption("bn", "Bengali (বাংলা)"),
    LanguageOption("ur", "Urdu (اردو)")
]

/// Helper to get a flat list of all selectable language IDs (used for validation).
let allSupportedLanguageIDs: [String] = supportedLanguages.flatMap { lang in
    if let children = lang.children {
        return children.map { $0.id }
    }
    return [lang.id]
}

/// Helper to resolve dialect codes like "en-US" to base codes like "en" for Whisper.
func baseLanguageCode(for code: String) -> String {
    code.components(separatedBy: "-").first ?? code
}

// MARK: - Supporter Celebration Data

struct SupporterCelebrationData: Equatable, Sendable {
    let tier: SupporterTier
    let amount: Double
    let currency: String
    let txHash: String
    let isPreview: Bool

    init(tier: SupporterTier, amount: Double = 0, currency: String = "", txHash: String = "", isPreview: Bool = false) {
        self.tier = tier
        self.amount = amount
        self.currency = currency
        self.txHash = txHash
        self.isPreview = isPreview
    }
}

// MARK: - App State

/// Central orchestrator that connects recording, transcription and paste services.
@MainActor
final class AppState: ObservableObject {

    public static weak var shared: AppState?

    // MARK: Published UI State

    @Published var isRecording    = false
    @Published var isTranscribing = false
    @Published var audioLevel: Float = 0
    @Published var recordingStatus: RecordingStatus = .idle {
        didSet {
            if recordingStatus == .transcribing {
                startTranscribingDotTimer()
            } else {
                stopTranscribingDotTimer()
            }
        }
    }
    
    // MARK: - Lecture Recording & File Import State
    @Published public var isLectureRecording: Bool = false
    @Published public var isImportTranscribing: Bool = false
    @Published public var importProgressMessage: String = ""
    @Published public var lastImportedNoteTitle: String = ""
    @AppStorage("showLectureControls") public var showLectureControls: Bool = true
    @AppStorage("autoOpenNotesAfterLecture") public var autoOpenNotesAfterLecture: Bool = true
    @AppStorage("lectureTitlePrefix") public var lectureTitlePrefix: String = "Lecture"
    @AppStorage("lectureTargetAppleNotes") public var lectureTargetAppleNotes: Bool = true
    @AppStorage("lectureTargetObsidian") public var lectureTargetObsidian: Bool = false
    @AppStorage("lectureTargetNotion") public var lectureTargetNotion: Bool = false

    @AppStorage("cleanFillerWords") var cleanFillerWords: Bool = true
    @Published var targetAppName: String = ""
    @Published var targetAppIcon: NSImage? = nil
    public var targetRunningApplication: NSRunningApplication? = nil

    public func captureTargetApplication() {
        let scribeID = Bundle.main.bundleIdentifier
        let isScribeActive = NSApp.isActive || 
                             (SettingsWindowManager.shared.window?.isKeyWindow == true) ||
                             (NSApp.keyWindow != nil && NSApp.keyWindow !== recordingPanel) ||
                             (NSWorkspace.shared.frontmostApplication?.bundleIdentifier == scribeID)

        if isScribeActive {
            targetAppName = "Scribe"
            targetAppIcon = NSApp.applicationIconImage ?? NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath)
            targetRunningApplication = NSRunningApplication.current
        } else if let frontApp = NSWorkspace.shared.frontmostApplication, frontApp.bundleIdentifier != scribeID {
            targetAppName = frontApp.localizedName ?? ""
            targetAppIcon = frontApp.icon
            targetRunningApplication = frontApp
        } else if let menuApp = NSWorkspace.shared.menuBarOwningApplication, menuApp.bundleIdentifier != scribeID {
            targetAppName = menuApp.localizedName ?? ""
            targetAppIcon = menuApp.icon
            targetRunningApplication = menuApp
        } else if let activeApp = NSWorkspace.shared.runningApplications.first(where: { $0.isActive && $0.bundleIdentifier != scribeID }) {
            targetAppName = activeApp.localizedName ?? ""
            targetAppIcon = activeApp.icon
            targetRunningApplication = activeApp
        } else {
            targetAppName = "Scribe"
            targetAppIcon = NSApp.applicationIconImage ?? NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath)
            targetRunningApplication = NSRunningApplication.current
        }
    }

    @Published public var recordingDuration: TimeInterval = 0
    @Published var livePreviewText: String = ""
    @Published var latestWhisperTranscription: String = ""
    private var liveStreamLastInsertedText: String = ""
    private var interimWhisperTimer: Timer?
    private var interimWhisperTask: Task<Void, Never>?
    @Published var requestedSettingsTab: SettingsTab? = nil
    @Published var supporterCelebrationData: SupporterCelebrationData? = nil

    func triggerSupporterCelebration(
        tier: SupporterTier,
        amount: Double = 0,
        currency: String = "",
        txHash: String = "",
        isPreview: Bool = false
    ) {
        let effectiveTier = tier == .none ? .tier2 : tier
        let data = SupporterCelebrationData(tier: effectiveTier, amount: amount, currency: currency, txHash: txHash, isPreview: isPreview)
        withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
            self.supporterCelebrationData = data
        }
        SoundFeedback.play(.supporterCelebration)
    }

    @Published public var transcribingDotCount: Int = 3
    private var transcribingDotTimer: Timer?

    public func startTranscribingDotTimer() {
        // Handled smoothly via GPU in TranscribingAnimationView
    }

    public func stopTranscribingDotTimer() {
        transcribingDotTimer?.invalidate()
        transcribingDotTimer = nil
    }

    public var transcribingStatusText: String {
        l("Transcribing")
    }

    // MARK: App Storage Preferences

    public var selectedLanguage: String {
        get {
            if recognitionMode == "singleLanguage" {
                return singleDictationLanguage
            } else {
                return "auto"
            }
        }
        set {
            if recognitionMode == "singleLanguage" {
                singleDictationLanguage = newValue
            }
        }
    }
    @AppStorage("selectedUILanguage") var selectedUILanguage: String = "auto"
    @AppStorage("selectedModel") var selectedModel: String = "openai_whisper-large-v3_turbo" {
        didSet {
            if oldValue != selectedModel {
                preloadModel()
            }
        }
    }

    /// Dynamically selects the optimal model:
    /// Returns the selected model tier (Turbo, Studio, Eco), defaulting to Turbo if unspecified.
    public var effectiveModel: String {
        if selectedModel.isEmpty {
            return "openai_whisper-large-v3_turbo"
        }
        return selectedModel
    }

    /// Helper for string localization using current selected UI language.
    func l(_ key: String) -> String {
        key.loc(selectedUILanguage)
    }
    @AppStorage("selectedTheme") var selectedThemeRaw: String = AppTheme.ocean.rawValue
    @AppStorage("selectedOverlayStyle") var selectedOverlayStyleRaw: String = OverlayStyle.waveform.rawValue
    @AppStorage("selectedOverlaySize") var selectedOverlaySizeRaw: String = OverlaySize.s90.rawValue
    @AppStorage("overlayPositionMode") var overlayPositionModeRaw: String = OverlayPositionMode.screenBottom.rawValue
    @AppStorage("hasCustomOverlayPosition") public var hasCustomOverlayPosition: Bool = false
    @AppStorage("customOverlayOriginX") public var customOverlayOriginX: Double = 0
    @AppStorage("customOverlayOriginY") public var customOverlayOriginY: Double = 0
    @AppStorage("selectedOverlayAppearance") var selectedOverlayAppearanceRaw: String = PanelAppearance.liquidGlass.rawValue
    @AppStorage("selectedPanelAppearance") var selectedPanelAppearanceRaw: String = PanelAppearance.liquidGlass.rawValue
    @AppStorage("preserveClipboard") public var preserveClipboard: Bool = true
    @AppStorage("soundFeedbackEnabled") var soundFeedbackEnabled: Bool = true
    @AppStorage("livePreviewEnabled") var livePreviewEnabled: Bool = true
    @AppStorage("livePreviewBackground") var livePreviewBackgroundRaw: String = SubtitleBackground.glass.rawValue
    @AppStorage("durationVisible") public var durationVisible: Bool = true
    @AppStorage("showTargetAppInOverlay") public var showTargetAppInOverlay: Bool = true
    @AppStorage("autoTranslate") var autoTranslate: Bool = false
    @AppStorage("noteExportMode") public var noteExportMode: ExportMode = .append
    @AppStorage("appleNotesExportMode") public var appleNotesExportModeRaw: String = ExportMode.append.rawValue
    public var appleNotesExportMode: ExportMode {
        get { ExportMode(rawValue: appleNotesExportModeRaw) ?? .append }
        set { appleNotesExportModeRaw = newValue.rawValue }
    }
    @AppStorage("enableAppleNotes") public var enableAppleNotes: Bool = false
    @AppStorage("attachAudioToNotes") public var attachAudioToNotes: Bool = false
    @AppStorage("textReplacements") public var textReplacements: [Replacement] = []
    @AppStorage("enableObsidian") public var enableObsidian: Bool = false
    @AppStorage("appleNotesTargetNote") public var appleNotesTargetNote: String = "Scribe Notes"
    @AppStorage("obsidianVaultURL") public var obsidianVaultURL: String = ""
    @AppStorage("obsidianTargetNote") public var obsidianTargetNote: String = "Scribe Notes"
    @AppStorage("enableNotion") public var enableNotion: Bool = false
    public var notionIntegrationToken: String {
        get { KeychainHelper.shared.getNotionToken() }
        set {
            objectWillChange.send()
            KeychainHelper.shared.setNotionToken(newValue)
        }
    }
    @AppStorage("notionPageId") public var notionPageId: String = ""
    @AppStorage("integrationExportMode") public var integrationExportMode: String = "both" // "both", "notesOnly", "windowOnly"
    @AppStorage("vocabulary") public var vocabulary: String = ""
    @AppStorage("blockedWords") public var blockedWords: String = ""
    @AppStorage("blockedWordsAction") public var blockedWordsActionRaw: String = "remove" // "remove" or "mask"
    @AppStorage("customVocabularyPresets") public var customVocabularyPresets: [VocabularyPreset] = []
    @AppStorage("customBlockedWordsPresets") public var customBlockedWordsPresets: [VocabularyPreset] = []
    @AppStorage("customLocationPresets") public var customLocationPresets: [VocabularyPreset] = []
    @AppStorage("activeLocationPresetIds") public var activeLocationPresetIds: [String] = []
    @AppStorage("userCityLocation") public var userCityLocation: String = ""
    @AppStorage("smartCasingEnabled") public var smartCasingEnabled: Bool = true

    // MARK: - Personal Writing & Speech Habit Monitor
    public var vocabularyMonitor: PersonalVocabularyMonitor {
        PersonalVocabularyMonitor.shared
    }

    // MARK: - AI Post-Processing & Refinement
    @AppStorage("enableCloudAI") public var enableCloudAI: Bool = false
    @AppStorage("cloudAIProvider") public var cloudAIProviderRaw: String = CloudAIProvider.groq.rawValue
    @AppStorage("selectedAIRefinementMode") public var selectedAIRefinementModeRaw: String = AIRefinementMode.polish.rawValue
    @AppStorage("groqAPIKey") public var groqAPIKey: String = ""
    @AppStorage("cerebrasAPIKey") public var cerebrasAPIKey: String = ""
    @AppStorage("geminiAPIKey") public var geminiAPIKey: String = ""
    @AppStorage("customOpenAIBaseURL") public var customOpenAIBaseURL: String = "https://api.openai.com/v1"
    @AppStorage("customOpenAIKey") public var customOpenAIKey: String = ""
    @AppStorage("customOpenAIModel") public var customOpenAIModel: String = "gpt-4o-mini"
    @AppStorage("geminiModel") public var geminiModel: String = "gemini-2.0-flash"
    @AppStorage("cerebrasModel") public var cerebrasModel: String = "gpt-oss-120b"
    @AppStorage("groqModel") public var groqModel: String = "qwen/qwen3.8-27b"
    @AppStorage("anthropicAPIKey") public var anthropicAPIKey: String = ""
    @AppStorage("openAIAPIKey") public var openAIAPIKey: String = ""
    @AppStorage("ollamaEndpoint") public var ollamaEndpoint: String = "http://localhost:11434"
    @AppStorage("ollamaModel") public var ollamaModel: String = "qwen2.5:7b"
    @Published public var lastAIErrorMessage: String? = nil

    // MARK: - AI Gateway Keys (Auto-Failover)
    @AppStorage("aiGatewayKeysJSON") public var aiGatewayKeysJSON: String = ""
    @AppStorage("isAIGatewayExpanded") public var isAIGatewayExpanded: Bool = false
    @Published public var gatewayKeys: [AIGatewayKey] = []

    public var cloudAIProvider: CloudAIProvider {
        get { CloudAIProvider(rawValue: cloudAIProviderRaw) ?? .groq }
        set { cloudAIProviderRaw = newValue.rawValue }
    }

    public var selectedAIRefinementMode: AIRefinementMode {
        get { AIRefinementMode(rawValue: selectedAIRefinementModeRaw) ?? .polish }
        set { selectedAIRefinementModeRaw = newValue.rawValue }
    }

    public var activeCloudAPIKey: String {
        switch cloudAIProvider {
        case .groq:
            return groqAPIKey
        case .cerebras:
            return cerebrasAPIKey
        case .gemini:
            return geminiAPIKey
        case .customOpenAI:
            return customOpenAIKey
        case .openAI:
            return openAIAPIKey
        case .anthropic:
            return anthropicAPIKey
        case .ollama:
            return ""
        }
    }

    public var isAIPostProcessingActive: Bool {
        guard enableCloudAI else { return false }
        if cloudAIProvider == .ollama { return true }
        if !gatewayKeys.filter({ $0.isEnabled && !$0.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }).isEmpty {
            return true
        }
        return !activeCloudAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public func loadGatewayKeys() {
        if !aiGatewayKeysJSON.isEmpty, let data = aiGatewayKeysJSON.data(using: .utf8) {
            do {
                let decoded = try JSONDecoder().decode([AIGatewayKey].self, from: data)
                self.gatewayKeys = decoded
                return
            } catch {
                logger.error("Failed to decode gatewayKeys: \(error.localizedDescription)")
            }
        }

        // Migration from existing standalone keys if gateway is empty
        var initialKeys: [AIGatewayKey] = []
        if !groqAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            initialKeys.append(AIGatewayKey(provider: .groq, apiKey: groqAPIKey))
        }
        if !cerebrasAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            initialKeys.append(AIGatewayKey(provider: .cerebras, apiKey: cerebrasAPIKey))
        }
        if !geminiAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            initialKeys.append(AIGatewayKey(provider: .gemini, apiKey: geminiAPIKey))
        }
        if !openAIAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            initialKeys.append(AIGatewayKey(provider: .openAI, apiKey: openAIAPIKey))
        }
        if !anthropicAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            initialKeys.append(AIGatewayKey(provider: .anthropic, apiKey: anthropicAPIKey))
        }
        if !customOpenAIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            initialKeys.append(AIGatewayKey(provider: .customOpenAI, apiKey: customOpenAIKey, customModel: customOpenAIModel, customBaseURL: customOpenAIBaseURL))
        }

        self.gatewayKeys = Array(initialKeys.prefix(10))
        if !initialKeys.isEmpty {
            saveGatewayKeys()
        }
    }

    public func saveGatewayKeys() {
        do {
            let data = try JSONEncoder().encode(gatewayKeys)
            if let string = String(data: data, encoding: .utf8) {
                aiGatewayKeysJSON = string
            }
        } catch {
            logger.error("Failed to save gatewayKeys: \(error.localizedDescription)")
        }
    }

    public func addGatewayKey(provider: CloudAIProvider, apiKey: String, customModel: String = "", customBaseURL: String = "") {
        let cleanKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanKey.isEmpty else { return }

        if let existingIdx = gatewayKeys.firstIndex(where: { $0.apiKey == cleanKey }) {
            gatewayKeys[existingIdx].provider = provider
            gatewayKeys[existingIdx].isEnabled = true
            if !customModel.isEmpty { gatewayKeys[existingIdx].customModel = customModel }
            if !customBaseURL.isEmpty { gatewayKeys[existingIdx].customBaseURL = customBaseURL }
            saveGatewayKeys()
        } else {
            guard gatewayKeys.count < 10 else { return }
            let newKey = AIGatewayKey(provider: provider, apiKey: cleanKey, isEnabled: true, customModel: customModel, customBaseURL: customBaseURL)
            gatewayKeys.append(newKey)
            saveGatewayKeys()
        }

        if gatewayKeys.count == 1 {
            cloudAIProvider = provider
        }

        // Sync fallback key if empty
        switch provider {
        case .groq:
            if groqAPIKey.isEmpty { groqAPIKey = cleanKey }
        case .cerebras:
            if cerebrasAPIKey.isEmpty { cerebrasAPIKey = cleanKey }
        case .gemini:
            if geminiAPIKey.isEmpty { geminiAPIKey = cleanKey }
        case .openAI:
            if openAIAPIKey.isEmpty { openAIAPIKey = cleanKey }
        case .anthropic:
            if anthropicAPIKey.isEmpty { anthropicAPIKey = cleanKey }
        case .customOpenAI:
            if customOpenAIKey.isEmpty {
                customOpenAIKey = cleanKey
                if !customModel.isEmpty { customOpenAIModel = customModel }
                if !customBaseURL.isEmpty { customOpenAIBaseURL = customBaseURL }
            }
        case .ollama:
            break
        }
    }

    public func removeGatewayKey(id: UUID) {
        gatewayKeys.removeAll { $0.id == id }
        saveGatewayKeys()
    }

    public func toggleGatewayKey(id: UUID) {
        if let idx = gatewayKeys.firstIndex(where: { $0.id == id }) {
            gatewayKeys[idx].isEnabled.toggle()
            saveGatewayKeys()
        }
    }

    public func moveGatewayKeyUp(id: UUID) {
        guard let idx = gatewayKeys.firstIndex(where: { $0.id == id }), idx > 0 else { return }
        gatewayKeys.swapAt(idx, idx - 1)
        saveGatewayKeys()
    }

    public func moveGatewayKeyDown(id: UUID) {
        guard let idx = gatewayKeys.firstIndex(where: { $0.id == id }), idx < gatewayKeys.count - 1 else { return }
        gatewayKeys.swapAt(idx, idx + 1)
        saveGatewayKeys()
    }

    public func moveGatewayKeyToTop(id: UUID) {
        guard let idx = gatewayKeys.firstIndex(where: { $0.id == id }), idx > 0 else { return }
        let item = gatewayKeys.remove(at: idx)
        gatewayKeys.insert(item, at: 0)
        saveGatewayKeys()
    }

    public func moveGatewayKeyToBottom(id: UUID) {
        guard let idx = gatewayKeys.firstIndex(where: { $0.id == id }), idx < gatewayKeys.count - 1 else { return }
        let item = gatewayKeys.remove(at: idx)
        gatewayKeys.append(item)
        saveGatewayKeys()
    }

    public static let defaultVocabularyPresets: [VocabularyPreset] = [
        VocabularyPreset(
            name: "IDE & Vibe Coding",
            description: "Xcode, Cursor, VS Code, Codex, Antigravity & vibe coding terminology",
            words: [
                "vibe coding", "вайб-кодинг", "вайбкодинг", "Codex", "Codex CLI", "Antigravity", "Antigravity 2.0",
                "Cursor", "Windsurf", "Trae", "Zed", "Xcode", "VS Code", "GitHub Copilot", "Claude Code",
                "refactor", "commit", "merge", "pull request", "branch", "terminal", "Docker", "Git", "Swift",
                "SwiftUI", "SwiftData", "TypeScript", "Python", "Rust", "Go", "Next.js", "TailwindCSS", "PostgreSQL",
                "Supabase", "Vercel", "API", "SDK", "JSON", "regex", "struct", "class", "enum", "async", "await",
                "function", "endpoint", "backend", "frontend", "fullstack", "MCP",
                "коммит", "пул реквест", "ветка", "деплой", "баг", "пофиксить", "рефакторинг", "эндпоинт",
                "сделай", "сделай что-то", "создай", "напиши", "добавь", "удали", "пофикси", "запусти", "проверь", "обнови", "настрой", "исправь", "покажи", "сгенерируй"
            ],
            shareCode: "scr_voc_ide_vibe_coding",
            category: "developer_tools"
        ),
        VocabularyPreset(
            name: "AI Assistants & LLMs",
            description: "ChatGPT, chatgpt.com, Gemini, Groq, Cerebras, Claude, Ollama & models",
            words: [
                "chatgpt.com", "ChatGPT", "Gemini", "Groq", "Cerebras", "Claude", "Kimi", "LM Studio", "LM Studio Bionic", "Ollama", "Perplexity",
                "DeepSeek", "Poe", "Jan", "LocalAI", "Bionic GPT", "GGUF", "LoRA", "Hugging Face", "vLLM",
                "Llama", "Mistral", "Qwen", "DeepSeek-R1", "Claude 3.5 Sonnet", "Gemini 1.5 Pro", "Gemini 2.0 Flash", "GPT-4o", "o1", "o3-mini",
                "промпт", "системный промпт", "токены", "контекст", "температура", "инференс", "квантование", "эмбеддинги",
                "веса модели", "нейросеть", "чат-бот", "рассуждения", "промптинг",
                "system prompt", "reasoning", "chain of thought", "tokens", "inference", "context window", "temperature", "prompt engineering"
            ],
            shareCode: "scr_voc_ai_assistants_llms",
            category: "developer_tools"
        )
    ]

    public static let defaultLocationPresets: [VocabularyPreset] = []

    public var effectiveUserLocation: String {
        var items: [String] = []
        if !userCityLocation.isEmpty {
            let split = userCityLocation.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            items.append(contentsOf: split)
        }
        for preset in customLocationPresets {
            if activeLocationPresetIds.contains(preset.id.uuidString) || activeLocationPresetIds.isEmpty {
                items.append(contentsOf: preset.words)
            }
        }
        return items.joined(separator: ", ")
    }
    @AppStorage("allowAnonymousVocabularyContribution") public var allowAnonymousVocabularyContribution: Bool = false
    @AppStorage("hasPromptedVocabularyDataSharing") public var hasPromptedVocabularyDataSharing: Bool = false
    @AppStorage("recognitionEngine") public var recognitionEngine: String = "Aether Neural (Recommended)"
    
    public var isInstantEngine: Bool {
        recognitionEngine.contains("Instant")
    }

    public var isParakeetSupported: Bool {
        recognitionEngine.contains("Parakeet") && ParakeetEngine.canHandle(
            language: recognitionMode == "singleLanguage" ? singleDictationLanguage : nil,
            preferredLanguages: recognitionMode == "multilingual" ? multilingualLanguages : []
        ) && !autoTranslate
    }

    public var recognitionEngineDescription: String {
        if isInstantEngine {
            return l("Aether Instant uses Apple's built-in native speech engine with zero model downloads (~0 MB) strictly for English (en-US).")
        } else if recognitionEngine.contains("Turbo") {
            return l("Aether Turbo uses lightweight quantized Whisper models for fast, low-latency offline dictation across 99+ languages.")
        } else if recognitionEngine.contains("Parakeet") {
            return l("Aether Parakeet uses NVIDIA FastConformer TDT 0.6B on Apple Neural Engine (ANE) for ultra-low latency acoustic decoding.")
        } else {
            return l("Aether Neural runs high-accuracy WhisperKit on Apple Neural Engine (ANE) & GPU with context conditioning, dynamic vocabulary, and rich grammatical language modeling.")
        }
    }
    @AppStorage("recognitionMode") private var savedRecognitionMode: String = "singleLanguage"
    @AppStorage("singleDictationLanguage") private var savedSingleDictationLanguage: String = "en"
    @AppStorage("multilingualLanguages") public var multilingualLanguages: [String] = ["en"]

    public var recognitionMode: String {
        get {
            multilingualLanguages.count == 1 ? "singleLanguage" : "multilingual"
        }
        set {
            savedRecognitionMode = newValue
        }
    }

    public var singleDictationLanguage: String {
        get {
            if multilingualLanguages.count == 1, let first = multilingualLanguages.first {
                return first
            }
            return savedSingleDictationLanguage
        }
        set {
            savedSingleDictationLanguage = newValue
        }
    }

    public func toggleMultilingualLanguage(_ langId: String) {
        var list = multilingualLanguages
        if let idx = list.firstIndex(of: langId) {
            if list.count > 1 {
                list.remove(at: idx)
            }
        } else {
            if list.count < 3 {
                list.append(langId)
            } else {
                list.removeFirst()
                list.append(langId)
            }
        }
        multilingualLanguages = list
        if list.count == 1 {
            savedSingleDictationLanguage = list[0]
            savedRecognitionMode = "singleLanguage"
        } else {
            savedRecognitionMode = "multilingual"
        }
    }

    @AppStorage("pushToTalk") public var pushToTalk: Bool = false
    @AppStorage("scribeTranscriptionMode") public var transcriptionModeRaw: String = ScribeMode.clean.rawValue

    public var transcriptionMode: ScribeMode {
        get { ScribeMode(rawValue: transcriptionModeRaw) ?? .clean }
        set { transcriptionModeRaw = newValue.rawValue }
    }

    @AppStorage("defaultNoteTags") public var defaultNoteTags: String = ""
    @AppStorage("appendDateToNotes") public var appendDateToNotes: Bool = true
    @AppStorage("enableDirectNote") public var enableDirectNote: Bool = true
    @AppStorage("directNoteTargetApp") var directNoteTargetAppRaw: String = NoteApp.appleNotes.rawValue
    @AppStorage("directNoteTargetApps") public var directNoteTargetAppsRaw: String = "appleNotes"
    @Published public var isDirectNoteRecording: Bool = false

    /// Multi-app direct note targets (1 or more apps)
    public var directNoteTargetApps: Set<NoteApp> {
        get {
            let ids = directNoteTargetAppsRaw.split(separator: ",").map(String.init)
            let apps = ids.compactMap { NoteApp(rawValue: $0) }
            return apps.isEmpty ? [.appleNotes] : Set(apps)
        }
        set {
            let val = newValue.isEmpty ? [.appleNotes] : newValue
            directNoteTargetAppsRaw = val.map(\.rawValue).joined(separator: ",")
            if let first = val.first {
                directNoteTargetAppRaw = first.rawValue
            }
        }
    }

    public func toggleDirectNoteTargetApp(_ app: NoteApp) {
        var current = directNoteTargetApps
        if current.contains(app) {
            if current.count > 1 {
                current.remove(app)
            }
        } else {
            current.insert(app)
        }
        directNoteTargetApps = current
    }

    /// Computed property for backward compatibility
    var directNoteTargetApp: NoteApp {
        get { directNoteTargetApps.first ?? .appleNotes }
        set {
            directNoteTargetApps = [newValue]
        }
    }

    /// Computed property for type-safe theme access.
    var selectedTheme: AppTheme {
        get { AppTheme(rawValue: selectedThemeRaw) ?? .ocean }
        set { selectedThemeRaw = newValue.rawValue }
    }

    /// Computed property for type-safe overlay style access.
    var selectedOverlayStyle: OverlayStyle {
        get { OverlayStyle(rawValue: selectedOverlayStyleRaw) ?? .waveform }
        set {
            selectedOverlayStyleRaw = newValue.rawValue
        }
    }

    /// Computed property for type-safe overlay size access.
    var selectedOverlaySize: OverlaySize {
        get { OverlaySize(rawValue: selectedOverlaySizeRaw) ?? .s90 }
        set { selectedOverlaySizeRaw = newValue.rawValue }
    }

    /// Computed property for type-safe overlay position mode access.
    var overlayPositionMode: OverlayPositionMode {
        get {
            if hasCustomOverlayPosition {
                return .custom
            }
            return OverlayPositionMode(rawValue: overlayPositionModeRaw) ?? .screenBottom
        }
        set {
            overlayPositionModeRaw = newValue.rawValue
            if newValue == .custom {
                if !hasCustomOverlayPosition {
                    if let currentOrigin = settingsPreviewPanel?.frame.origin ?? recordingPanel?.frame.origin, currentOrigin != .zero {
                        customOverlayOriginX = Double(currentOrigin.x)
                        customOverlayOriginY = Double(currentOrigin.y)
                    } else if let screen = NSScreen.main ?? NSScreen.screens.first {
                        let screenFrame = screen.visibleFrame
                        let w = settingsPreviewPanel?.frame.width ?? recordingPanel?.frame.width ?? 220
                        customOverlayOriginX = Double(screenFrame.midX - w / 2)
                        customOverlayOriginY = Double(screenFrame.minY + 80)
                    }
                    hasCustomOverlayPosition = true
                }
                let saved = NSPoint(x: customOverlayOriginX, y: customOverlayOriginY)
                recordingPanel?.customUserOrigin = saved
                settingsPreviewPanel?.customUserOrigin = saved
            } else {
                hasCustomOverlayPosition = false
                recordingPanel?.customUserOrigin = nil
                settingsPreviewPanel?.customUserOrigin = nil
            }
            showSettingsPreviewFor5Seconds()
        }
    }

    func saveCustomOverlayOrigin(_ origin: NSPoint) {
        customOverlayOriginX = Double(origin.x)
        customOverlayOriginY = Double(origin.y)
        if !hasCustomOverlayPosition {
            hasCustomOverlayPosition = true
        }
        if overlayPositionModeRaw != OverlayPositionMode.custom.rawValue {
            overlayPositionModeRaw = OverlayPositionMode.custom.rawValue
        }
        recordingPanel?.customUserOrigin = origin
        settingsPreviewPanel?.customUserOrigin = origin

        if settingsPreviewPanel != nil {
            previewDismissTimer?.invalidate()
            previewDismissTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.hideSettingsPreviewPanel()
                }
            }
        }
    }

    /// Compensation multiplier for text/timers when the overlay panel is scaled down.
    var overlayTextCompensation: CGFloat {
        let scale = selectedOverlaySize.scale
        return 1.0 + (1.0 - scale) * 0.75
    }

    /// Computed property for type-safe overlay appearance access.
    var selectedOverlayAppearance: PanelAppearance {
        get { PanelAppearance(rawValue: selectedOverlayAppearanceRaw) ?? .liquidGlass }
        set {
            selectedOverlayAppearanceRaw = newValue.rawValue
            showSettingsPreviewFor5Seconds()
        }
    }

    /// Computed property for type-safe panel appearance access.
    var selectedPanelAppearance: PanelAppearance {
        get { PanelAppearance(rawValue: selectedPanelAppearanceRaw) ?? .liquidGlass }
        set {
            selectedPanelAppearanceRaw = newValue.rawValue
            SettingsWindowManager.shared.updateAppearance(newValue)
        }
    }

    /// Computed property for type-safe subtitle background access.
    var livePreviewBackground: SubtitleBackground {
        get { SubtitleBackground(rawValue: livePreviewBackgroundRaw) ?? .glass }
        set { livePreviewBackgroundRaw = newValue.rawValue }
    }

    @AppStorage("livePreviewMode") var livePreviewModeRaw: String = LivePreviewMode.external.rawValue

    /// Computed property for type-safe live preview mode access.
    var livePreviewMode: LivePreviewMode {
        get {
            return LivePreviewMode(rawValue: livePreviewModeRaw) ?? .external
        }
        set {
            livePreviewModeRaw = newValue.rawValue
        }
    }

    /// Whether embedded live preview is active (inside the overlay card).
    public var isEmbeddedPreviewActive: Bool {
        return livePreviewEnabled && (isShowingPreview || !livePreviewText.isEmpty)
    }

    @AppStorage("selectedPasteMode") var selectedPasteModeRaw: String = PasteMode.directType.rawValue

    /// Computed property for type-safe paste mode access (always Direct Typing).
    var selectedPasteMode: PasteMode {
        get { .directType }
        set { selectedPasteModeRaw = PasteMode.directType.rawValue }
    }

    // MARK: Services

    let audioRecorder       = AudioRecorder()
    let transcriptionService = TranscriptionService()

    // MARK: Private

    private var recordingPanel: RecordingPanel?
    private var subtitlePanel: NSPanel?
    private var panelHideGeneration: Int = 0
    private var cancellables   = Set<AnyCancellable>()
    private var escMonitor: Any?
    private var localEscMonitor: Any?
    private var durationTimer: Timer?
    private var periodicSyncTimer: Timer?
    private var audioStartTask: Task<Void, Never>?

    // MARK: Init

    init() {
        AppState.shared = self
        logger.info("AppState init")
        selectedPasteModeRaw = PasteMode.directType.rawValue
        setupHotkeyHandler()
        setupEscHandler()
        setupLivePreviewResizing()
        setupPeriodicAutoSync()
        preloadModel()
        PermissionWindowManager.shared.restoreCrashBackupIfPresent(appState: self)
        checkFirstLaunchPermissions()
        loadGatewayKeys()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.prewarmOverlayPanelsIfNeeded()
        }
        
        // Record anonymous installation & active user telemetry
        TelemetryService.shared.recordAppLaunch()
        
        // Auto-migrate deprecated Cerebras & Groq models
        if cerebrasModel.contains("llama") || cerebrasModel.isEmpty {
            cerebrasModel = "gpt-oss-120b"
        }
        if groqModel.contains("llama") || groqModel.contains("qwen-2.5") || groqModel.contains("gpt-oss-120b") || groqModel.isEmpty {
            groqModel = "qwen/qwen3.8-27b"
        }
        
        // Remove old pre-seeded location presets if present
        if customLocationPresets.contains(where: { 
            $0.shareCode == "scr_loc_cis_capitals" || 
            $0.shareCode == "scr_loc_europe_hubs" || 
            $0.shareCode == "scr_loc_usa_cities" || 
            $0.shareCode == "scr_loc_uae_middle_east" || 
            $0.shareCode == "scr_loc_countries_world" 
        }) {
            customLocationPresets.removeAll { 
                $0.shareCode == "scr_loc_cis_capitals" || 
                $0.shareCode == "scr_loc_europe_hubs" || 
                $0.shareCode == "scr_loc_usa_cities" || 
                $0.shareCode == "scr_loc_uae_middle_east" || 
                $0.shareCode == "scr_loc_countries_world" 
            }
        }
        
        // Seed default vocabulary presets (IDE & Vibe Coding, AI Assistants & LLMs) if not present
        for preset in Self.defaultVocabularyPresets {
            if !customVocabularyPresets.contains(where: { $0.shareCode == preset.shareCode || $0.name == preset.name }) {
                customVocabularyPresets.append(preset)
            }
        }

        // Normalize stored user vocabulary to plain letters (e.g., Dom Pérignon -> Dom Perignon)
        let sanitizedVocab = self.vocabulary
            .components(separatedBy: CharacterSet(charactersIn: ",\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).normalizedPlainVocabularyWord() }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
        if sanitizedVocab != self.vocabulary {
            self.vocabulary = sanitizedVocab
        }

        // Normalize words across custom vocabulary presets if needed
        var presetsUpdated = false
        var normalizedPresets: [VocabularyPreset] = []
        for preset in customVocabularyPresets {
            let normalizedWords = preset.words.map { $0.normalizedPlainVocabularyWord() }
            if normalizedWords != preset.words {
                presetsUpdated = true
                var updated = preset
                updated.words = normalizedWords
                normalizedPresets.append(updated)
            } else {
                normalizedPresets.append(preset)
            }
        }
        if presetsUpdated {
            customVocabularyPresets = normalizedPresets
        }

        // Sync local active words into community dictionary
        CommunityVocabularyService.shared.syncLocalWordsToDictionary(rawVocabulary: self.vocabulary)
        
        if CommandLine.arguments.contains("--settings") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                SettingsWindowManager.shared.showSettings(appState: self)
            }
        }
        
        if CommandLine.arguments.contains("--test-onboarding") || UserDefaults.standard.bool(forKey: "launchTestOnboardingOnce") {
            UserDefaults.standard.removeObject(forKey: "launchTestOnboardingOnce")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                PermissionWindowManager.shared.showWindow(appState: self, isTestRun: true)
            }
        } else if CommandLine.arguments.contains("--permissions") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                PermissionWindowManager.shared.showWindow(appState: self)
            }
        }
    }

    // MARK: - 5-Minute Background Periodic Sync
    private func setupPeriodicAutoSync() {
        periodicSyncTimer?.invalidate()
        
        // Immediate launch sync
        Task.detached(priority: .background) {
            await CommunityVocabularyService.shared.performBiDirectionalSync()
            await MainActor.run {
                if AuthService.shared.currentUser != nil {
                    AuthService.shared.syncRecords(TranscriptionHistory.shared.records)
                    AuthService.shared.syncSupporterStatusFromCloud()
                    AuthService.shared.syncDeviceStatsFromCloud()
                }
            }
        }
        
        // 5-minute recurring timer (300 seconds)
        let timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task.detached(priority: .background) {
                await CommunityVocabularyService.shared.performBiDirectionalSync()
                await MainActor.run {
                    if AuthService.shared.currentUser != nil {
                        AuthService.shared.syncRecords(TranscriptionHistory.shared.records)
                        AuthService.shared.syncSupporterStatusFromCloud()
                        AuthService.shared.syncDeviceStatsFromCloud()
                    }
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.periodicSyncTimer = timer
    }

    // MARK: - Onboarding
    @AppStorage("hasCompletedFirstLaunchSetup") private var hasCompletedFirstLaunchSetup: Bool = false
    @AppStorage("userName") public var userName: String = ""

    private func checkFirstLaunchPermissions() {
        if CommandLine.arguments.contains("--test-onboarding") || UserDefaults.standard.bool(forKey: "launchTestOnboardingOnce") {
            return
        }
        let namePromptDone = UserDefaults.standard.bool(forKey: "hasCompletedOnboardingNamePrompt")
        let mic = PermissionManager.shared.isMicrophoneGranted
        let ax = PasteService.isAccessibilityGranted()
        
        if !hasCompletedFirstLaunchSetup || !namePromptDone || userName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                PermissionWindowManager.shared.showWindow(appState: self)
            }
        }
        
        // Pre-request Apple Notes automation permission so macOS asks up-front rather than during a lecture export
        if (lectureTargetAppleNotes || enableAppleNotes) && !UserDefaults.standard.bool(forKey: "hasPromptedAppleNotesPermission") {
            UserDefaults.standard.set(true, forKey: "hasPromptedAppleNotesPermission")
            PermissionManager.shared.requestAppleNotes()
        }
    }

    // MARK: - Public API

    /// Toggle between recording and idle. Ignored while a transcription is in flight.
    func toggleRecording() {
        guard !isTranscribing else {
            logger.warning("toggleRecording ignored — transcription in progress")
            return
        }

        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    /// Starts a long lecture recording session: no intrusive on-screen overlay, toolbar indication, auto-exports to new note.
    public func startLectureRecording() {
        guard !isRecording, !isTranscribing else { return }
        if lectureTargetAppleNotes && !PermissionManager.shared.isAppleNotesGranted {
            PermissionManager.shared.requestAppleNotes()
        }
        isLectureRecording = true
        startRecording()
    }

    /// Stops lecture recording session.
    public func stopLectureRecording() {
        guard isRecording else { return }
        stopRecording()
    }

    /// Cancel the current recording without transcribing — just stop and close.
    func cancelRecording() {
        if isShowingPreview {
            hideSettingsPreviewPanel()
            return
        }
        guard isRecording else { return }
        audioStartTask?.cancel()
        audioStartTask = nil
        isLectureRecording = false
        stopDurationTimer()
        stopInterimWhisperGeneration()
        audioRecorder.enableLiveBuffer = false
        audioRecorder.purgeMemory()
        if livePreviewEnabled { stopLiveStreaming() }
        livePreviewText = ""
        liveStreamLastInsertedText = ""
        let audioURL = audioRecorder.stopRecording()
        isRecording = false
        isTranscribing = false
        recordingStatus = .idle
        hidePanel()
        logger.info("Recording cancelled by user")
        // Clean up temp file
        if let url = audioURL {
            try? FileManager.default.removeItem(at: url)
        }
    }

    // MARK: - Private — Recording Flow

    private func startRecording() {
        hideSettingsPreviewPanel()
        captureTargetApplication()
        isRecording     = true
        recordingStatus = .recording
        recordingDuration = 0
        livePreviewText = ""
        latestWhisperTranscription = ""
        if !isLectureRecording {
            showPanel()
        }
        if soundFeedbackEnabled { SoundFeedback.play(.recordingStarted) }
        startDurationTimer()

        audioStartTask?.cancel()
        audioStartTask = Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }
            do {
                await MainActor.run {
                    self.audioRecorder.enableLiveBuffer = !self.isLectureRecording && self.livePreviewEnabled && !self.isInstantEngine
                    self.audioRecorder.purgeMemory()
                }

                try self.audioRecorder.startRecording()

                await MainActor.run {
                    guard self.isRecording else {
                        _ = self.audioRecorder.stopRecording()
                        return
                    }
                    if !self.isLectureRecording && self.livePreviewEnabled {
                        if self.isInstantEngine {
                            self.startLiveStreaming()
                        } else {
                            self.startInterimWhisperGeneration()
                        }
                    }
                }

                // Pre-warm Whisper neural engine and CoreML compute graph during recording (neural engine only)
                if await !self.isInstantEngine {
                    Task.detached(priority: .utility) { [weak self] in
                        guard let self = self else { return }
                        let model = await self.effectiveModel
                        try? await self.transcriptionService.ensureModelLoaded(modelName: model)
                    }
                }

                logger.info("Audio recording hardware started successfully")
            } catch {
                await MainActor.run {
                    self.isRecording = false
                    self.isLectureRecording = false
                    self.recordingStatus = .error("Mic error")
                    self.hidePanel()
                    if self.soundFeedbackEnabled { SoundFeedback.play(.error) }
                }
                logger.error("Failed to start audio recording: \(error.localizedDescription)")
            }
        }
    }

    private func stopRecording() {
        stopDurationTimer()
        interimWhisperTimer?.invalidate()
        interimWhisperTimer = nil
        audioRecorder.enableLiveBuffer = false
        isRecording = false
        isTranscribing = true
        recordingStatus = .transcribing
        self.audioRecorder.audioLevel = 0

        let soundFeedback = self.soundFeedbackEnabled
        let livePreview = self.livePreviewEnabled
        let startTask = self.audioStartTask
        self.audioStartTask = nil

        Task {
            await self.performStopRecording(
                soundFeedback: soundFeedback,
                livePreview: livePreview,
                startTask: startTask
            )
        }
    }

    private func makeLivePreviewProgressHandler(
        enabled: Bool,
        preferredLangs: [String],
        effectiveVocab: String,
        effectiveBlocked: String
    ) -> (@Sendable (String) -> Void)? {
        guard enabled else { return nil }
        return { [weak self] (progressRaw: String) in
            guard let self else { return }
            Task { @MainActor in
                self.applyLivePreviewUpdate(
                    rawText: progressRaw,
                    preferredLangs: preferredLangs,
                    effectiveVocab: effectiveVocab,
                    effectiveBlocked: effectiveBlocked,
                    allowShrink: false
                )
            }
        }
    }

    private func performStopRecording(
        soundFeedback: Bool,
        livePreview: Bool,
        startTask: Task<Void, Never>?
    ) async {
        // Await start task to ensure CoreAudio file has been initialized
        _ = await startTask?.value

        // Keep recording ~80ms after hotkey release: captures trailing syllable cleanly without noticeable delay
        try? await Task.sleep(for: .milliseconds(80))

        if livePreview { self.stopLiveStreaming() }
        // Keep livePreviewText intact so preview panel displays intermediate/final recognized words smoothly
        if soundFeedback { SoundFeedback.play(.recordingStopped) }

        let audioURL = self.audioRecorder.stopRecording()
        logger.info("Recording stopped with trailing tail buffer, audioURL=\(audioURL?.path ?? "nil")")

        guard let audioURL else {
            logger.warning("No audio URL returned")
            self.stopInterimWhisperGeneration()
            self.livePreviewText = ""
            self.isLectureRecording = false
            self.isTranscribing = false
            self.recordingStatus = .error("No speech")
            try? await Task.sleep(for: .milliseconds(1200))
            guard !self.isRecording else { return }
            self.hidePanel()
            return
        }

        // Check file exists and has content
        if let attrs = try? FileManager.default.attributesOfItem(atPath: audioURL.path),
           let size = attrs[.size] as? UInt64 {
            logger.info("Audio file size: \(size) bytes")
            if size < 1000 {
                logger.warning("Audio file very small (\(size) bytes), might be too short")
            }
        }

        do {
            let isSingle = self.recognitionMode == "singleLanguage"
            let langParam: String? = isSingle ? (self.singleDictationLanguage == "auto" ? nil : self.singleDictationLanguage) : nil
            let preferredLangs: [String] = isSingle ?
                (self.singleDictationLanguage == "auto" ? (self.multilingualLanguages.isEmpty ? ["ru", "en"] : self.multilingualLanguages) : [self.singleDictationLanguage]) :
                (self.multilingualLanguages.isEmpty ? ["ru", "en"] : self.multilingualLanguages)

            let effectiveBlocked = AetherContextEngine.shared.activeEffectiveBlockedWords(
                targetApp: self.targetRunningApplication,
                userBlockedWords: self.blockedWords,
                recognitionLanguages: isSingle ? [self.singleDictationLanguage] : preferredLangs
            )
            let effectiveVocab = AetherContextEngine.shared.activeEffectiveVocabulary(
                targetApp: self.targetRunningApplication,
                userVocabulary: self.vocabulary,
                userLocation: self.effectiveUserLocation
            )

            logger.info("Starting transcription with model=\(self.effectiveModel), mode=\(self.recognitionMode), lang=\(langParam ?? "auto"), preferred=\(preferredLangs)…")

            let progressHandler = self.makeLivePreviewProgressHandler(
                enabled: livePreview,
                preferredLangs: preferredLangs,
                effectiveVocab: effectiveVocab,
                effectiveBlocked: effectiveBlocked
            )

            var text = try await transcriptionService.transcribe(
                audioURL: audioURL,
                modelName: self.effectiveModel,
                language: self.isInstantEngine ? "en" : langParam,
                preferredLanguages: self.isInstantEngine ? ["en"] : preferredLangs,
                autoTranslate: self.isInstantEngine ? false : self.autoTranslate,
                customVocabulary: self.vocabulary,
                userLocation: self.effectiveUserLocation,
                targetApp: self.targetRunningApplication,
                recognitionEngine: self.recognitionEngine,
                onProgressText: progressHandler
            )
            self.stopInterimWhisperGeneration()

                // Fast exit if no speech was detected, or recover if final decode truncated a prefix/suffix that interim preview already captured
                let trimmedFinal = text.trimmingCharacters(in: .whitespacesAndNewlines)
                let trimmedInterim = self.latestWhisperTranscription.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmedFinal.isEmpty {
                    if !trimmedInterim.isEmpty {
                        text = trimmedInterim
                        logger.info("Using interim Whisper live preview text as final transcription: '\(text)'")
                    } else {
                        logger.info("Transcription returned empty text (no speech detected)")
                        self.livePreviewText = ""
                        self.recordingStatus = .error("No speech")
                        self.isLectureRecording = false
                        self.isTranscribing = false
                        self.audioRecorder.purgeMemory()
                        try? FileManager.default.removeItem(at: audioURL)
                        try? await Task.sleep(for: .milliseconds(1200))
                        guard !self.isRecording else { return }
                        self.hidePanel()
                        return
                    }
                } else if !trimmedInterim.isEmpty {
                    let cleanFinal = trimmedFinal.trimmingCharacters(in: .punctuationCharacters.union(.whitespacesAndNewlines)).lowercased()
                    let cleanInterim = trimmedInterim.trimmingCharacters(in: .punctuationCharacters.union(.whitespacesAndNewlines)).lowercased()
                    if cleanFinal.count >= 4 && cleanInterim.count >= cleanFinal.count + 4 &&
                        (cleanInterim.hasPrefix(cleanFinal) || cleanInterim.hasSuffix(cleanFinal)) {
                        logger.info("Final transcription ('\(trimmedFinal)') was a truncated substring of interim preview ('\(trimmedInterim)'); recovering full interim text.")
                        text = trimmedInterim
                    }
                }

                if livePreview && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    self.applyLivePreviewUpdate(
                        rawText: text,
                        preferredLangs: preferredLangs,
                        effectiveVocab: effectiveVocab,
                        effectiveBlocked: effectiveBlocked,
                        allowShrink: true
                    )
                }

                // AI Refinement with Cloud / LLM Provider & Gateway Failover
                if self.enableCloudAI {
                    let key = self.activeCloudAPIKey
                    let provider = self.cloudAIProvider
                    let hasGateway = !self.gatewayKeys.filter { $0.isEnabled && !$0.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.isEmpty
                    if hasGateway || provider == .ollama || !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        do {
                            let activeRefinementLangs = preferredLangs.filter { $0 != "auto" }
                            let refined = try await CloudAIService.shared.refineWithGateway(
                                text: text,
                                mode: self.selectedAIRefinementMode,
                                gatewayKeys: self.gatewayKeys,
                                fallbackProvider: provider,
                                fallbackKey: key,
                                vocabulary: effectiveVocab,
                                allowedLanguages: activeRefinementLangs.isEmpty ? ["ru", "en"] : activeRefinementLangs,
                                isLecture: self.isLectureRecording,
                                customBaseURL: self.customOpenAIBaseURL,
                                customModel: self.customOpenAIModel,
                                geminiModel: self.geminiModel,
                                groqModel: self.groqModel,
                                cerebrasModel: self.cerebrasModel,
                                ollamaEndpoint: self.ollamaEndpoint,
                                ollamaModel: self.ollamaModel
                            )
                            let cleanedRefined = refined.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !cleanedRefined.isEmpty {
                                text = cleanedRefined
                            }
                            await MainActor.run {
                                self.lastAIErrorMessage = nil
                            }
                        } catch {
                            logger.error("AI refinement failed: \(error.localizedDescription)")
                            await MainActor.run {
                                self.lastAIErrorMessage = error.localizedDescription
                            }
                        }
                    } else {
                        let errMsg = "AI Gateway: No active API keys configured"
                        logger.warning("\(errMsg)")
                        await MainActor.run {
                            self.lastAIErrorMessage = errMsg
                        }
                    }
                }

                // 1. Scribe Dictation Mode Transformation (Clean, Code, Raw, Chat, Formal)
                text = ScribeModeProcessor.shared.process(text: text, mode: self.transcriptionMode)

                // 2. Custom Replacements, Canonical Vocabulary & Anti-Hallucination Filtering
                text = TextReplacer.apply(
                    replacements: self.textReplacements,
                    vocabulary: effectiveVocab,
                    blockedWords: effectiveBlocked,
                    blockedAction: self.blockedWordsActionRaw,
                    to: text
                )

                // Smart Casing: Lowercase first letter if continuing an active sentence
                text = PasteService.adjustCasingForContext(text: text)

                logger.info("Transcription result: '\(text)'")
                self.livePreviewText = text

                if text.isEmpty {
                    logger.warning("Transcription returned empty text")
                    self.livePreviewText = ""
                    recordingStatus = .error("No speech")
                    self.isLectureRecording = false
                    self.isTranscribing = false
                    try? await Task.sleep(for: .milliseconds(1200))
                    guard !self.isRecording else { return }
                    hidePanel()
                    return
                } else if TranscriptionService.isVoiceCancelCommand(text) {
                    logger.info("Voice cancel command detected: '\(text)'")
                    recordingStatus = .error("Cancelled")
                    self.isLectureRecording = false
                    if self.soundFeedbackEnabled { SoundFeedback.play(.error) }
                    try? await Task.sleep(for: .seconds(1.2))
                    hidePanel()
                } else {
                    // Capture snapshot of previous clipboard if preserveClipboard is enabled
                    let previousClipboard = self.preserveClipboard ? PasteService.captureClipboard() : nil

                    // Save to history
                    let record = TranscriptionRecord(
                        text: text,
                        duration: self.recordingDuration,
                        language: self.selectedLanguage,
                        model: self.effectiveModel
                    )
                    TranscriptionHistory.shared.add(record)

                    if self.isLectureRecording {
                        let duration = self.recordingDuration
                        self.isLectureRecording = false
                        logger.info("Lecture recording completed. Exporting directly to new note…")

                        // Export to notes as a fresh lecture note
                        await NoteExporter.exportLectureNote(
                            duration: duration,
                            transcript: text,
                            state: self
                        )

                        // Copy to clipboard silently
                        PasteService.copyToClipboard(text, transient: false)

                        recordingStatus = .done
                        if self.soundFeedbackEnabled { SoundFeedback.play(.transcriptionDone) }
                        self.sendLectureNotification(
                            title: "Scribe • Запись лекции завершена",
                            body: "Транскрибация успешно сохранена в новую заметку."
                        )
                        try? await Task.sleep(for: .seconds(0.6))
                        recordingStatus = .idle
                    } else {
                        // Export to notes (Apple Notes, Obsidian, Notion)
                        NoteExporter.export(text: text, state: self)

                        let isNotesOnly = self.isDirectNoteRecording

                        recordingStatus = .done
                        if self.soundFeedbackEnabled { SoundFeedback.play(.transcriptionDone) }

                        if isNotesOnly {
                            logger.info("Integrations-only mode active: Skipping active window paste.")
                        } else if self.selectedPasteMode == .directType {
                            logger.info("Direct typing mode: Typing text directly without touching clipboard…")
                            try? await Task.sleep(for: .milliseconds(40))
                            PasteService.typeText(text)
                        } else {
                            // Populate clipboard
                            switch self.selectedPasteMode {
                            case .paste:  PasteService.copyToClipboard(text, transient: self.preserveClipboard)
                            case .append: PasteService.appendToClipboard(text)
                            case .directType, .integrationsOnly: break
                            }

                            logger.info("Text copied to clipboard, simulating paste…")
                            // Brief delay so the user sees the checkmark, then paste
                            try? await Task.sleep(for: .milliseconds(60))
                            PasteService.simulatePaste()

                            // If preserving clipboard, restore original user content after target app consumes paste
                            if let snapshot = previousClipboard {
                                try? await Task.sleep(for: .milliseconds(120))
                                snapshot.restore()
                                logger.info("Previous clipboard contents restored")
                            }
                        }

                        try? await Task.sleep(for: .milliseconds(350))
                        hidePanel()
                    }
                }
            } catch {
                self.stopInterimWhisperGeneration()
                self.isLectureRecording = false
                recordingStatus = .error("Error")
                if self.soundFeedbackEnabled { SoundFeedback.play(.error) }
                logger.error("Transcription failed: \(error.localizedDescription)")
                try? await Task.sleep(for: .seconds(2))
                hidePanel()
            }

            isTranscribing = false

            // Securely wipe audio RAM buffers and clean up temp file
            self.audioRecorder.purgeMemory()
            try? FileManager.default.removeItem(at: audioURL)
    }

    // MARK: - Lecture Notifications & File Import

    public func sendLectureNotification(title: String, body: String) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            center.add(request)
        }
    }

    /// Imports an audio/video file, transcribes it in the background, and exports directly to a new note in Apple Notes.
    public func importAndTranscribeLecture(url: URL) {
        guard !isImportTranscribing else { return }
        if lectureTargetAppleNotes && !PermissionManager.shared.isAppleNotesGranted {
            PermissionManager.shared.requestAppleNotes()
        }
        isImportTranscribing = true
        importProgressMessage = "Подготовка файла…"

        Task {
            do {
                let preparedURL = try await AudioFileImporter.prepareAudio(from: url)
                defer {
                    if preparedURL != url {
                        try? FileManager.default.removeItem(at: preparedURL)
                    }
                }

                await MainActor.run {
                    self.importProgressMessage = "Транскрибация лекции через Whisper…"
                }

                let isSingle = self.recognitionMode == "singleLanguage"
                let langParam: String? = isSingle ? (self.singleDictationLanguage == "auto" ? nil : self.singleDictationLanguage) : nil
                let preferredLangs: [String] = isSingle ?
                    (self.singleDictationLanguage == "auto" ? (self.multilingualLanguages.isEmpty ? ["ru", "en"] : self.multilingualLanguages) : [self.singleDictationLanguage]) :
                    (self.multilingualLanguages.isEmpty ? ["ru", "en"] : self.multilingualLanguages)

                var text = try await self.transcriptionService.transcribe(
                    audioURL: preparedURL,
                    modelName: self.effectiveModel,
                    language: langParam,
                    preferredLanguages: preferredLangs,
                    autoTranslate: self.autoTranslate,
                    customVocabulary: self.vocabulary,
                    userLocation: self.effectiveUserLocation,
                    targetApp: nil,
                    recognitionEngine: self.recognitionEngine
                )

                text = text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else {
                    await MainActor.run {
                        self.importProgressMessage = "Речь не обнаружена в файле"
                    }
                    try? await Task.sleep(for: .seconds(2))
                    await MainActor.run {
                        self.isImportTranscribing = false
                        self.importProgressMessage = ""
                    }
                    return
                }

                let effectiveVocab = AetherContextEngine.shared.activeEffectiveVocabulary(
                    targetApp: nil,
                    userVocabulary: self.vocabulary,
                    userLocation: self.effectiveUserLocation
                )

                // AI Refinement with Cloud / LLM Provider & Gateway Failover
                if self.enableCloudAI {
                    let key = self.activeCloudAPIKey
                    let provider = self.cloudAIProvider
                    let hasGateway = !self.gatewayKeys.filter { $0.isEnabled && !$0.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.isEmpty
                    if hasGateway || provider == .ollama || !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        do {
                            let activeRefinementLangs = preferredLangs.filter { $0 != "auto" }
                            let refined = try await CloudAIService.shared.refineWithGateway(
                                text: text,
                                mode: self.selectedAIRefinementMode,
                                gatewayKeys: self.gatewayKeys,
                                fallbackProvider: provider,
                                fallbackKey: key,
                                vocabulary: effectiveVocab,
                                allowedLanguages: activeRefinementLangs.isEmpty ? ["ru", "en"] : activeRefinementLangs,
                                customBaseURL: self.customOpenAIBaseURL,
                                customModel: self.customOpenAIModel,
                                geminiModel: self.geminiModel,
                                groqModel: self.groqModel,
                                cerebrasModel: self.cerebrasModel,
                                ollamaEndpoint: self.ollamaEndpoint,
                                ollamaModel: self.ollamaModel
                            )
                            let cleanedRefined = refined.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !cleanedRefined.isEmpty {
                                text = cleanedRefined
                            }
                            await MainActor.run {
                                self.lastAIErrorMessage = nil
                            }
                        } catch {
                            logger.error("AI refinement failed for imported file: \(error.localizedDescription)")
                            await MainActor.run {
                                self.lastAIErrorMessage = error.localizedDescription
                            }
                        }
                    } else {
                        let errMsg = "AI Gateway: No active API keys configured"
                        logger.warning("\(errMsg)")
                        await MainActor.run {
                            self.lastAIErrorMessage = errMsg
                        }
                    }
                }

                // 1. Scribe Mode formatting
                text = ScribeModeProcessor.shared.process(text: text, mode: self.transcriptionMode)

                // 2. Replacements and vocabulary
                text = TextReplacer.apply(
                    replacements: self.textReplacements,
                    vocabulary: effectiveVocab,
                    blockedWords: self.blockedWords,
                    blockedAction: self.blockedWordsActionRaw,
                    to: text
                )

                // 3. Save to History
                let filename = url.deletingPathExtension().lastPathComponent
                let record = TranscriptionRecord(
                    text: text,
                    duration: 0,
                    language: self.selectedLanguage,
                    model: self.effectiveModel
                )
                TranscriptionHistory.shared.add(record)

                // 4. Export to Apple Notes
                await NoteExporter.exportLectureNote(
                    title: filename,
                    duration: nil,
                    transcript: text,
                    sourceFilename: filename,
                    state: self
                )

                // 5. Copy to clipboard
                PasteService.copyToClipboard(text, transient: false)

                if self.soundFeedbackEnabled { SoundFeedback.play(.transcriptionDone) }

                await MainActor.run {
                    self.importProgressMessage = "Готово! Сохранено в Заметки"
                    self.sendLectureNotification(
                        title: "Scribe • Файл расшифрован",
                        body: "«\(filename)» успешно сохранена в Заметки."
                    )
                }
                try? await Task.sleep(for: .seconds(2.5))
                await MainActor.run {
                    self.isImportTranscribing = false
                    self.importProgressMessage = ""
                }
            } catch {
                logger.error("Lecture import error: \(error.localizedDescription)")
                await MainActor.run {
                    self.importProgressMessage = "Ошибка: \(error.localizedDescription)"
                }
                try? await Task.sleep(for: .seconds(3))
                await MainActor.run {
                    self.isImportTranscribing = false
                    self.importProgressMessage = ""
                }
            }
        }
    }

    // MARK: - Panel Management

    private func prewarmOverlayPanelsIfNeeded() {
        if recordingPanel == nil {
            let overlay = RecordingOverlayView()
                .environmentObject(self)
                .environmentObject(audioRecorder)
            let isEmbedded = false
            let hasAI = false
            let activeAppName = showTargetAppInOverlay ? targetAppName : ""
            let isTimerVis = durationVisible
            let panel = RecordingPanel.make(
                style: selectedOverlayStyle,
                appearance: selectedOverlayAppearance,
                size: selectedOverlaySize,
                isEmbeddedPreviewActive: isEmbedded,
                previewTextLength: 0,
                targetAppName: activeAppName,
                isTimerVisible: isTimerVis,
                hasAIMode: hasAI
            )
            panel.setContent(
                overlay,
                style: selectedOverlayStyle,
                overlaySize: selectedOverlaySize,
                isEmbeddedPreviewActive: isEmbedded,
                previewTextLength: 0,
                targetAppName: activeAppName,
                isTimerVisible: isTimerVis,
                hasAIMode: hasAI
            )
            panel.alphaValue = 0
            if hasCustomOverlayPosition {
                panel.customUserOrigin = NSPoint(x: customOverlayOriginX, y: customOverlayOriginY)
            }
            panel.onUserDragged = { [weak self, weak panel] newOrigin in
                guard let self = self, let panel = panel else { return }
                self.saveCustomOverlayOrigin(newOrigin)
                if let sub = self.subtitlePanel {
                    self.updateSubtitlePanelFrame(for: panel, subPanel: sub)
                }
            }
            recordingPanel = panel
        }

        if subtitlePanel == nil {
            let subPanel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 800, height: 100),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            subPanel.isFloatingPanel = true
            subPanel.level = .floating
            subPanel.backgroundColor = .clear
            subPanel.isOpaque = false
            subPanel.hasShadow = false
            subPanel.ignoresMouseEvents = true

            let subView = SubtitleOverlayView().environmentObject(self)
            let host = NSHostingView(rootView: subView)
            host.layer?.backgroundColor = .clear
            subPanel.contentView = host
            subPanel.alphaValue = 0
            subtitlePanel = subPanel
        }
    }

    private func showPanel() {
        panelHideGeneration &+= 1
        prewarmOverlayPanelsIfNeeded()

        guard let panel = recordingPanel, let subPanel = subtitlePanel else { return }

        let overlay = RecordingOverlayView()
            .environmentObject(self)
            .environmentObject(audioRecorder)

        let isEmbedded = false
        let hasAI = false
        let activeAppName = showTargetAppInOverlay ? targetAppName : ""
        let isTimerVis = durationVisible

        panel.updateAppearance(selectedOverlayAppearance)
        panel.setContent(
            overlay,
            style: selectedOverlayStyle,
            overlaySize: selectedOverlaySize,
            isEmbeddedPreviewActive: isEmbedded,
            previewTextLength: livePreviewText.count,
            targetAppName: activeAppName,
            isTimerVisible: isTimerVis,
            hasAIMode: hasAI
        )

        if hasCustomOverlayPosition {
            panel.customUserOrigin = NSPoint(x: customOverlayOriginX, y: customOverlayOriginY)
        } else {
            panel.customUserOrigin = nil
        }
        panel.positionPanel(mode: overlayPositionMode, targetApp: targetRunningApplication)
        panel.alphaValue = 1
        panel.orderFrontRegardless()

        updateSubtitlePanelFrame(for: panel, subPanel: subPanel)
        subPanel.alphaValue = 1
        if subPanel.parent == nil {
            panel.addChildWindow(subPanel, ordered: .above)
        }
        subPanel.orderFrontRegardless()
    }

    func updateSubtitlePanelFrame(for mainPanel: NSPanel, subPanel: NSPanel) {
        let screen = mainPanel.screen ?? NSScreen.main ?? NSScreen.screens.first
        let screenFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)

        // Use a fixed transparent canvas height (up to 4 lines) so subPanel never calls setFrame
        // or shifts mainPanel mid-sentence when livePreviewText wraps onto a new line.
        let subHeight: CGFloat = livePreviewEnabled ? 132 : 54
        let baseSubWidth = max(mainPanel.frame.width + 120, 700)
        let subWidth: CGFloat = min(baseSubWidth, screenFrame.width - 48)

        let frame = mainPanel.frame
        let subX = frame.midX - subWidth / 2
        let isCustomPinned = hasCustomOverlayPosition || (mainPanel as? RecordingPanel)?.customUserOrigin != nil

        // Position the subtitle panel under mainPanel when room permits.
        // If user dragged mainPanel near the bottom edge of the screen, place subPanel above mainPanel instead of moving mainPanel!
        let rawSubY = frame.minY - subHeight - 10
        let subY: CGFloat
        if rawSubY < screenFrame.minY + 8 {
            if isCustomPinned {
                subY = min(screenFrame.maxY - subHeight - 4, frame.maxY + 10)
            } else {
                let neededShift = (screenFrame.minY + 8) - rawSubY
                let newMainY = min(screenFrame.maxY - mainPanel.frame.height - 8, mainPanel.frame.origin.y + neededShift)
                if abs(mainPanel.frame.origin.y - newMainY) > 1.0 {
                    mainPanel.setFrameOrigin(NSPoint(x: mainPanel.frame.origin.x, y: newMainY))
                }
                subY = max(screenFrame.minY + 4, mainPanel.frame.minY - subHeight - 10)
            }
        } else {
            subY = rawSubY
        }

        let finalRect = NSRect(
            x: max(screenFrame.minX + 16, min(subX, screenFrame.maxX - subWidth - 16)),
            y: max(screenFrame.minY + 4, min(subY, screenFrame.maxY - subHeight - 4)),
            width: subWidth,
            height: subHeight
        )
        if subPanel.frame != finalRect {
            subPanel.setFrame(finalRect, display: true)
        }
    }

    private func hidePanel() {
        panelHideGeneration &+= 1
        let expectedGen = panelHideGeneration
        let panel = recordingPanel
        let sub = subtitlePanel
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.18
            panel?.animator().alphaValue = 0
            sub?.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            DispatchQueue.main.async {
                guard let self = self, self.panelHideGeneration == expectedGen else { return }
                guard !self.isRecording && !self.isTranscribing else { return }
                if let sub = self.subtitlePanel {
                    self.recordingPanel?.removeChildWindow(sub)
                    sub.orderOut(nil)
                }
                self.recordingPanel?.orderOut(nil)
            }
        }
        recordingStatus = .idle
    }

    // MARK: - Live Preview Panel Resizing (during recording)

    /// Observe `livePreviewText` changes and dynamically update subtitle panel frames.
    private func setupLivePreviewResizing() {
        $livePreviewText
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                if let main = self.recordingPanel, let sub = self.subtitlePanel {
                    self.updateSubtitlePanelFrame(for: main, subPanel: sub)
                }
                if let main = self.settingsPreviewPanel, let sub = self.settingsSubtitlePanel {
                    self.updateSubtitlePanelFrame(for: main, subPanel: sub)
                }
            }
            .store(in: &cancellables)
    }

    /// Resize the live recording panel's NSWindow when embedded preview text changes.
    private func resizeRecordingPanelForEmbeddedPreview() {
        // Embedded preview was moved to dedicated floating subtitle panel
    }

    // MARK: - Floating Preview Panel for Settings (5-second auto-dismiss)

    private var settingsPreviewPanel: RecordingPanel?
    private var settingsSubtitlePanel: NSPanel?
    @Published public var isPreviewStageActive: Bool = false
    public var isFloatingPreviewActive: Bool { settingsPreviewPanel != nil }
    var isShowingPreview: Bool { settingsPreviewPanel != nil || isPreviewStageActive }
    private var settingsPreviewAnimTimer: Timer?
    private var previewDismissTimer: Timer?

    func showSettingsPreviewFor5Seconds(includeSubtitle: Bool = false) {
        guard !isRecording && !isTranscribing else { return }

        if includeSubtitle && livePreviewEnabled {
            livePreviewText = l("Scribe transcribes your speech live…")
        } else {
            livePreviewText = ""
        }

        updateSettingsPreviewPanel(includeSubtitle: includeSubtitle)

        if settingsPreviewAnimTimer == nil {
            settingsPreviewAnimTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
                DispatchQueue.main.async {
                    guard let self = self, !self.isRecording && !self.isTranscribing else { return }
                    let level = Float.random(in: 0.25...0.65)
                    withAnimation(.linear(duration: 0.08)) {
                        self.audioLevel = level
                    }
                }
            }
        }

        // Schedule auto-dismiss after 5 seconds
        previewDismissTimer?.invalidate()
        previewDismissTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.hideSettingsPreviewPanel()
            }
        }
    }

    func onThemeChangedPreview() {
        guard !isRecording && !isTranscribing else { return }
        showSettingsPreviewFor5Seconds()
    }

    private func activePreviewReferenceWindow() -> NSWindow? {
        if let permWin = PermissionWindowManager.shared.window, permWin.isVisible {
            return permWin
        }
        if let settingsWin = SettingsWindowManager.shared.window, settingsWin.isVisible {
            return settingsWin
        }
        return NSApp.keyWindow ?? PermissionWindowManager.shared.window ?? SettingsWindowManager.shared.window
    }

    private func targetPreviewOrigin(for style: OverlayStyle, size: NSSize, isDragging: Bool = false) -> NSPoint {
        let targetWin = activePreviewReferenceWindow()
        let screen = targetWin?.screen ?? NSScreen.main ?? NSScreen.screens.first
        guard let screen = screen else { return .zero }
        let screenFrame = screen.visibleFrame

        guard let windowFrame = targetWin?.frame else {
            let x = screenFrame.midX - size.width / 2
            let y = screenFrame.minY + 24
            return NSPoint(x: x, y: y)
        }

        let isNearlyFullScreen = windowFrame.width >= (screenFrame.width - 60) && windowFrame.height >= (screenFrame.height - 60)
        let isValidWindowFrame = windowFrame.intersects(screenFrame) && windowFrame.width >= 200

        if isNearlyFullScreen || !isValidWindowFrame {
            let x = screenFrame.midX - size.width / 2
            let y = screenFrame.minY + 24
            return NSPoint(x: x, y: y)
        }

        if style.isSquareStyle {
            // Square styles (.classic, .orb): display to the right or left of the window
            let gap: CGFloat = 18
            let rightX = windowFrame.maxX + gap
            let leftX = windowFrame.minX - size.width - gap
            let spaceRight = screenFrame.maxX - windowFrame.maxX
            let spaceLeft = windowFrame.minX - screenFrame.minX
            let fitsRight = (rightX + size.width) <= (screenFrame.maxX - 12)
            let fitsLeft = leftX >= (screenFrame.minX + 12)

            let targetX: CGFloat
            if fitsRight && (!fitsLeft || spaceRight >= spaceLeft) {
                targetX = rightX
            } else if fitsLeft {
                targetX = leftX
            } else if spaceRight >= spaceLeft {
                targetX = min(rightX, screenFrame.maxX - size.width - 12)
            } else {
                targetX = max(screenFrame.minX + 12, leftX)
            }

            let centeredY = windowFrame.midY - size.height / 2
            let clampedY = max(screenFrame.minY + 16, min(centeredY, screenFrame.maxY - size.height - 16))
            return NSPoint(x: targetX, y: clampedY)
        } else {
            // Horizontal styles (.waveform, .minimal, .ecg): display below or above the window
            let gap: CGFloat = 16
            let centeredX = windowFrame.midX - size.width / 2
            let clampedX = max(screenFrame.minX + 16, min(centeredX, screenFrame.maxX - size.width - 16))

            let belowY = windowFrame.minY - size.height - gap
            let aboveY = windowFrame.maxY + gap
            let spaceBelow = windowFrame.minY - screenFrame.minY
            let spaceAbove = screenFrame.maxY - windowFrame.maxY
            let fitsBelow = belowY >= (screenFrame.minY + 10)
            let fitsAbove = (aboveY + size.height) <= (screenFrame.maxY - 10)

            let targetY: CGFloat
            if fitsBelow && (!fitsAbove || spaceBelow >= spaceAbove) {
                targetY = belowY
            } else if fitsAbove {
                targetY = aboveY
            } else if spaceBelow >= spaceAbove {
                targetY = max(screenFrame.minY + 10, belowY)
            } else {
                targetY = min(screenFrame.maxY - size.height - 10, aboveY)
            }

            return NSPoint(x: clampedX, y: targetY)
        }
    }

    func moveSettingsPreviewPanelWithWindow() {
        guard let panel = settingsPreviewPanel, panel.isVisible else { return }
        if hasCustomOverlayPosition || panel.customUserOrigin != nil {
            if let subPanel = settingsSubtitlePanel {
                updateSubtitlePanelFrame(for: panel, subPanel: subPanel)
            }
            return
        }
        let targetOrigin = targetPreviewOrigin(for: selectedOverlayStyle, size: panel.frame.size, isDragging: true)
        panel.setFrameOrigin(targetOrigin)
        if let subPanel = settingsSubtitlePanel {
            updateSubtitlePanelFrame(for: panel, subPanel: subPanel)
        }
    }

    func updateSettingsPreviewPanel(isDragging: Bool = false, includeSubtitle: Bool = false, createIfNeeded: Bool = true) {
        guard !isRecording && !isTranscribing else { return }
        if settingsPreviewPanel == nil && (!createIfNeeded || isDragging) {
            return
        }

        let overlay = RecordingOverlayView()
            .environmentObject(self)
            .environmentObject(audioRecorder)

        let isEmbeddedActive = false
        let hasAI = false
        let previewAppName = showTargetAppInOverlay ? "Scribe" : ""
        let isTimerVis = durationVisible
        let targetSize = RecordingPanel.size(
            for: selectedOverlayStyle,
            overlaySize: selectedOverlaySize,
            isEmbeddedPreviewActive: isEmbeddedActive,
            previewTextLength: livePreviewText.count,
            targetAppName: previewAppName,
            isTimerVisible: isTimerVis,
            hasAIMode: hasAI
        )
        let targetRadius = RecordingPanel.radius(
            for: selectedOverlayStyle, 
            overlaySize: selectedOverlaySize, 
            isEmbeddedPreviewActive: isEmbeddedActive, 
            previewTextLength: livePreviewText.count,
            targetAppName: previewAppName,
            isTimerVisible: isTimerVis,
            hasAIMode: hasAI
        )
        let savedCustomOrigin: NSPoint? = hasCustomOverlayPosition
            ? NSPoint(x: customOverlayOriginX, y: customOverlayOriginY)
            : nil
        let targetOrigin = savedCustomOrigin ?? targetPreviewOrigin(for: selectedOverlayStyle, size: targetSize, isDragging: isDragging)

        if let existingPanel = settingsPreviewPanel {
            guard existingPanel.isVisible else { return }
            // Update existing panel in-place without recreation or flashing
            existingPanel.ignoresMouseEvents = false
            existingPanel.customUserOrigin = savedCustomOrigin
            existingPanel.updateAppearance(selectedOverlayAppearance)
            existingPanel.setContent(
                overlay,
                style: selectedOverlayStyle,
                overlaySize: selectedOverlaySize,
                isEmbeddedPreviewActive: isEmbeddedActive,
                previewTextLength: livePreviewText.count,
                targetAppName: previewAppName,
                isTimerVisible: isTimerVis,
                hasAIMode: hasAI
            )
            existingPanel.updateCornerRadius(targetRadius, targetSize: targetSize)

            let oldFrame = existingPanel.frame
            let effectiveOrigin = savedCustomOrigin ?? existingPanel.customUserOrigin ?? targetOrigin
            let calculatedFrame = NSRect(origin: effectiveOrigin, size: targetSize)
            let frameDiff = max(
                abs(oldFrame.origin.x - calculatedFrame.origin.x),
                abs(oldFrame.origin.y - calculatedFrame.origin.y),
                abs(oldFrame.size.width - calculatedFrame.size.width),
                abs(oldFrame.size.height - calculatedFrame.size.height)
            )

            if frameDiff > 1.0 {
                let isLargeCrossJump = abs(oldFrame.origin.x - effectiveOrigin.x) > 100 && abs(oldFrame.origin.y - effectiveOrigin.y) > 80
                if !isDragging && !isLargeCrossJump && (abs(oldFrame.origin.x - effectiveOrigin.x) > 4 || abs(oldFrame.origin.y - effectiveOrigin.y) > 4) {
                    NSAnimationContext.runAnimationGroup { ctx in
                        ctx.duration = 0.22
                        ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                        existingPanel.animator().setFrame(calculatedFrame, display: true)
                    }
                } else {
                    existingPanel.setFrame(calculatedFrame, display: true)
                }
            }

            existingPanel.orderFrontRegardless()
        } else if createIfNeeded {
            // Create new panel with smooth entrance animation
            let panel = RecordingPanel.make(
                style: selectedOverlayStyle,
                appearance: selectedOverlayAppearance,
                size: selectedOverlaySize,
                isEmbeddedPreviewActive: isEmbeddedActive,
                previewTextLength: livePreviewText.count,
                targetAppName: previewAppName,
                isTimerVisible: isTimerVis,
                hasAIMode: hasAI
            )
            panel.setContent(
                overlay,
                style: selectedOverlayStyle,
                overlaySize: selectedOverlaySize,
                isEmbeddedPreviewActive: isEmbeddedActive,
                previewTextLength: livePreviewText.count,
                targetAppName: previewAppName,
                isTimerVisible: isTimerVis,
                hasAIMode: hasAI
            )
            panel.collectionBehavior = [.moveToActiveSpace, .ignoresCycle]
            panel.customUserOrigin = savedCustomOrigin
            panel.onUserDragged = { [weak self, weak panel] newOrigin in
                guard let self = self, let panel = panel else { return }
                self.saveCustomOverlayOrigin(newOrigin)
                if let sub = self.settingsSubtitlePanel {
                    self.updateSubtitlePanelFrame(for: panel, subPanel: sub)
                }
            }

            let effectiveOrigin = savedCustomOrigin ?? recordingPanel?.customUserOrigin ?? targetOrigin
            let effectiveFrame = NSRect(origin: effectiveOrigin, size: targetSize)

            let refMidX = activePreviewReferenceWindow()?.frame.midX ?? effectiveOrigin.x
            let refMidY = activePreviewReferenceWindow()?.frame.midY ?? effectiveOrigin.y
            let startOrigin: NSPoint
            if selectedOverlayStyle.isSquareStyle {
                let offsetX: CGFloat = (effectiveOrigin.x >= refMidX) ? -14 : 14
                startOrigin = NSPoint(x: effectiveOrigin.x + offsetX, y: effectiveOrigin.y)
            } else {
                let offsetY: CGFloat = (effectiveOrigin.y <= refMidY) ? 14 : -14
                startOrigin = NSPoint(x: effectiveOrigin.x, y: effectiveOrigin.y + offsetY)
            }

            panel.setFrame(effectiveFrame, display: false)
            panel.setFrameOrigin(startOrigin)
            panel.alphaValue = 0

            panel.ignoresMouseEvents = false
            panel.orderFrontRegardless()
            settingsPreviewPanel = panel

            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.30
                ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().alphaValue = 1
                panel.animator().setFrameOrigin(effectiveOrigin)
            }
        }

        // Handle Subtitle Panel for preview mode
        if includeSubtitle && livePreviewEnabled {
            if livePreviewText.isEmpty {
                livePreviewText = l("Scribe transcribes your speech live…")
            }
            if settingsSubtitlePanel == nil {
                let subPanel = NSPanel(
                    contentRect: NSRect(x: 0, y: 0, width: 720, height: 60),
                    styleMask: [.borderless, .nonactivatingPanel],
                    backing: .buffered,
                    defer: false
                )
                subPanel.isFloatingPanel = true
                subPanel.level = .floating
                subPanel.backgroundColor = .clear
                subPanel.isOpaque = false
                subPanel.hasShadow = false
                subPanel.ignoresMouseEvents = true

                let subView = SubtitleOverlayView().environmentObject(self)
                let host = NSHostingView(rootView: subView)
                host.layer?.backgroundColor = .clear
                subPanel.contentView = host

                settingsSubtitlePanel = subPanel

                // Animate entrance
                subPanel.alphaValue = 0
                settingsPreviewPanel?.addChildWindow(subPanel, ordered: .above)
                subPanel.orderFrontRegardless()

                NSAnimationContext.runAnimationGroup { ctx in
                    ctx.duration = 0.35
                    ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                    subPanel.animator().alphaValue = 1
                }
            } else if let subPanel = settingsSubtitlePanel, let panel = settingsPreviewPanel {
                if subPanel.parent == nil {
                    panel.addChildWindow(subPanel, ordered: .above)
                }
                subPanel.orderFrontRegardless()
            }

            // Position safely on-screen
            if let subPanel = settingsSubtitlePanel, let panel = settingsPreviewPanel {
                updateSubtitlePanelFrame(for: panel, subPanel: subPanel)
            }

        } else {
            // Remove subtitle panel if no longer needed
            if let subPanel = settingsSubtitlePanel {
                settingsSubtitlePanel = nil
                subPanel.orderOut(nil)
                subPanel.close()
            }
        }
    }

    func hideSettingsPreviewPanel() {
        previewDismissTimer?.invalidate()
        previewDismissTimer = nil
        settingsPreviewAnimTimer?.invalidate()
        settingsPreviewAnimTimer = nil

        let subPanel = settingsSubtitlePanel
        settingsSubtitlePanel = nil

        guard let panel = settingsPreviewPanel else {
            subPanel?.orderOut(nil)
            subPanel?.close()
            if !isRecording && !isTranscribing { audioLevel = 0 }
            return
        }

        settingsPreviewPanel = nil
        panel.ignoresMouseEvents = true

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.35
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().alphaValue = 0
            subPanel?.animator().alphaValue = 0

            let currentFrame = panel.frame
            panel.animator().setFrameOrigin(NSPoint(x: currentFrame.minX, y: currentFrame.minY - 24))
        } completionHandler: { [weak self] in
            DispatchQueue.main.async {
                subPanel?.orderOut(nil)
                subPanel?.close()
                panel.orderOut(nil)
                panel.close()
                if self?.isRecording == false && self?.isTranscribing == false {
                    self?.audioLevel = 0
                }
                // Re-activate Settings window so buttons remain clickable
                if SettingsWindowManager.shared.isWindowOpen {
                    SettingsWindowManager.shared.makeKeyIfNeeded()
                }
            }
        }
    }

    // MARK: - Setup Helpers

    private func setupHotkeyHandler() {
        KeyboardShortcuts.onKeyDown(for: .toggleRecording) { [weak self] in
            Task { @MainActor in
                guard let self = self else { return }
                if self.pushToTalk {
                    if !self.isRecording {
                        self.toggleRecording()
                    }
                } else {
                    self.toggleRecording()
                }
            }
        }
        
        KeyboardShortcuts.onKeyUp(for: .toggleRecording) { [weak self] in
            Task { @MainActor in
                guard let self = self else { return }
                if self.pushToTalk && self.isRecording {
                    self.toggleRecording()
                }
            }
        }

        KeyboardShortcuts.onKeyDown(for: .directNoteRecording) { [weak self] in
            Task { @MainActor in
                guard let self = self, self.enableDirectNote else { return }
                if self.pushToTalk {
                    if !self.isRecording {
                        self.isDirectNoteRecording = true
                        self.toggleRecording()
                    }
                } else {
                    self.isDirectNoteRecording = true
                    self.toggleRecording()
                }
            }
        }

        KeyboardShortcuts.onKeyUp(for: .directNoteRecording) { [weak self] in
            Task { @MainActor in
                guard let self = self, self.enableDirectNote else { return }
                if self.pushToTalk && self.isRecording {
                    self.toggleRecording()
                }
            }
        }
    }

    private func setupEscHandler() {
        escMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53 else { return } // 53 = Esc
            Task { @MainActor [weak self] in
                guard let self, self.isRecording || self.isShowingPreview else { return }
                self.cancelRecording()
            }
        }
        localEscMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53, let self, (self.isRecording || self.isShowingPreview) {
                Task { @MainActor [weak self] in
                    self?.cancelRecording()
                }
                return nil // Consume event
            }
            return event
        }
    }

    private func preloadModel() {
        Task {
            if self.recognitionEngine.contains("Parakeet") {
                Task.detached(priority: .userInitiated) {
                    try? await ParakeetEngine.shared.loadModel()
                }
            }

            if !self.isInstantEngine {
                do {
                    let targetModel = self.effectiveModel
                    logger.info("Preloading WhisperKit model '\(targetModel)'…")
                    try await transcriptionService.ensureModelLoaded(modelName: targetModel)
                    logger.info("WhisperKit model loaded successfully")
                } catch {
                    logger.error("WhisperKit model preload failed: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Duration Timer

    private func startDurationTimer() {
        durationTimer?.invalidate()
        durationTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.recordingDuration += 1
            }
        }
    }

    private func stopDurationTimer() {
        durationTimer?.invalidate()
        durationTimer = nil
    }

    /// Formatted duration string for the overlay (e.g. "0:05", "1:30").
    var formattedDuration: String {
        let mins = Int(recordingDuration) / 60
        let secs = Int(recordingDuration) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    // MARK: - Live Preview (Floating Card Overlay)

    private func startLiveStreaming() {
        // When using Aether Neural, Live Preview is powered directly by Whisper snapshots
        guard isInstantEngine else {
            logger.info("Aether Neural active: Live preview powered natively by Whisper on Apple Neural Engine")
            return
        }

        let streamingLangs: [String]
        if isInstantEngine {
            streamingLangs = ["en"]
        } else {
            let isSingle = self.recognitionMode == "singleLanguage"
            if isSingle && self.singleDictationLanguage != "auto" {
                streamingLangs = [self.singleDictationLanguage]
            } else {
                let active = self.multilingualLanguages.filter { $0 != "auto" }
                streamingLangs = active.isEmpty ? ["ru", "en"] : active
            }
        }
        do {
            try transcriptionService.startStreaming(
                languages: streamingLangs,
                customVocabulary: vocabulary,
                userLocation: effectiveUserLocation,
                targetApp: self.targetRunningApplication
            ) { [weak self] streamingText in
                guard let self = self, self.isRecording else { return }
                
                let isSingle = self.recognitionMode == "singleLanguage"
                let preferredLangs = self.recognitionMode == "multilingual" ? self.multilingualLanguages : ["ru", "en"]
                let effectiveBlocked = AetherContextEngine.shared.activeEffectiveBlockedWords(
                    targetApp: self.targetRunningApplication,
                    userBlockedWords: self.blockedWords,
                    recognitionLanguages: isSingle ? [self.singleDictationLanguage] : preferredLangs
                )
                let effectiveVocab = AetherContextEngine.shared.activeEffectiveVocabulary(
                    targetApp: self.targetRunningApplication,
                    userVocabulary: self.vocabulary,
                    userLocation: self.effectiveUserLocation
                )

                // 1. Strip Whisper/Speech boundary hallucinations (credits, noise)
                let cleanedStream = TranscriptionService.stripBuiltInHallucinations(streamingText)

                // 2. Process dictation mode (Code, Clean, Raw, Chat, Formal)
                var formatted = ScribeModeProcessor.shared.process(text: cleanedStream, mode: self.transcriptionMode)
                
                // 3. Apply Custom Replacements, Canonical Vocabulary & Anti-Hallucination Filtering
                formatted = TextReplacer.apply(
                    replacements: self.textReplacements,
                    vocabulary: effectiveVocab,
                    blockedWords: effectiveBlocked,
                    blockedAction: self.blockedWordsActionRaw,
                    to: formatted
                )
                
                if AppState.isTextAllowedForLivePreview(text: formatted, allowedLanguages: preferredLangs) {
                    self.livePreviewText = formatted
                }
            }
            audioRecorder.onBufferTap = { [weak self] buffer in
                self?.transcriptionService.append(buffer)
            }
        } catch {
            logger.info("Live streaming unavailable: \(error.localizedDescription)")
        }
    }

    private func stopLiveStreaming() {
        audioRecorder.onBufferTap = nil
        Task {
            _ = await transcriptionService.stopStreaming()
        }
    }

    // MARK: - Native Whisper Live Streaming & Interim Generation

    private func applyLivePreviewUpdate(
        rawText: String,
        preferredLangs: [String],
        effectiveVocab: String,
        effectiveBlocked: String,
        allowShrink: Bool = false
    ) {
        guard self.isRecording || self.isTranscribing else { return }
        let trimmedRaw = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedRaw.isEmpty else { return }
        let cleaned = TranscriptionService.stripBuiltInHallucinations(trimmedRaw)
        var formatted = ScribeModeProcessor.shared.process(text: cleaned, mode: self.transcriptionMode)
        formatted = TextReplacer.apply(
            replacements: self.textReplacements,
            vocabulary: effectiveVocab,
            blockedWords: effectiveBlocked,
            blockedAction: self.blockedWordsActionRaw,
            to: formatted
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !formatted.isEmpty else { return }
        guard AppState.isTextAllowedForLivePreview(text: formatted, allowedLanguages: preferredLangs) else { return }

        let currentLen = self.livePreviewText.count
        if allowShrink || currentLen == 0 || formatted.count >= currentLen {
            self.latestWhisperTranscription = formatted
            if self.livePreviewText != formatted {
                self.livePreviewText = formatted
            }
        }
    }

    private func startInterimWhisperGeneration() {
        stopInterimWhisperGeneration()
        latestWhisperTranscription = ""
        transcriptionService.resetLivePreviewSession()

        let preferredLangs = multilingualLanguages.isEmpty ? ["ru", "en"] : multilingualLanguages
        let isSingle = recognitionMode == "singleLanguage"
        let lang = isSingle ? (singleDictationLanguage == "auto" ? nil : singleDictationLanguage) : nil
        let model = effectiveModel

        let effectiveBlocked = AetherContextEngine.shared.activeEffectiveBlockedWords(
            targetApp: self.targetRunningApplication,
            userBlockedWords: self.blockedWords,
            recognitionLanguages: isSingle ? [self.singleDictationLanguage] : preferredLangs
        )
        let effectiveVocab = AetherContextEngine.shared.activeEffectiveVocabulary(
            targetApp: self.targetRunningApplication,
            userVocabulary: self.vocabulary,
            userLocation: self.effectiveUserLocation
        )

        let partialHandler = self.makeLivePreviewProgressHandler(
            enabled: true,
            preferredLangs: preferredLangs,
            effectiveVocab: effectiveVocab,
            effectiveBlocked: effectiveBlocked
        )

        // Poll every 0.85 seconds to track user speech in real-time with responsive token streaming
        interimWhisperTimer = Timer.scheduledTimer(withTimeInterval: 0.85, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, self.isRecording, self.recordingDuration >= 0.45 else { return }
                guard self.interimWhisperTask == nil else { return }

                guard let snapshotURL = self.audioRecorder.createSnapshot() else { return }
                let customVocab = self.vocabulary
                let currentTargetApp = self.targetRunningApplication

                self.interimWhisperTask = Task.detached(priority: .userInitiated) { [weak self] in
                    guard let self = self else { return }
                    defer {
                        try? FileManager.default.removeItem(at: snapshotURL)
                        Task { @MainActor in
                            self.interimWhisperTask = nil
                        }
                    }

                    if let rawSnapshot = await self.transcriptionService.transcribeSnapshot(
                        audioURL: snapshotURL,
                        modelName: model,
                        language: lang,
                        preferredLanguages: preferredLangs,
                        customVocabulary: customVocab,
                        targetApp: currentTargetApp,
                        onPartialText: partialHandler
                    ), !rawSnapshot.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        await MainActor.run {
                            if (self.isRecording || self.isTranscribing) && !rawSnapshot.isEmpty {
                                let allowMinorRefinement = rawSnapshot.count >= max(1, self.livePreviewText.count - 6)
                                self.applyLivePreviewUpdate(
                                    rawText: rawSnapshot,
                                    preferredLangs: preferredLangs,
                                    effectiveVocab: effectiveVocab,
                                    effectiveBlocked: effectiveBlocked,
                                    allowShrink: allowMinorRefinement
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    /// Strict language and script filter for live preview updates.
    /// Prevents Chinese, Spanish, or other unselected languages from appearing during recording.
    static func isTextAllowedForLivePreview(text: String, allowedLanguages: [String]) -> Bool {
        guard !text.isEmpty else { return false }

        let allowedBases = Set(allowedLanguages.map { baseLanguageCode(for: $0).lowercased() })
        let allowsChinese = allowedBases.contains("zh")
        let allowsJapanese = allowedBases.contains("ja")
        let allowsKorean = allowedBases.contains("ko")
        let allowsArabic = allowedBases.contains("ar") || allowedBases.contains("fa")
        let allowsHebrew = allowedBases.contains("he")
        let allowsSpanish = allowedBases.contains("es")

        // 1. Block foreign script glyphs
        for scalar in text.unicodeScalars {
            let v = scalar.value
            // CJK Han ideographs (Chinese)
            if !allowsChinese && ((v >= 0x4E00 && v <= 0x9FFF) || (v >= 0x3400 && v <= 0x4DBF)) {
                return false
            }
            // Japanese Kana
            if !allowsJapanese && ((v >= 0x3040 && v <= 0x309F) || (v >= 0x30A0 && v <= 0x30FF)) {
                return false
            }
            // Korean Hangul
            if !allowsKorean && ((v >= 0xAC00 && v <= 0xD7AF) || (v >= 0x1100 && v <= 0x11FF)) {
                return false
            }
            // Arabic
            if !allowsArabic && ((v >= 0x0600 && v <= 0x06FF) || (v >= 0x0750 && v <= 0x077F)) {
                return false
            }
            // Hebrew
            if !allowsHebrew && (v >= 0x0590 && v <= 0x05FF) {
                return false
            }
        }

        // 2. Block Spanish hallucinations if Spanish is not an allowed language
        let lower = text.lowercased()
        if !allowsSpanish {
            let spanishMarkers = [
                "gracias", "subtítulos", "subtitulos", "amara.org", "hola a todos",
                "por favor", "suscríbete", "suscribete", "hasta luego", "hasta la próxima",
                "de nuevo", "muchas gracias", "buenos días", "buenas noches"
            ]
            for marker in spanishMarkers {
                if lower.contains(marker) {
                    return false
                }
            }
        }

        // 3. Block Whisper subtitle and broadcast hallucination loops
        let subtitleHallucinations = [
            "субтитры", "субтитров", "подписывайтесь", "подпишитесь",
            "спасибо за просмотр", "до встречи в следующем видео", "продолжение следует",
            "amara.org", "subtitles by", "thanks for watching", "thank you for watching"
        ]
        for marker in subtitleHallucinations {
            if lower.contains(marker) {
                return false
            }
        }

        return true
    }

    private func stopInterimWhisperGeneration() {
        interimWhisperTimer?.invalidate()
        interimWhisperTimer = nil
        transcriptionService.cancelSnapshot()
        interimWhisperTask?.cancel()
        interimWhisperTask = nil
    }
}
