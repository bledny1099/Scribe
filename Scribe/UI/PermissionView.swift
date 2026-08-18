import AppKit
import SwiftUI
import Speech
import AVFoundation

// MARK: - Reusable Permissions Card (Matching Liquid Glass Design)

struct PermissionsCard: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var permissionManager = PermissionManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(appState.l("Permissions").uppercased())
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
                .padding(.bottom, 8)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                // Microphone row
                PermissionRow(
                    title: appState.l("Microphone"),
                    icon: "mic.fill",
                    isGranted: permissionManager.isMicrophoneGranted,
                    action: { permissionManager.requestMicrophone() }
                )

                Divider()
                    .padding(.horizontal, 16)

                // Accessibility row
                PermissionRow(
                    title: appState.l("Accessibility"),
                    icon: "hand.raised.fill",
                    isGranted: permissionManager.isAccessibilityGranted,
                    action: { permissionManager.requestAccessibility() }
                )

                Divider()
                    .padding(.horizontal, 16)

                // Speech Recognition row
                PermissionRow(
                    title: appState.l("Speech Recognition"),
                    icon: "waveform",
                    isGranted: permissionManager.isSpeechRecognitionGranted,
                    action: { permissionManager.requestSpeechRecognition() }
                )
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.primary.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
            )
        }
    }
}

struct PermissionRow: View {
    @EnvironmentObject var appState: AppState
    let title: String
    var description: String? = nil
    let icon: String
    let isGranted: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(isGranted
                        ? Color.green.opacity(0.15)
                        : Color.primary.opacity(0.06)
                    )
                    .frame(width: 32, height: 32)

                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isGranted ? .green : .secondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(appState.l(title))
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.primary)
                if let desc = description {
                    Text(appState.l(desc))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if isGranted {
                HStack(spacing: 5) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.green)

                    Text(appState.l("Granted"))
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .transition(.scale.combined(with: .opacity))
            } else {
                Button(appState.l("Grant Access")) {
                    action()
                }
                .buttonStyle(GlassButtonStyle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isGranted)
    }
}

struct PermissionWindowSizePreferenceKey: PreferenceKey {
    static let defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

// MARK: - Onboarding Permission Window Content

struct PermissionWelcomeView: View {
    enum OnboardingStep {
        case permissions
        case customization
        case voiceTest
        case profile
    }

    @EnvironmentObject var appState: AppState
    @ObservedObject var permissionManager = PermissionManager.shared
    @State private var showingSupportModal = false
    @State private var currentStep: OnboardingStep = .permissions
    
    // Voice Test State
    @State private var isTestingVoice = false
    @State private var voiceTestText = "Click 'Start Test' and say \"Testing microphone for Scribe\""
    @State private var voiceTestSuccess = false
    
    @State private var engine = AVAudioEngine()
    @State private var request = SFSpeechAudioBufferRecognitionRequest()
    @State private var task: SFSpeechRecognitionTask?
    @StateObject private var previewRecorder = AudioRecorder()

    var onComplete: (() -> Void)? = nil

    private var windowWidth: CGFloat {
        return 460
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Welcome")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 56)
            .padding(.bottom, 8)

            // Scrollable Content
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    if currentStep == .permissions {
                    // App Introduction Section
                    GlassSection(title: "About Scribe", icon: "waveform") {
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.blue, Color.purple],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 52, height: 52)

                                Image(systemName: "waveform")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                            .shadow(color: .blue.opacity(0.3), radius: 10, y: 4)

                            Text("Scribe converts your speech to text and automatically pastes it into your active app via ⌘V.")
                                .font(.system(size: 13, weight: .regular))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity)
                    }

