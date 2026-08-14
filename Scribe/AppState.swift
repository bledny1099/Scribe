import Combine
import KeyboardShortcuts
import SwiftUI
import OSLog

extension Array: RawRepresentable where Element: Codable {
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
        switch self {
        case .waveform, .ecg: true
        case .classic, .minimal, .orb: false
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
        case .liquidGlass: .hudWindow
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
    case paste             // Replace clipboard and paste
    case append            // Append to current clipboard text and paste
    case integrationsOnly  // Export to notes/integrations only (no active window paste)

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .paste:            return "Replace"
        case .append:           return "Append"
        case .integrationsOnly: return "Integrations Only"
        }
    }

    var icon: String {
        switch self {
        case .paste:            return "doc.on.clipboard"
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

/// Placement mode for Live Preview text (Floating Pill vs Inside Card).
enum LivePreviewMode: String, CaseIterable, Identifiable {
    case external = "external"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .external: "Floating Pill"
        }
    }

    var icon: String {
        switch self {
        case .external: "capsule"
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
    LanguageOption("id", "Indonesian (Bahasa Indonesia)")
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

// MARK: - App State

/// Central orchestrator that connects recording, transcription and paste services.
@MainActor
final class AppState: ObservableObject {

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
    @AppStorage("cleanFillerWords") var cleanFillerWords: Bool = true
    @Published var targetAppName: String = ""
    @Published var targetAppIcon: NSImage? = nil

    public func captureTargetApplication() {
        let scribeID = Bundle.main.bundleIdentifier
        if let app = NSWorkspace.shared.runningApplications.first(where: { $0.isActive && $0.bundleIdentifier != scribeID }) {
            targetAppName = app.localizedName ?? ""
            targetAppIcon = app.icon
        } else if let app = NSWorkspace.shared.menuBarOwningApplication, app.bundleIdentifier != scribeID {
            targetAppName = app.localizedName ?? ""
            targetAppIcon = app.icon
        } else {
            targetAppName = ""
            targetAppIcon = nil
        }
    }

    @Published var recordingDuration: TimeInterval = 0
    @Published var livePreviewText: String = ""

    @Published public var transcribingDotCount: Int = 3
    private var transcribingDotTimer: Timer?

    public func startTranscribingDotTimer() {
        stopTranscribingDotTimer()
        transcribingDotCount = 1
        transcribingDotTimer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                self.transcribingDotCount = (self.transcribingDotCount % 3) + 1
            }
        }
    }

    public func stopTranscribingDotTimer() {
        transcribingDotTimer?.invalidate()
        transcribingDotTimer = nil
        transcribingDotCount = 3
    }

    public var transcribingStatusText: String {
        let base = l("Transcribing")
        let dots = String(repeating: ".", count: transcribingDotCount)
        return "\(base)\(dots)"
    }

    // MARK: App Storage Preferences

    @AppStorage("selectedLanguage") var selectedLanguage: String = "auto"
    @AppStorage("selectedUILanguage") var selectedUILanguage: String = "auto"
    @AppStorage("selectedModel") var selectedModel: String = "openai_whisper-small" {
        didSet {
            if oldValue != selectedModel {
                preloadModel()
            }
        }
    }

    /// Helper for string localization using current selected UI language.
    func l(_ key: String) -> String {
        key.loc(selectedUILanguage)
    }
    @AppStorage("selectedTheme") var selectedThemeRaw: String = AppTheme.aurora.rawValue
    @AppStorage("selectedOverlayStyle") var selectedOverlayStyleRaw: String = OverlayStyle.waveform.rawValue
    @AppStorage("selectedOverlaySize") var selectedOverlaySizeRaw: String = OverlaySize.s100.rawValue
    @AppStorage("selectedPanelAppearance") var selectedPanelAppearanceRaw: String = PanelAppearance.dark.rawValue
    @AppStorage("soundFeedbackEnabled") var soundFeedbackEnabled: Bool = true
    @AppStorage("livePreviewEnabled") var livePreviewEnabled: Bool = false
    @AppStorage("livePreviewBackground") var livePreviewBackgroundRaw: String = SubtitleBackground.glass.rawValue
    @AppStorage("durationVisible") public var durationVisible: Bool = true
    @AppStorage("autoTranslate") var autoTranslate: Bool = false
    @AppStorage("noteExportMode") public var noteExportMode: ExportMode = .append
    @AppStorage("enableAppleNotes") public var enableAppleNotes: Bool = false
    @AppStorage("attachAudioToNotes") public var attachAudioToNotes: Bool = false
    @AppStorage("textReplacements") public var textReplacements: [Replacement] = []
    @AppStorage("enableObsidian") public var enableObsidian: Bool = false
    @AppStorage("appleNotesTargetNote") public var appleNotesTargetNote: String = "Scribe Notes"
    @AppStorage("obsidianVaultURL") public var obsidianVaultURL: String = ""
    @AppStorage("obsidianTargetNote") public var obsidianTargetNote: String = "Scribe Notes"
    @AppStorage("enableNotion") public var enableNotion: Bool = false
    @AppStorage("notionIntegrationToken") public var notionIntegrationToken: String = ""
    @AppStorage("notionPageId") public var notionPageId: String = ""
    @AppStorage("integrationExportMode") public var integrationExportMode: String = "both" // "both", "notesOnly", "windowOnly"
    @AppStorage("vocabulary") public var vocabulary: String = ""
    @AppStorage("customVocabularyPresets") public var customVocabularyPresets: [VocabularyPreset] = []
    @AppStorage("allowAnonymousVocabularyContribution") public var allowAnonymousVocabularyContribution: Bool = false
    @AppStorage("hasPromptedVocabularyDataSharing") public var hasPromptedVocabularyDataSharing: Bool = false
    @AppStorage("recognitionEngine") public var recognitionEngine: String = "Both"
    @AppStorage("recognitionMode") public var recognitionMode: String = "multilingual"
    @AppStorage("singleDictationLanguage") public var singleDictationLanguage: String = "ru"
    @AppStorage("pushToTalk") public var pushToTalk: Bool = false
    @AppStorage("enableCloudAI") public var enableCloudAI: Bool = false
    @AppStorage("cloudAIProvider") public var cloudAIProviderRaw: String = CloudAIProvider.groq.rawValue
    @AppStorage("groqAPIKey") public var groqAPIKey: String = ""
    @AppStorage("openAIAPIKey") public var openAIAPIKey: String = ""
    @AppStorage("selectedAIRefinementMode") public var selectedAIRefinementModeRaw: String = AIRefinementMode.raw.rawValue

    public var cloudAIProvider: CloudAIProvider {
        get { CloudAIProvider(rawValue: cloudAIProviderRaw) ?? .groq }
        set { cloudAIProviderRaw = newValue.rawValue }
    }

    public var selectedAIRefinementMode: AIRefinementMode {
        get { AIRefinementMode(rawValue: selectedAIRefinementModeRaw) ?? .raw }
        set { selectedAIRefinementModeRaw = newValue.rawValue }
    }

    public var activeCloudAPIKey: String {
        switch cloudAIProvider {
        case .groq:                 return groqAPIKey
        case .openAI, .scribeCloud: return openAIAPIKey
        }
    }

    @AppStorage("defaultNoteTags") public var defaultNoteTags: String = ""
    @AppStorage("appendDateToNotes") public var appendDateToNotes: Bool = true
    @AppStorage("enableDirectNote") public var enableDirectNote: Bool = true
    @AppStorage("directNoteTargetApp") var directNoteTargetAppRaw: String = NoteApp.appleNotes.rawValue
    @Published public var isDirectNoteRecording: Bool = false

    /// Computed property for type-safe direct note target app access.
    var directNoteTargetApp: NoteApp {
        get { NoteApp(rawValue: directNoteTargetAppRaw) ?? .appleNotes }
        set { directNoteTargetAppRaw = newValue.rawValue }
    }

    /// Computed property for type-safe theme access.
    var selectedTheme: AppTheme {
        get { AppTheme(rawValue: selectedThemeRaw) ?? .aurora }
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
        get { OverlaySize(rawValue: selectedOverlaySizeRaw) ?? .s100 }
        set { selectedOverlaySizeRaw = newValue.rawValue }
    }

    /// Compensation multiplier for text/timers when the overlay panel is scaled down.
    var overlayTextCompensation: CGFloat {
        let scale = selectedOverlaySize.scale
        return 1.0 + (1.0 - scale) * 0.75
    }

    /// Computed property for type-safe panel appearance access.
    var selectedPanelAppearance: PanelAppearance {
        get { PanelAppearance(rawValue: selectedPanelAppearanceRaw) ?? .dark }
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

    @AppStorage("selectedPasteMode") var selectedPasteModeRaw: String = PasteMode.paste.rawValue

    /// Computed property for type-safe paste mode access.
    var selectedPasteMode: PasteMode {
        get { PasteMode(rawValue: selectedPasteModeRaw) ?? .paste }
        set { selectedPasteModeRaw = newValue.rawValue }
    }

    // MARK: Services

    let audioRecorder       = AudioRecorder()
    let transcriptionService = TranscriptionService()

    // MARK: Private

    private var recordingPanel: RecordingPanel?
    private var subtitlePanel: NSPanel?
    private var cancellables   = Set<AnyCancellable>()
    private var escMonitor: Any?
    private var localEscMonitor: Any?
    private var durationTimer: Timer?
    private var livePreviewTimer: Timer?
    private var isLiveTranscribing = false

    // MARK: Init

    init() {
        logger.info("AppState init")
        setupHotkeyHandler()
        setupEscHandler()
        setupAudioLevelForwarding()
        setupLivePreviewResizing()
        preloadModel()
        checkFirstLaunchPermissions()
        
        if CommandLine.arguments.contains("--settings") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                SettingsWindowManager.shared.showSettings(appState: self)
            }
        }
        
        if CommandLine.arguments.contains("--permissions") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                PermissionWindowManager.shared.showWindow(appState: self)
            }
        }
    }

    // MARK: - Onboarding
    @AppStorage("hasCompletedFirstLaunchSetup") private var hasCompletedFirstLaunchSetup: Bool = false
    @AppStorage("userName") public var userName: String = ""

    private func checkFirstLaunchPermissions() {
        if !hasCompletedFirstLaunchSetup {
            hasCompletedFirstLaunchSetup = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                let mic = PermissionManager.shared.isMicrophoneGranted
                let ax = PasteService.isAccessibilityGranted()
                if !mic || !ax {
                    PermissionWindowManager.shared.showWindow(appState: self)
                } else {
                    SettingsWindowManager.shared.showSettings(appState: self)
                }
            }
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

    /// Cancel the current recording without transcribing — just stop and close.
    func cancelRecording() {
        if isShowingPreview {
            hideSettingsPreviewPanel()
            return
        }
        guard isRecording else { return }
        stopDurationTimer()
        stopLivePreviewTimer()
        livePreviewText = ""
        let audioURL = audioRecorder.stopRecording()
        isRecording = false
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
        do {
            try audioRecorder.startRecording()
            isRecording     = true
            recordingStatus = .recording
            recordingDuration = 0
            livePreviewText = ""
            startDurationTimer()
            if livePreviewEnabled { startLivePreviewTimer() }
            showPanel()
            if soundFeedbackEnabled { SoundFeedback.play(.recordingStarted) }
            logger.info("Recording started")
        } catch {
            recordingStatus = .error("Mic error")
            if soundFeedbackEnabled { SoundFeedback.play(.error) }
            logger.error("Failed to start recording: \(error.localizedDescription)")
        }
    }

    private func stopRecording() {
        stopDurationTimer()
        stopLivePreviewTimer()
        livePreviewText = ""
        if soundFeedbackEnabled { SoundFeedback.play(.recordingStopped) }
        let audioURL = audioRecorder.stopRecording()
        isRecording = false
        logger.info("Recording stopped, audioURL=\(audioURL?.path ?? "nil")")

        guard let audioURL else {
            logger.warning("No audio URL returned")
            hidePanel()
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

        isTranscribing = true
        recordingStatus = .transcribing

        let localProvider = self.cloudAIProvider
        let localMode = self.selectedAIRefinementMode
        let localAPIKey = self.activeCloudAPIKey
        let localEnableCloud = self.enableCloudAI

        Task {
            do {
                logger.info("Starting transcription with model=\(self.selectedModel), lang=\(self.selectedLanguage)…")
                let langParam = self.selectedLanguage == "auto" ? nil : self.selectedLanguage
                var text = ""

                if localEnableCloud && !localAPIKey.isEmpty {
                    logger.info("Using Cloud AI transcription via \(localProvider.displayName)…")
                    do {
                        text = try await CloudAIService.shared.transcribeAudio(
                            audioURL: audioURL,
                            provider: localProvider,
                            apiKey: localAPIKey,
                            language: langParam
                        )
                    } catch {
                        logger.warning("Cloud transcription failed (\(error.localizedDescription)), falling back to local WhisperKit…")
                        text = try await transcriptionService.transcribe(
                            audioURL: audioURL,
                            modelName: self.selectedModel,
                            language: langParam,
                            autoTranslate: self.autoTranslate
                        )
                    }
                } else {
                    text = try await transcriptionService.transcribe(
                        audioURL: audioURL,
                        modelName: self.selectedModel,
                        language: langParam,
                        autoTranslate: self.autoTranslate
                    )
                }

                if self.cleanFillerWords {
                    text = TranscriptionService.removeFillerWordsAndDuplicates(text)
                }
                text = TextReplacer.apply(replacements: self.textReplacements, vocabulary: self.vocabulary, to: text)

                // LLM Refinement if Cloud AI is active and an AI mode is selected
                if localEnableCloud && !localAPIKey.isEmpty && localMode != .raw {
                    logger.info("Refining text with LLM (\(localMode.displayName))…")
                    text = try await CloudAIService.shared.refineText(
                        text: text,
                        mode: localMode,
                        provider: localProvider,
                        apiKey: localAPIKey
                    )
                }

                logger.info("Transcription result: '\(text)'")

                if text.isEmpty {
                    logger.warning("Transcription returned empty text")
                    recordingStatus = .error("No speech")
                    try? await Task.sleep(for: .seconds(1.5))
                    hidePanel()
                } else if TranscriptionService.isVoiceCancelCommand(text) {
                    logger.info("Voice cancel command detected: '\(text)'")
                    recordingStatus = .error("Cancelled")
                    if self.soundFeedbackEnabled { SoundFeedback.play(.error) }
                    try? await Task.sleep(for: .seconds(1.2))
                    hidePanel()
                } else {
                    // Use selected paste mode
                    switch self.selectedPasteMode {
                    case .paste:  PasteService.copyToClipboard(text)
                    case .append: PasteService.appendToClipboard(text)
                    case .integrationsOnly: break
                    }
                    recordingStatus = .done
                    if self.soundFeedbackEnabled { SoundFeedback.play(.transcriptionDone) }

                    // Save to history
                    let record = TranscriptionRecord(
                        text: text,
                        duration: self.recordingDuration,
                        language: self.selectedLanguage,
                        model: self.selectedModel
                    )
                    TranscriptionHistory.shared.add(record)

                    // Export to notes (Apple Notes, Obsidian, Notion)
                    NoteExporter.export(text: text, state: self)

                    let isNotesOnly = self.isDirectNoteRecording ||
                                      self.selectedPasteMode == .integrationsOnly ||
                                      self.integrationExportMode == "notesOnly"

                    if isNotesOnly {
                        logger.info("Integrations-only mode active: Skipping active window paste.")
                    } else {
                        logger.info("Text copied to clipboard, simulating paste…")
                        // Brief delay so the user sees the checkmark, then paste
                        try? await Task.sleep(for: .milliseconds(400))
                        PasteService.simulatePaste()
                    }

                    try? await Task.sleep(for: .seconds(0.8))
                    hidePanel()
                }
            } catch {
                recordingStatus = .error("Error")
                if self.soundFeedbackEnabled { SoundFeedback.play(.error) }
                logger.error("Transcription failed: \(error.localizedDescription)")
                try? await Task.sleep(for: .seconds(2))
                hidePanel()
            }

            isTranscribing = false

            // Clean up temp file
            try? FileManager.default.removeItem(at: audioURL)
        }
    }

    // MARK: - Panel Management

    private func showPanel() {
        let overlay = RecordingOverlayView()
            .environmentObject(self)
            .environmentObject(audioRecorder)

        let isEmbedded = false
        let panel = RecordingPanel.make(
            style: selectedOverlayStyle,
            appearance: selectedPanelAppearance,
            size: selectedOverlaySize,
            isEmbeddedPreviewActive: isEmbedded,
            previewTextLength: livePreviewText.count
        )
        panel.setContent(
            overlay,
            style: selectedOverlayStyle,
            overlaySize: selectedOverlaySize,
            isEmbeddedPreviewActive: isEmbedded,
            previewTextLength: livePreviewText.count
        )

        panel.positionAtBottom()

        panel.orderFrontRegardless()
        recordingPanel = panel

        // Create the subtitle panel for live preview
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

        // Position it below the main panel (macOS Y=0 is bottom, so subtract height + margin)
        let frame = panel.frame
        let subY = frame.minY - 110 
        let subX = frame.midX - 400
        subPanel.setFrameOrigin(NSPoint(x: subX, y: subY))

        panel.addChildWindow(subPanel, ordered: .below)
        subtitlePanel = subPanel
    }

    private func hidePanel() {
        let panel = recordingPanel
        let sub = subtitlePanel
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.25
            panel?.animator().alphaValue = 0
            sub?.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                self?.recordingPanel?.close()
                self?.recordingPanel = nil
                self?.subtitlePanel?.close()
                self?.subtitlePanel = nil
            }
        }
        recordingStatus = .idle
    }

    // MARK: - Live Preview Panel Resizing (during recording)

    /// Observe `livePreviewText` changes and resize the recording panel dynamically.
    private func setupLivePreviewResizing() {
        $livePreviewText
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.resizeRecordingPanelForEmbeddedPreview()
            }
            .store(in: &cancellables)
    }

    /// Resize the live recording panel's NSWindow when embedded preview text changes.
    private func resizeRecordingPanelForEmbeddedPreview() {
        guard let panel = recordingPanel, (isRecording || isTranscribing) else { return }
        return // Embedded preview removed

        let isEmbedded = !livePreviewText.isEmpty
        let newSize = RecordingPanel.size(
            for: selectedOverlayStyle,
            overlaySize: selectedOverlaySize,
            isEmbeddedPreviewActive: isEmbedded,
            previewTextLength: livePreviewText.count
        )

        let overlay = RecordingOverlayView()
            .environmentObject(self)
            .environmentObject(audioRecorder)
        panel.setContent(
            overlay,
            style: selectedOverlayStyle,
            overlaySize: selectedOverlaySize,
            isEmbeddedPreviewActive: isEmbedded,
            previewTextLength: livePreviewText.count
        )

        let oldFrame = panel.frame
        // Keep the top edge anchored; expand downward
        let newY = oldFrame.maxY - newSize.height
        let newFrame = NSRect(x: oldFrame.origin.x, y: newY, width: newSize.width, height: newSize.height)

        if oldFrame != newFrame {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.25
                ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                panel.animator().setFrame(newFrame, display: true)
            }
        }
    }

    // MARK: - Floating Preview Panel for Settings (5-second auto-dismiss)

    private var settingsPreviewPanel: RecordingPanel?
    private var settingsSubtitlePanel: NSPanel?
    var isShowingPreview: Bool { settingsPreviewPanel != nil }
    private var settingsPreviewAnimTimer: Timer?
    private var previewDismissTimer: Timer?

    func showSettingsPreviewFor5Seconds() {
        guard !isRecording && !isTranscribing else { return }

        if livePreviewEnabled {
            livePreviewText = l("Scribe transcribes your speech live…")
        } else {
            livePreviewText = ""
        }

        updateSettingsPreviewPanel()

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
        if settingsPreviewPanel != nil {
            // Preview is active: colors update automatically via SwiftUI binding. Reset 5-second timer.
            previewDismissTimer?.invalidate()
            previewDismissTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.hideSettingsPreviewPanel()
                }
            }
        } else {
            showSettingsPreviewFor5Seconds()
        }
    }

    private func targetPreviewOrigin(for style: OverlayStyle, size: NSSize, isDragging: Bool = false) -> NSPoint {
        guard let screen = NSScreen.main else { return .zero }
        let screenFrame = screen.visibleFrame

        var activeFrame: NSRect? = nil
        if let permFrame = PermissionWindowManager.shared.windowFrame, NSApp.keyWindow == PermissionWindowManager.shared.window {
            activeFrame = permFrame
        } else if let setFrame = SettingsWindowManager.shared.windowFrame, NSApp.keyWindow == SettingsWindowManager.shared.window {
            activeFrame = setFrame
        } else {
            activeFrame = SettingsWindowManager.shared.windowFrame ?? PermissionWindowManager.shared.windowFrame
        }

        guard let settingsFrame = activeFrame else {
            let x = screenFrame.midX - size.width / 2
            let y = screenFrame.minY + 160
            return NSPoint(x: x, y: y)
        }

        let spaceRight = screenFrame.maxX - settingsFrame.maxX
        let spaceLeft = settingsFrame.minX - screenFrame.minX
        let spaceBelow = settingsFrame.minY - screenFrame.minY
        let spaceAbove = screenFrame.maxY - settingsFrame.maxY

        let padding: CGFloat = 16

        // 1. If enough space on the right, place on the right
        if spaceRight >= size.width + padding {
            let x = settingsFrame.maxX + padding
            let preferredY = settingsFrame.midY - size.height / 2
            let y = max(screenFrame.minY + padding, min(preferredY, screenFrame.maxY - size.height - padding))
            return NSPoint(x: x, y: y)
        }

        // 2. If enough space on the left, place on the left
        if spaceLeft >= size.width + padding {
            let x = settingsFrame.minX - size.width - padding
            let preferredY = settingsFrame.midY - size.height / 2
            let y = max(screenFrame.minY + padding, min(preferredY, screenFrame.maxY - size.height - padding))
            return NSPoint(x: x, y: y)
        }

        // 3. If neither side fits fully, check if bottom or top has enough space
        if spaceBelow >= size.height + padding {
            let x = max(screenFrame.minX + padding, min(settingsFrame.midX - size.width / 2, screenFrame.maxX - size.width - padding))
            let y = settingsFrame.minY - size.height - padding
            return NSPoint(x: x, y: y)
        }

        if spaceAbove >= size.height + padding {
            let x = max(screenFrame.minX + padding, min(settingsFrame.midX - size.width / 2, screenFrame.maxX - size.width - padding))
            let y = settingsFrame.maxY + padding
            return NSPoint(x: x, y: y)
        }

        // 4. Fallback: place on the side (right vs left) that has MORE available space
        if spaceRight >= spaceLeft {
            let x = min(settingsFrame.maxX + padding, screenFrame.maxX - size.width - padding)
            let preferredY = settingsFrame.midY - size.height / 2
            let y = max(screenFrame.minY + padding, min(preferredY, screenFrame.maxY - size.height - padding))
            return NSPoint(x: max(screenFrame.minX + padding, x), y: y)
        } else {
            let x = max(screenFrame.minX + padding, settingsFrame.minX - size.width - padding)
            let preferredY = settingsFrame.midY - size.height / 2
            let y = max(screenFrame.minY + padding, min(preferredY, screenFrame.maxY - size.height - padding))
            return NSPoint(x: min(screenFrame.maxX - size.width - padding, x), y: y)
        }
    }

    func updateSettingsPreviewPanel(isDragging: Bool = false) {
        guard !isRecording && !isTranscribing else { return }
        if isDragging && (settingsPreviewPanel == nil || settingsPreviewPanel?.isVisible == false) {
            return
        }

        let overlay = RecordingOverlayView()
            .environmentObject(self)
            .environmentObject(audioRecorder)

        let isEmbeddedActive = false
        let targetSize = RecordingPanel.size(
            for: selectedOverlayStyle,
            overlaySize: selectedOverlaySize,
            isEmbeddedPreviewActive: isEmbeddedActive,
            previewTextLength: livePreviewText.count
        )
        let targetRadius = RecordingPanel.radius(
            for: selectedOverlayStyle, 
            overlaySize: selectedOverlaySize, 
            isEmbeddedPreviewActive: isEmbeddedActive,
            previewTextLength: livePreviewText.count
        )
        let targetOrigin = targetPreviewOrigin(for: selectedOverlayStyle, size: targetSize, isDragging: isDragging)
        let targetFrame = NSRect(origin: targetOrigin, size: targetSize)

        if let existingPanel = settingsPreviewPanel {
            // Update existing panel in-place without recreation or flashing
            existingPanel.ignoresMouseEvents = true
            existingPanel.updateAppearance(selectedPanelAppearance)
            existingPanel.setContent(overlay, style: selectedOverlayStyle, overlaySize: selectedOverlaySize, isEmbeddedPreviewActive: isEmbeddedActive, previewTextLength: livePreviewText.count)
            existingPanel.updateCornerRadius(targetRadius, targetSize: targetSize)

            let oldFrame = existingPanel.frame
            let calculatedFrame: NSRect
            if abs(oldFrame.origin.y - targetOrigin.y) > 50 || abs(oldFrame.origin.x - targetOrigin.x) > 50 {
                calculatedFrame = targetFrame
            } else {
                let calculatedY = oldFrame.maxY - targetSize.height
                calculatedFrame = NSRect(x: targetOrigin.x, y: calculatedY, width: targetSize.width, height: targetSize.height)
            }

            if oldFrame != calculatedFrame {
                existingPanel.setFrame(calculatedFrame, display: true)
            }

            existingPanel.orderFrontRegardless()
        } else {
            // Create new panel with smooth slide-up entrance animation
            let panel = RecordingPanel.make(
                style: selectedOverlayStyle,
                appearance: selectedPanelAppearance,
                size: selectedOverlaySize,
                isEmbeddedPreviewActive: isEmbeddedActive,
                previewTextLength: livePreviewText.count
            )
            panel.setContent(overlay, style: selectedOverlayStyle, overlaySize: selectedOverlaySize, isEmbeddedPreviewActive: isEmbeddedActive, previewTextLength: livePreviewText.count)
            panel.collectionBehavior = [.moveToActiveSpace, .ignoresCycle]

            let startY = targetOrigin.y - 24
            panel.setFrame(targetFrame, display: false)
            panel.setFrameOrigin(NSPoint(x: targetOrigin.x, y: startY))
            panel.alphaValue = 0

            panel.ignoresMouseEvents = true
            panel.orderFrontRegardless()
            settingsPreviewPanel = panel

            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.35
                ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().alphaValue = 1
                panel.animator().setFrameOrigin(targetOrigin)
            }
        }
        
        // Handle Subtitle Panel for external mode
        if livePreviewEnabled && !livePreviewText.isEmpty {
            if settingsSubtitlePanel == nil {
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
                
                settingsSubtitlePanel = subPanel
                
                // Animate entrance
                subPanel.alphaValue = 0
                settingsPreviewPanel?.addChildWindow(subPanel, ordered: .below)
                
                NSAnimationContext.runAnimationGroup { ctx in
                    ctx.duration = 0.35
                    ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                    subPanel.animator().alphaValue = 1
                }
            }
            
            // Position
            if let subPanel = settingsSubtitlePanel, let panel = settingsPreviewPanel {
                let frame = panel.frame
                let subY = frame.minY - 110
                let subX = frame.midX - 400
                subPanel.setFrameOrigin(NSPoint(x: subX, y: subY))
            }
            
        } else {
            // Remove subtitle panel if no longer needed
            if let subPanel = settingsSubtitlePanel {
                subPanel.orderOut(nil)
                subPanel.close()
                settingsSubtitlePanel = nil
            }
        }
    }

    func hideSettingsPreviewPanel() {
        previewDismissTimer?.invalidate()
        previewDismissTimer = nil
        settingsPreviewAnimTimer?.invalidate()
        settingsPreviewAnimTimer = nil

        guard let panel = settingsPreviewPanel else {
            if !isRecording && !isTranscribing { audioLevel = 0 }
            return
        }

        settingsPreviewPanel = nil
        panel.ignoresMouseEvents = true

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.35
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().alphaValue = 0

            let currentFrame = panel.frame
            panel.animator().setFrameOrigin(NSPoint(x: currentFrame.minX, y: currentFrame.minY - 24))
        } completionHandler: { [weak self] in
            MainActor.assumeIsolated {
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
                if self.pushToTalk && !self.isRecording {
                    self.toggleRecording()
                }
            }
        }
        
        KeyboardShortcuts.onKeyUp(for: .toggleRecording) { [weak self] in
            Task { @MainActor in
                guard let self = self else { return }
                if self.pushToTalk {
                    if self.isRecording {
                        self.toggleRecording()
                    }
                } else {
                    self.toggleRecording()
                }
            }
        }

        KeyboardShortcuts.onKeyDown(for: .directNoteRecording) { [weak self] in
            Task { @MainActor in
                guard let self = self, self.enableDirectNote else { return }
                if self.pushToTalk && !self.isRecording {
                    self.isDirectNoteRecording = true
                    self.toggleRecording()
                }
            }
        }

        KeyboardShortcuts.onKeyUp(for: .directNoteRecording) { [weak self] in
            Task { @MainActor in
                guard let self = self, self.enableDirectNote else { return }
                if self.pushToTalk {
                    if self.isRecording {
                        self.toggleRecording()
                    }
                } else {
                    self.isDirectNoteRecording = true
                    self.toggleRecording()
                }
            }
        }
    }

    private func setupEscHandler() {
        escMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53 else { return } // 53 = Esc
            Task { @MainActor [weak self] in
                self?.cancelRecording()
            }
        }
        localEscMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 {
                Task { @MainActor [weak self] in
                    self?.cancelRecording()
                }
                return nil // Consume event
            }
            return event
        }
    }

    private func setupAudioLevelForwarding() {
        audioRecorder.$audioLevel
            .receive(on: RunLoop.main)
            .assign(to: &$audioLevel)
    }

    private func preloadModel() {
        Task {
            do {
                logger.info("Preloading WhisperKit model '\(self.selectedModel)'…")
                try await transcriptionService.ensureModelLoaded(modelName: self.selectedModel)
                logger.info("WhisperKit model loaded successfully")
            } catch {
                logger.error("WhisperKit model preload failed: \(error.localizedDescription)")
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

    // MARK: - Live Preview Timer

    private func startLivePreviewTimer() {
        livePreviewTimer?.invalidate()
        livePreviewTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.runLivePreview()
            }
        }
    }

    private func stopLivePreviewTimer() {
        livePreviewTimer?.invalidate()
        livePreviewTimer = nil
    }

    private func runLivePreview() async {
        guard isRecording, !isLiveTranscribing else { return }
        guard audioRecorder.currentRecordingURL != nil else { return }

        isLiveTranscribing = true
        defer { isLiveTranscribing = false }

        // Create a snapshot WAV file from the in-memory buffers
        guard let snapshotURL = audioRecorder.createSnapshot() else { return }
        defer { try? FileManager.default.removeItem(at: snapshotURL) }

        do {
            let langParam = selectedLanguage == "auto" ? nil : selectedLanguage
            let text = try await transcriptionService.transcribe(
                audioURL: snapshotURL,
                modelName: selectedModel,
                language: langParam,
                autoTranslate: autoTranslate
            )
            // Only update if we're still recording
            if isRecording {
                livePreviewText = text
            }
        } catch {
            logger.warning("Live preview transcription failed: \(error.localizedDescription)")
        }
    }
}
