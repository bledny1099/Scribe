import Combine
import KeyboardShortcuts
import SwiftUI
import os.log

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

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .dark:  "Dark"
        case .light: "Light"
        }
    }

    var icon: String {
        switch self {
        case .dark:  "moon.fill"
        case .light: "sun.max"
        }
    }

    var nsAppearance: NSAppearance {
        switch self {
        case .dark:  NSAppearance(named: .darkAqua)!
        case .light: NSAppearance(named: .aqua)!
        }
    }

    var material: NSVisualEffectView.Material {
        switch self {
        case .dark:  .hudWindow
        case .light: .sheet
        }
    }
}

// MARK: - Paste Mode

/// How transcribed text is inserted.
enum PasteMode: String, CaseIterable, Identifiable {
    case paste   // Replace clipboard and paste
    case append  // Append to current clipboard text and paste

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .paste:  "Replace"
        case .append: "Append"
        }
    }

    var icon: String {
        switch self {
        case .paste:  "doc.on.clipboard"
        case .append: "text.append"
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
    case embedded = "embedded"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .external: "Floating Pill"
        case .embedded: "Inside Card"
        }
    }

    var icon: String {
        switch self {
        case .external: "capsule"
        case .embedded: "rectangle.inset.filled"
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
    @Published var recordingStatus: RecordingStatus = .idle
    @Published var recordingDuration: TimeInterval = 0
    @Published var livePreviewText: String = ""

    // MARK: App Storage Preferences

    @AppStorage("selectedLanguage") var selectedLanguage: String = "auto"
    @AppStorage("selectedUILanguage") var selectedUILanguage: String = "auto"
    @AppStorage("selectedModel") var selectedModel: String = "openai_whisper-small"

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
    @AppStorage("autoTranslate") var autoTranslate: Bool = false

    /// Computed property for type-safe theme access.
    var selectedTheme: AppTheme {
        get { AppTheme(rawValue: selectedThemeRaw) ?? .aurora }
        set { selectedThemeRaw = newValue.rawValue }
    }

    /// Computed property for type-safe overlay style access.
    var selectedOverlayStyle: OverlayStyle {
        get { OverlayStyle(rawValue: selectedOverlayStyleRaw) ?? .waveform }
        set { selectedOverlayStyleRaw = newValue.rawValue }
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
        set { selectedPanelAppearanceRaw = newValue.rawValue }
    }

    /// Computed property for type-safe subtitle background access.
    var livePreviewBackground: SubtitleBackground {
        get { SubtitleBackground(rawValue: livePreviewBackgroundRaw) ?? .glass }
        set { livePreviewBackgroundRaw = newValue.rawValue }
    }

    @AppStorage("livePreviewMode") var livePreviewModeRaw: String = LivePreviewMode.external.rawValue

    /// Computed property for type-safe live preview mode access.
    var livePreviewMode: LivePreviewMode {
        get { LivePreviewMode(rawValue: livePreviewModeRaw) ?? .external }
        set { livePreviewModeRaw = newValue.rawValue }
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

    @AppStorage("hasCompletedFirstLaunchSetup") private var hasCompletedFirstLaunchSetup: Bool = false

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

        Task {
            do {
                logger.info("Starting transcription with model=\(self.selectedModel), lang=\(self.selectedLanguage)…")
                let langParam = self.selectedLanguage == "auto" ? nil : self.selectedLanguage
                let text = try await transcriptionService.transcribe(
                    audioURL: audioURL,
                    modelName: self.selectedModel,
                    language: langParam,
                    autoTranslate: self.autoTranslate
                )
                logger.info("Transcription result: '\(text)'")

                if text.isEmpty {
                    logger.warning("Transcription returned empty text")
                    recordingStatus = .error("No speech")
                    try? await Task.sleep(for: .seconds(1.5))
                    hidePanel()
                } else {
                    // Use selected paste mode
                    switch self.selectedPasteMode {
                    case .paste:  PasteService.copyToClipboard(text)
                    case .append: PasteService.appendToClipboard(text)
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

                    logger.info("Text copied to clipboard, simulating paste…")

                    // Brief delay so the user sees the checkmark, then paste
                    try? await Task.sleep(for: .milliseconds(400))
                    PasteService.simulatePaste()

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

        let isEmbedded = livePreviewEnabled && livePreviewMode == .embedded && !livePreviewText.isEmpty
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
        guard let panel = recordingPanel, isRecording else { return }
        guard livePreviewEnabled, livePreviewMode == .embedded else { return }

        let isEmbedded = !livePreviewText.isEmpty
        let newSize = RecordingPanel.size(
            for: selectedOverlayStyle,
            overlaySize: selectedOverlaySize,
            isEmbeddedPreviewActive: isEmbedded,
            previewTextLength: livePreviewText.count
        )

        let overlay = RecordingOverlayView().environmentObject(self)
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
                guard let self = self, !self.isRecording && !self.isTranscribing else { return }
                let level = Float.random(in: 0.25...0.65)
                withAnimation(.linear(duration: 0.08)) {
                    self.audioLevel = level
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

    private func targetPreviewOrigin(for style: OverlayStyle, size: NSSize) -> NSPoint {
        guard let screen = NSScreen.main else { return .zero }
        let screenFrame = screen.visibleFrame

        if (style == .classic || style == .orb), let settingsFrame = SettingsWindowManager.shared.windowFrame {
            let preferredX = settingsFrame.maxX + 24
            let maxAllowedX = screenFrame.maxX - size.width - 20
            let x = min(preferredX, maxAllowedX)
            let preferredY = settingsFrame.midY - size.height / 2
            let y = max(screenFrame.minY + 20, min(preferredY, screenFrame.maxY - size.height - 20))
            return NSPoint(x: x, y: y)
        } else {
            let x = screenFrame.midX - size.width / 2
            let y = screenFrame.minY + 60
            return NSPoint(x: x, y: y)
        }
    }

    func updateSettingsPreviewPanel() {
        guard !isRecording && !isTranscribing else { return }

        let overlay = RecordingOverlayView()
            .environmentObject(self)

        let isEmbeddedActive = livePreviewEnabled && livePreviewMode == .embedded && !livePreviewText.isEmpty
        let targetSize = RecordingPanel.size(
            for: selectedOverlayStyle,
            overlaySize: selectedOverlaySize,
            isEmbeddedPreviewActive: isEmbeddedActive,
            previewTextLength: livePreviewText.count
        )
        let targetRadius = RecordingPanel.radius(for: selectedOverlayStyle, overlaySize: selectedOverlaySize)
        let targetOrigin = targetPreviewOrigin(for: selectedOverlayStyle, size: targetSize)
        let targetFrame = NSRect(origin: targetOrigin, size: targetSize)

        if let existingPanel = settingsPreviewPanel {
            // Update existing panel in-place without recreation or flashing
            existingPanel.updateAppearance(selectedPanelAppearance)
            existingPanel.setContent(overlay, style: selectedOverlayStyle, overlaySize: selectedOverlaySize, isEmbeddedPreviewActive: isEmbeddedActive, previewTextLength: livePreviewText.count)
            existingPanel.updateCornerRadius(targetRadius)

            let oldFrame = existingPanel.frame
            // Anchor top edge (oldFrame.maxY) so window stretches DOWNWARDS when height expands
            let calculatedY = oldFrame.maxY - targetSize.height
            let calculatedFrame = NSRect(x: targetOrigin.x, y: calculatedY, width: targetSize.width, height: targetSize.height)

            if oldFrame != calculatedFrame {
                NSAnimationContext.runAnimationGroup { ctx in
                    ctx.duration = 0.25
                    ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                    existingPanel.animator().setFrame(calculatedFrame, display: true)
                }
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

            panel.orderFrontRegardless()
            settingsPreviewPanel = panel

            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.35
                ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().alphaValue = 1
                panel.animator().setFrameOrigin(targetOrigin)
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

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.35
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().alphaValue = 0

            let currentFrame = panel.frame
            panel.animator().setFrameOrigin(NSPoint(x: currentFrame.minX, y: currentFrame.minY - 24))
        } completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                panel.close()
                if self?.isRecording == false && self?.isTranscribing == false {
                    self?.audioLevel = 0
                }
            }
        }
    }

    // MARK: - Setup Helpers

    private func setupHotkeyHandler() {
        KeyboardShortcuts.onKeyUp(for: .toggleRecording) { [weak self] in
            Task { @MainActor in
                self?.toggleRecording()
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
        livePreviewTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
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