                    // Permissions Section
                    GlassSection(title: "Required Permissions", icon: "lock.shield") {
                        VStack(spacing: 0) {
                            PermissionRow(
                                title: "Microphone",
                                description: "Required to record your speech for transcription.",
                                icon: "mic.fill",
                                isGranted: permissionManager.isMicrophoneGranted,
                                action: { permissionManager.requestMicrophone() }
                            )

                            Divider()
                                .padding(.horizontal, 16)

                            PermissionRow(
                                title: "Accessibility",
                                description: "Needed to simulate ⌘V and paste text into other apps.",
                                icon: "hand.raised.fill",
                                isGranted: permissionManager.isAccessibilityGranted,
                                action: { permissionManager.requestAccessibility() }
                            )
                            
                            Divider()
                                .padding(.horizontal, 16)

                            PermissionRow(
                                title: "Speech Recognition",
                                description: "Used by the native Apple engine for fast offline dictation.",
                                icon: "waveform",
                                isGranted: permissionManager.isSpeechRecognitionGranted,
                                action: { permissionManager.requestSpeechRecognition() }
                            )
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.primary.opacity(0.03))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
                        )
                    }

                    // Support Developer Button
                    Button(action: {
                        showingSupportModal = true
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "heart.fill")
                                .foregroundStyle(.pink)
                            Text("Support Scribe ☕️")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(.primary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.ultraThinMaterial)
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.primary.opacity(0.04))
                            }
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Color.primary.opacity(0.15), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .sheet(isPresented: $showingSupportModal) {
                        SupportDeveloperModal()
                    }

                    let allGranted = permissionManager.isMicrophoneGranted && permissionManager.isAccessibilityGranted && permissionManager.isSpeechRecognitionGranted
                    Button(action: {
                        if allGranted {
                            withAnimation {
                                currentStep = .customization
                            }
                        }
                    }) {
                        HStack(spacing: 8) {
                            Text("Continue")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))

                            if allGranted {
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 12, weight: .bold))
                            }
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(
                                        LinearGradient(
                                            colors: allGranted
                                                ? [Color.blue, Color.purple]
                                                : [Color.primary.opacity(0.15), Color.primary.opacity(0.2)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )

                                if allGranted {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    Color.white.opacity(0.25),
                                                    Color.clear,
                                                ],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )
                                }
                            }
                        )
                        .shadow(
                            color: allGranted ? .blue.opacity(0.3) : .clear,
                            radius: 8, y: 4
                        )
                    }
                    .buttonStyle(.plain)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: allGranted)
                    } // end permissions section
                    
                    if currentStep == .customization {
                        GlassSection(title: "Customize Look", icon: "paintbrush.fill") {
                            VStack(spacing: 16) {
                                Text("Choose how you want Scribe to look when recording.")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                
                                // Theme picker
                                HStack(alignment: .top, spacing: 14) {
                                    ForEach(AppTheme.allCases) { theme in
                                        ThemeSwatchButton(
                                            theme: theme,
                                            isSelected: appState.selectedTheme == theme
                                        ) {
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                appState.selectedTheme = theme
                                                appState.onThemeChangedPreview()
                                            }
                                        }
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                
                                // Overlay style picker
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(appState.l("Overlay Style"))
                                        .font(.system(size: 14, weight: .medium, design: .rounded))
                                        .foregroundStyle(.primary)
                                    LiquidGlassSegmentedPicker(
                                        items: OverlayStyle.allCases,
                                        selection: Binding(
                                            get: { appState.selectedOverlayStyle },
                                            set: { appState.selectedOverlayStyle = $0; appState.showSettingsPreviewFor5Seconds() }
                                        ),
                                        label: { ("", $0.icon) }
                                    )
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                
                                // Panel appearance picker
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(appState.l("Panel Appearance"))
                                        .font(.system(size: 14, weight: .medium, design: .rounded))
                                        .foregroundStyle(.primary)
                                    LiquidGlassSegmentedPicker(
                                        items: PanelAppearance.allCases,
                                        selection: Binding(
                                            get: { appState.selectedPanelAppearance },
                                            set: { appState.selectedPanelAppearance = $0; appState.showSettingsPreviewFor5Seconds() }
                                        ),
                                        label: { (appState.l($0.displayName), $0.icon) }
                                    )
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                
                                // Live Preview
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(appState.l("Live Preview"))
                                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                                .foregroundStyle(.primary)
                                            Text(appState.l("Shows intermediate text while recording"))
                                                .font(.system(size: 11))
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        let supportsLivePreview = appState.selectedOverlayStyle.supportsEmbeddedPreview
                                        Toggle("", isOn: Binding(
                                            get: { supportsLivePreview ? appState.livePreviewEnabled : false },
                                            set: { newValue in
                                                guard supportsLivePreview else { return }
                                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                    appState.livePreviewEnabled = newValue
                                                }
                                                DispatchQueue.main.async {
                                                    if newValue {
                                                        appState.showSettingsPreviewFor5Seconds()
                                                    } else {
                                                        appState.hideSettingsPreviewPanel()
                                                    }
                                                }
                                            }
                                        ))
                                        .toggleStyle(.switch)
                                        .labelsHidden()
                                        .allowsHitTesting(supportsLivePreview)
                                        .opacity(supportsLivePreview ? 1.0 : 0.5)
                                    }
                                    
                                    if !appState.selectedOverlayStyle.supportsEmbeddedPreview {
                                        HStack(spacing: 6) {
                                            Image(systemName: "info.circle")
                                                .font(.system(size: 11, weight: .medium))
                                                .foregroundStyle(.secondary)
                                            Text(appState.l("Live Preview is only available for Waveform and Pulse"))
                                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                                .foregroundStyle(.secondary)
                                        }
                                        .padding(.top, 4)
                                    }
                                    

                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                
                            }
                        }
                        
                        Button(action: {
                            withAnimation {
                                currentStep = .voiceTest
                            }
                        }) {
                            HStack(spacing: 8) {
                                Text("Continue")
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 12, weight: .bold))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(LinearGradient(colors: [Color.blue, Color.purple], startPoint: .leading, endPoint: .trailing))
                            )
                            .shadow(color: .blue.opacity(0.3), radius: 8, y: 4)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    if currentStep == .voiceTest {
                        GlassSection(title: "Voice Test", icon: "mic.fill") {
                            VStack(spacing: 20) {
                                ZStack {
                                    Circle()
                                        .fill(isTestingVoice ? Color.blue.opacity(0.15) : Color.primary.opacity(0.05))
                                        .frame(width: 80, height: 80)
                                    
                                    if voiceTestSuccess {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 40))
                                            .foregroundStyle(.green)
                                    } else {
                                        Image(systemName: isTestingVoice ? "waveform" : "mic.fill")
                                            .font(.system(size: 30))
                                            .foregroundStyle(isTestingVoice ? .blue : .secondary)
                                            
                                    }
                                }
                                
                                Text(voiceTestText)
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundStyle(.primary)
                                    .multilineTextAlignment(.center)
                                    .frame(minHeight: 40)
                                
                                if !voiceTestSuccess {
                                    Button(action: {
                                        if isTestingVoice {
                                            stopVoiceTest()
                                            isTestingVoice = false
                                        } else {
                                            startVoiceTest()
                                        }
                                    }) {
                                        Text(isTestingVoice ? "Stop Test" : "Start Test")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 20)
                                            .padding(.vertical, 8)
                                            .background(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(isTestingVoice ? Color.red : Color.blue)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                        }
                        
                        Button(action: {
                            if isTestingVoice {
                                stopVoiceTest()
                            }
                            withAnimation {
                                currentStep = .profile
                            }
                        }) {
                            HStack(spacing: 8) {
                                Text("Continue")
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 12, weight: .bold))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(LinearGradient(colors: [Color.blue, Color.purple], startPoint: .leading, endPoint: .trailing))
                            )
                            .shadow(color: .blue.opacity(0.3), radius: 8, y: 4)
                            .opacity(voiceTestSuccess ? 1.0 : 0.5)
                        }
                        .buttonStyle(.plain)
                        .disabled(!voiceTestSuccess)
                    }
                    
                    if currentStep == .profile {
                        GlassSection(title: appState.l("Profile"), icon: "person.circle.fill") {
                            VStack(spacing: 16) {
                                Text(appState.l("What should we call you?"))
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundStyle(.primary)
                                
                                TextField(appState.l("Your Name or Nickname"), text: $appState.userName)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(size: 14, design: .rounded))
                            }
                            .padding(.vertical, 10)
                        }
                        
                        Button(action: {
                            let clean = appState.userName.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !clean.isEmpty {
                                UserDefaults.standard.set(clean, forKey: "userName")
                                UserDefaults.standard.set(true, forKey: "hasCompletedFirstLaunchSetup")
                                UserDefaults.standard.set(true, forKey: "hasCompletedOnboardingNamePrompt")
                                Task {
                                    try? await AuthService.shared.updateDisplayName(clean)
                                }
                            }
                            if let onComplete = onComplete {
                                onComplete()
                            } else {
                                PermissionWindowManager.shared.closeWindow()
                            }
                        }) {
                            HStack(spacing: 8) {
                                Text(appState.l("Get Started"))
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(LinearGradient(colors: [Color.blue, Color.purple], startPoint: .leading, endPoint: .trailing))
                            )
                            .shadow(color: .blue.opacity(0.3), radius: 8, y: 4)
                            .opacity(appState.userName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1.0)
                        }
                        .buttonStyle(.plain)
                        .disabled(appState.userName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(key: PermissionWindowSizePreferenceKey.self, value: CGSize(width: windowWidth, height: geo.size.height))
                    }
                )
            }
        }
        .onPreferenceChange(PermissionWindowSizePreferenceKey.self) { size in
            // The total height is the scrollview content height (size.height) + header height (108) + bottom padding (24) + safe area.
            let totalHeight = size.height + 180
            PermissionWindowManager.shared.animateToSize(CGSize(width: size.width, height: totalHeight))
        }
        .ignoresSafeArea(.container, edges: .top)
        .frame(width: windowWidth)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: windowWidth)
        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
        .onAppear {
            // Force a fresh permission check when the view appears
            permissionManager.checkPermissions()
        }
    }
    
    private func startVoiceTest() {
        isTestingVoice = true
        voiceTestText = "Listening..."
        
        let recognizer = SFSpeechRecognizer()
        let req = SFSpeechAudioBufferRecognitionRequest()
        self.request = req
        
        if engine.isRunning {
            engine.stop()
        }
        
        let node = engine.inputNode
        node.removeTap(onBus: 0)
        
        let recordingFormat = node.outputFormat(forBus: 0)
        
        guard recordingFormat.channelCount > 0 else {
            isTestingVoice = false
            voiceTestText = "Microphone format unsupported."
            return
        }
        
        node.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { @Sendable buffer, _ in
            req.append(buffer)
        }
        
        engine.prepare()
        do {
            try engine.start()
            task = recognizer?.recognitionTask(with: request) { result, error in
                if let result = result {
                    let text = result.bestTranscription.formattedString
                    DispatchQueue.main.async {
                        if !text.isEmpty {
                            self.voiceTestText = text
                        }
                        if text.count > 10 {
                            if !self.voiceTestSuccess {
                                self.voiceTestSuccess = true
                                self.isTestingVoice = false
                                self.voiceTestText = "Perfect! Your mic is working."
                                self.stopVoiceTest()
                            }
                        }
                    }
                }
                
                if let error = error {
                    DispatchQueue.main.async {
                        if !self.voiceTestSuccess {
                            self.isTestingVoice = false
                            self.voiceTestText = "Testing failed: \(error.localizedDescription)"
                            self.stopVoiceTest()
                        }
                    }
                }
            }
        } catch {
            isTestingVoice = false
            voiceTestText = "Failed to start audio engine."
        }
    }
    
    private func stopVoiceTest() {
        if engine.isRunning {
            engine.stop()
            engine.inputNode.removeTap(onBus: 0)
            request.endAudio()
        }
        task?.cancel()
        task = nil
    }
}

// MARK: - Permission Window Manager

@MainActor
final class PermissionWindowManager {
    static let shared = PermissionWindowManager()

    var window: NSWindow?
    private var appState: AppState?
    
    var windowFrame: NSRect? { window?.frame }

    func ensureMinimumY(_ minY: CGFloat) {
        guard let win = window else { return }
        let currentFrame = win.frame
        if currentFrame.minY < minY {
            var newFrame = currentFrame
            newFrame.origin.y = minY
            win.setFrame(newFrame, display: true, animate: true)
        }
    }

    func animateToSize(_ size: CGSize) {
        guard let window = window else { return }
        
        let screenMaxY = window.screen?.visibleFrame.maxY ?? NSScreen.main?.visibleFrame.maxY ?? 1000
        // Constrain height
        let newHeight = min(size.height, 800)
        
        let currentFrame = window.frame
        let newX = currentFrame.midX - (size.width / 2)
        // Keep the top edge anchored if possible, or center it
        let newY = currentFrame.maxY - newHeight
        
        let newFrame = NSRect(x: newX, y: newY, width: size.width, height: newHeight)
        
        // Always apply the frame so it's guaranteed to be correct
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.35
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().setFrame(newFrame, display: true)
        }
    }

    func showWindow(appState: AppState? = nil) {
        if let appState = appState {
            self.appState = appState
        }

        if let existing = window {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 720),
            styleMask: [.titled, .fullSizeContentView, .closable],
            backing: .buffered,
            defer: false
        )

        newWindow.titlebarAppearsTransparent = true
        newWindow.titleVisibility = .hidden
        newWindow.standardWindowButton(.closeButton)?.isHidden = true
        newWindow.standardWindowButton(.miniaturizeButton)?.isHidden = true
        newWindow.standardWindowButton(.zoomButton)?.isHidden = true

        newWindow.isMovableByWindowBackground = true
        newWindow.isOpaque = false
        newWindow.backgroundColor = .clear
        newWindow.hasShadow = true
        newWindow.level = .normal
        newWindow.hidesOnDeactivate = false
        newWindow.isReleasedWhenClosed = false
        newWindow.center()

        // Blur background — same as Settings window
        let blurView = NSVisualEffectView()
        blurView.material = .popover
        blurView.blendingMode = .behindWindow
        blurView.state = .active

        newWindow.delegate = PermissionWindowDelegate.shared

        let welcomeView = PermissionWelcomeView(onComplete: { [weak self] in
            guard let self = self else { return }
            let state = self.appState
            self.closeWindow()
            if let state = state {
                SettingsWindowManager.shared.showSettings(appState: state)
            }
        })
        
        let hostingView = appState != nil ? NSHostingView(rootView: welcomeView.environmentObject(appState!)) : NSHostingView(rootView: welcomeView.environmentObject(AppState()))
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor

        blurView.addSubview(hostingView)
        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: blurView.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: blurView.bottomAnchor),
            hostingView.leadingAnchor.constraint(equalTo: blurView.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: blurView.trailingAnchor),
        ])

        newWindow.contentView = blurView

        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.window = newWindow
    }

    func closeWindow() {
        window?.close()
        window = nil
    }

    var currentAppState: AppState? {
        return appState
    }
    
    func windowDidMove() {
        currentAppState?.updateSettingsPreviewPanel(isDragging: true)
    }
}

@MainActor
private class PermissionWindowDelegate: NSObject, NSWindowDelegate, @unchecked Sendable {
    static let shared = PermissionWindowDelegate()

    func windowDidMove(_ notification: Notification) {
        PermissionWindowManager.shared.windowDidMove()
    }
}
