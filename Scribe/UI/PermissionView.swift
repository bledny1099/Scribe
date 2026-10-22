import AppKit
import SwiftUI
import Speech
import AVFoundation
import KeyboardShortcuts

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

            HStack {
                Spacer()
                Button {
                    permissionManager.resetPermissionsCache()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 10, weight: .semibold))
                        Text(appState.l("Reset Permissions Cache"))
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(Color.primary.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .help(appState.l("Flushes macOS TCC cache if permissions get out of sync"))
            }
            .padding(.top, 8)
            .padding(.trailing, 2)
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
    enum OnboardingStep: Int, CaseIterable {
        case permissions = 0
        case dictation = 1
        case vocabularyAndAI = 2
        case customization = 3
        case profileAndTest = 4

        var titleKey: String {
            switch self {
            case .permissions:     return "Welcome"
            case .dictation:       return "Dictation & Engine"
            case .vocabularyAndAI: return "Smart Vocabulary & AI"
            case .customization:   return "Customize Look"
            case .profileAndTest:  return "Profile & Mic Check"
            }
        }

        var icon: String {
            switch self {
            case .permissions:     return "lock.shield.fill"
            case .dictation:       return "waveform.and.mic"
            case .vocabularyAndAI: return "wand.and.stars"
            case .customization:   return "paintbrush.fill"
            case .profileAndTest:  return "person.crop.circle.badge.checkmark"
            }
        }
    }

    @EnvironmentObject var appState: AppState
    @ObservedObject var permissionManager = PermissionManager.shared
    @ObservedObject var habitMonitor = PersonalVocabularyMonitor.shared
    @State private var showingSupportModal = false
    @State private var currentStep: OnboardingStep = .permissions
    @State private var launchAtLogin: Bool = LaunchAtLoginHelper.isEnabled

    // AI Gateway Auto-Detect Input State
    @State private var gatewayKeyInput: String = ""
    @State private var isGatewayKeyVisible: Bool = false

    // Sandbox local profile state for test runs so real UserDefaults are untouched
    @State private var testUserName: String = ""
    @State private var testCityLocation: String = ""

    // Voice Test State
    @State private var isTestingVoice = false
    @State private var voiceTestTranscript = ""
    @State private var voiceTestError: String? = nil
    @State private var voiceTestSuccess = false
    @State private var voiceTestSkipped = false
    @State private var voiceTestLevel: Float = 0

    @State private var engine = AVAudioEngine()
    @State private var request = SFSpeechAudioBufferRecognitionRequest()
    @State private var task: SFSpeechRecognitionTask?

    var isTestRun: Bool = false
    var onComplete: (() -> Void)? = nil

    private var windowWidth: CGFloat {
        return 540
    }

    private var isLightAppearance: Bool {
        appState.selectedPanelAppearance == .light
    }

    private var isWhiteTheme: Bool {
        appState.selectedTheme == .whiteGlow
    }

    /// High-contrast accent color for text, icons, borders, and pill backgrounds across all themes and panel appearances.
    private var uiAccentColor: Color {
        if isWhiteTheme {
            return isLightAppearance ? Color(white: 0.14) : Color.white
        }
        return appState.selectedTheme.gradientColors.first ?? .blue
    }

    /// Foreground color for text/icons placed directly on top of a solid `uiAccentColor` or `uiAccentGradient` fill.
    private var uiOnAccentColor: Color {
        if isWhiteTheme {
            return isLightAppearance ? Color.white : Color(white: 0.12)
        }
        return Color.white
    }

    /// Gradient for active progress step and hero badge that remains high-contrast in all themes and panel appearances.
    private var uiAccentGradient: LinearGradient {
        if isWhiteTheme && isLightAppearance {
            return LinearGradient(
                colors: [Color(white: 0.14), Color(white: 0.28)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        return appState.selectedTheme.accentGradient
    }

    private var themeGlow: Color { appState.selectedTheme.glowColor }

    private var allPermissionsGranted: Bool {
        permissionManager.isMicrophoneGranted &&
        permissionManager.isAccessibilityGranted &&
        permissionManager.isSpeechRecognitionGranted
    }

    private var activeUserNameBinding: Binding<String> {
        isTestRun ? $testUserName : $appState.userName
    }

    private var activeCityLocationBinding: Binding<String> {
        isTestRun ? $testCityLocation : $appState.userCityLocation
    }

    private var detectedGatewayProvider: CloudAIProvider? {
        CloudAIProvider.detect(fromAPIKey: gatewayKeyInput)
    }

    private func commitPendingGatewayKeyIfNeeded() {
        let trimmed = gatewayKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let provider = CloudAIProvider.detect(fromAPIKey: trimmed) ?? .groq
        appState.addGatewayKey(provider: provider, apiKey: trimmed)
        appState.cloudAIProvider = provider
        gatewayKeyInput = ""
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            SettingsBackgroundView(
                panelAppearance: appState.selectedPanelAppearance,
                selectedTab: .general,
                levelColor: .blue,
                previousLevelColor: .blue,
                isLevelUpSweepActive: false,
                sweepProgress: 1.0
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(spacing: 0) {
                // Test Mode Banner (only shown when launched in sandbox test mode)
                if isTestRun {
                    HStack(spacing: 8) {
                        HStack(spacing: 5) {
                            Image(systemName: "flask.fill")
                                .font(.system(size: 10, weight: .bold))
                            Text(appState.l("Test Mode").uppercased())
                                .font(.system(size: 10, weight: .heavy, design: .rounded))
                        }
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.orange.opacity(0.16)))
                        .overlay(Capsule().stroke(Color.orange.opacity(0.35), lineWidth: 0.8))

                        Text(appState.l("Changes revert on exit"))
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        Spacer(minLength: 4)

                        Button(action: {
                            if isTestingVoice { stopVoiceTest() }
                            PermissionWindowManager.shared.closeWindow()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 9, weight: .bold))
                                Text(appState.l("Exit Test"))
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                            }
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.primary.opacity(0.08)))
                            .overlay(Capsule().stroke(Color.primary.opacity(0.15), lineWidth: 0.8))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 36)
                    .padding(.bottom, 4)
                }

                // Header with Back button and Step Title
                HStack(spacing: 10) {
                    if currentStep != .permissions {
                        Button(action: {
                            if isTestingVoice { stopVoiceTest() }
                            commitPendingGatewayKeyIfNeeded()
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                if let prev = OnboardingStep(rawValue: currentStep.rawValue - 1) {
                                    currentStep = prev
                                }
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 11, weight: .bold))
                                Text(appState.l("Back"))
                                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                            }
                            .foregroundStyle(uiAccentColor)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(uiAccentColor.opacity(0.12)))
                            .overlay(Capsule().stroke(uiAccentColor.opacity(0.28), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        Text(appState.l(currentStep.titleKey))
                            .font(.system(size: 19, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                        Text(String(format: appState.l("Step %d of %d"), currentStep.rawValue + 1, OnboardingStep.allCases.count))
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, isTestRun ? 8 : 44)
                .padding(.bottom, 10)

                // Interactive 5-Step Progress Bar
                HStack(spacing: 6) {
                    ForEach(OnboardingStep.allCases, id: \.rawValue) { step in
                        let isCompleted = step.rawValue < currentStep.rawValue
                        let isCurrent = step == currentStep
                        let canJump = isTestRun || allPermissionsGranted || step.rawValue <= currentStep.rawValue

                        Button {
                            guard canJump else { return }
                            if isTestingVoice { stopVoiceTest() }
                            commitPendingGatewayKeyIfNeeded()
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                currentStep = step
                            }
                        } label: {
                            Capsule()
                                .fill(
                                    isCurrent
                                        ? uiAccentGradient
                                        : (isCompleted
                                            ? LinearGradient(colors: [uiAccentColor.opacity(0.55), uiAccentColor.opacity(0.4)], startPoint: .leading, endPoint: .trailing)
                                            : LinearGradient(colors: [Color.primary.opacity(0.12), Color.primary.opacity(0.12)], startPoint: .leading, endPoint: .trailing))
                                )
                                .overlay(
                                    Capsule()
                                        .strokeBorder(
                                            isCurrent && isWhiteTheme && !isLightAppearance
                                                ? Color.white.opacity(0.45)
                                                : Color.clear,
                                            lineWidth: 0.5
                                        )
                                )
                                .frame(height: 5)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.plain)
                        .disabled(!canJump)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 12)

                // Step Content
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 12) {
                        switch currentStep {
                        case .permissions:
                            permissionsStepView
                        case .dictation:
                            dictationStepView
                        case .vocabularyAndAI:
                            vocabularyAndAIStepView
                        case .customization:
                            customizationStepView
                        case .profileAndTest:
                            profileAndTestStepView
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 8)
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(
                                key: PermissionWindowSizePreferenceKey.self,
                                value: CGSize(width: windowWidth, height: geo.size.height)
                            )
                        }
                    )
                }

                // Pinned Bottom Action Footer (always visible without scrolling)
                bottomActionFooter
                    .padding(.horizontal, 24)
                    .padding(.top, 6)
                    .padding(.bottom, 18)
            }
        }
        .onPreferenceChange(PermissionWindowSizePreferenceKey.self) { size in
            let headerAndFooterExtra: CGFloat = isTestRun ? 215 : 185
            let totalHeight = size.height + headerAndFooterExtra
            PermissionWindowManager.shared.animateToSize(CGSize(width: size.width, height: totalHeight))
        }
        .ignoresSafeArea(.container, edges: .top)
        .frame(width: windowWidth)
        .preferredColorScheme(
            appState.selectedPanelAppearance == .light ? .light : .dark
        )
        .onChange(of: appState.selectedPanelAppearance) { newAppearance in
            PermissionWindowManager.shared.updateWindowAppearance(newAppearance)
        }
        .onChange(of: currentStep) { newStep in
            if newStep != .customization {
                appState.hideSettingsPreviewPanel()
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.82), value: currentStep)
        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
        .onAppear {
            permissionManager.checkPermissions()
            launchAtLogin = LaunchAtLoginHelper.isEnabled
            PermissionWindowManager.shared.updateWindowAppearance(appState.selectedPanelAppearance)
        }
        .sheet(isPresented: $showingSupportModal, onDismiss: {
            if currentStep == .permissions {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                    currentStep = .dictation
                }
            }
        }) {
            SupportDeveloperModal(
                customTitle: appState.l("Please support the project"),
                onContinue: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                        currentStep = .dictation
                    }
                }
            )
            .environmentObject(appState)
        }
        .overlay {
            if let celebration = appState.supporterCelebrationData {
                SupporterCelebrationOverlayView(
                    data: celebration,
                    onDismiss: {
                        withAnimation(.easeInOut(duration: 0.35)) {
                            appState.supporterCelebrationData = nil
                        }
                    }
                )
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.95)),
                    removal: .opacity.combined(with: .scale(scale: 1.03))
                ))
                .zIndex(9999)
            }
        }
    }

    // MARK: - Pinned Bottom Action Footer

    @ViewBuilder
    private var bottomActionFooter: some View {
        switch currentStep {
        case .permissions:
            let canProceed = allPermissionsGranted || isTestRun
            primaryContinueButton(enabled: canProceed) {
                showingSupportModal = true
            }
        case .dictation:
            primaryContinueButton(enabled: true) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                    currentStep = .vocabularyAndAI
                }
            }
        case .vocabularyAndAI:
            primaryContinueButton(enabled: true) {
                commitPendingGatewayKeyIfNeeded()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                    currentStep = .customization
                }
            }
        case .customization:
            primaryContinueButton(enabled: true) {
                appState.hideSettingsPreviewPanel()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                    currentStep = .profileAndTest
                }
            }
        case .profileAndTest:
            let currentName = activeUserNameBinding.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines)
            let canFinish = !currentName.isEmpty || isTestRun
            primaryFinishButton(enabled: canFinish) {
                if isTestingVoice {
                    stopVoiceTest()
                }
                if !isTestRun {
                    let clean = appState.userName.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !clean.isEmpty {
                        UserDefaults.standard.set(clean, forKey: "userName")
                        UserDefaults.standard.set(true, forKey: "hasCompletedFirstLaunchSetup")
                        UserDefaults.standard.set(true, forKey: "hasCompletedOnboardingNamePrompt")
                        Task {
                            try? await AuthService.shared.updateDisplayName(clean)
                        }
                    }
                }
                if let onComplete = onComplete {
                    onComplete()
                } else {
                    PermissionWindowManager.shared.closeWindow()
                }
            }
        }
    }

    // MARK: - Step 1: Permissions & Intro

    private var permissionsStepView: some View {
        VStack(spacing: 12) {
            GlassSection(title: appState.l("About Scribe"), icon: "waveform") {
                HStack(spacing: 14) {
                    Image(nsImage: NSApp.applicationIconImage ?? NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath))
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 48, height: 48)
                        .shadow(color: .black.opacity(0.22), radius: 6, y: 3)

                    Text(appState.l("Scribe converts your speech to text and types it directly into your active app."))
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 0)
                }
            }

            GlassSection(title: appState.l("Required Permissions"), icon: "lock.shield") {
                VStack(spacing: 0) {
                    PermissionRow(
                        title: "Microphone",
                        icon: "mic.fill",
                        isGranted: permissionManager.isMicrophoneGranted,
                        action: { permissionManager.requestMicrophone() }
                    )

                    Divider().padding(.horizontal, 16)

                    PermissionRow(
                        title: "Accessibility",
                        icon: "hand.raised.fill",
                        isGranted: permissionManager.isAccessibilityGranted,
                        action: { permissionManager.requestAccessibility() }
                    )

                    Divider().padding(.horizontal, 16)

                    PermissionRow(
                        title: "Speech Recognition",
                        icon: "waveform",
                        isGranted: permissionManager.isSpeechRecognitionGranted,
                        action: { permissionManager.requestSpeechRecognition() }
                    )

                    Divider().padding(.horizontal, 16)

                    PermissionRow(
                        title: "Apple Notes (Optional)",
                        icon: "apple.logo",
                        isGranted: permissionManager.isAppleNotesGranted,
                        action: { permissionManager.requestAppleNotes() }
                    )
                }
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(0.03)))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5))
            }

            // Launch at Login row
            HStack(spacing: 10) {
                Image(systemName: "power.circle.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(uiAccentColor)

                Text(appState.l("Launch at Login"))
                    .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)

                Spacer()

                Toggle("", isOn: Binding(
                    get: { launchAtLogin },
                    set: { newValue in
                        launchAtLogin = newValue
                        LaunchAtLoginHelper.setEnabled(newValue)
                    }
                ))
                .toggleStyle(.switch)
                .labelsHidden()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(0.035)))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.primary.opacity(0.08), lineWidth: 1))
        }
    }

    // MARK: - Step 2: Dictation & Engine

    private var dictationStepView: some View {
        VStack(spacing: 12) {
            GlassSection(title: appState.l("Dictation & Engine"), icon: "waveform.and.mic") {
                VStack(spacing: 14) {
                    // Global Hotkey Recorder
                    HStack {
                        Text(appState.l("Global Hotkey"))
                            .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary)
                        Spacer()
                        KeyboardShortcuts.Recorder(for: .toggleRecording)
                    }

                    // Push-to-Talk Toggle
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(appState.l("Push-to-Talk (Hold)"))
                                .font(.system(size: 13.5, weight: .medium, design: .rounded))
                                .foregroundStyle(.primary)
                            Text(appState.l("Hold key to record, release to stop"))
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: $appState.pushToTalk)
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }

                    Divider().padding(.horizontal, 4)

                    // Recognition Engine Picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text(appState.l("Recognition Engine"))
                            .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary)

                        HStack(spacing: 8) {
                            engineOptionCard(
                                title: "Aether Neural",
                                subtitle: appState.l("Offline ANE & GPU • 99+ Languages"),
                                icon: "brain.head.profile",
                                isSelected: !appState.isInstantEngine
                            ) {
                                appState.recognitionEngine = "Aether Neural (Recommended)"
                            }

                            engineOptionCard(
                                title: "Aether Instant",
                                subtitle: appState.l("Apple Speech • English Only"),
                                icon: "bolt.fill",
                                isSelected: appState.isInstantEngine
                            ) {
                                appState.recognitionEngine = "Aether Instant"
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Step 3: Smart Vocabulary & AI

    private var vocabularyAndAIStepView: some View {
        VStack(spacing: 12) {
            GlassSection(title: appState.l("Smart Vocabulary & AI"), icon: "wand.and.stars") {
                VStack(spacing: 12) {
                    // Starter Vocabulary Packs
                    VStack(alignment: .leading, spacing: 8) {
                        Text(appState.l("Starter Vocabulary Packs"))
                            .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary)

                        ForEach(AppState.defaultVocabularyPresets) { preset in
                            let isApplied = isPresetApplied(preset)
                            HStack(spacing: 10) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(isApplied ? Color.green.opacity(0.15) : uiAccentColor.opacity(0.12))
                                        .frame(width: 30, height: 30)
                                    Image(systemName: preset.name.contains("IDE") ? "terminal.fill" : "sparkles")
                                        .font(.system(size: 12.5, weight: .semibold))
                                        .foregroundStyle(isApplied ? .green : uiAccentColor)
                                }

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(appState.l(preset.name))
                                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.primary)
                                    Text("\(preset.words.count) \(appState.l("words"))")
                                        .font(.system(size: 10.5, weight: .medium))
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Button {
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                        togglePresetWords(preset)
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: isApplied ? "checkmark.circle.fill" : "plus.circle.fill")
                                            .font(.system(size: 11, weight: .bold))
                                        Text(isApplied ? appState.l("Added") : appState.l("Add Pack"))
                                            .font(.system(size: 11.5, weight: .bold, design: .rounded))
                                    }
                                    .foregroundStyle(isApplied ? Color.green : uiAccentColor)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(
                                        Capsule()
                                            .fill(isApplied ? Color.green.opacity(0.14) : uiAccentColor.opacity(0.14))
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(9)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.03)))
                            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.primary.opacity(0.08), lineWidth: 1))
                        }
                    }

                    Divider().padding(.horizontal, 4)

                    // Clean Filler Words
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(appState.l("Clean Filler Words"))
                                .font(.system(size: 13.5, weight: .medium, design: .rounded))
                                .foregroundStyle(.primary)
                            Text(appState.l("Removes hesitations (\"uh\", \"um\") and duplicate words"))
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: $appState.cleanFillerWords)
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }

                    // Local Speech Habit Learning
                    HStack {
                        Text(appState.l("Local Speech Habit Learning"))
                            .font(.system(size: 13.5, weight: .medium, design: .rounded))
                            .foregroundStyle(.primary)
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { habitMonitor.isRunning },
                            set: { shouldRun in
                                if shouldRun != habitMonitor.isRunning {
                                    habitMonitor.toggleMonitoring()
                                }
                            }
                        ))
                        .toggleStyle(.switch)
                        .labelsHidden()
                    }

                    Divider().padding(.horizontal, 4)

                    // Optional Cloud AI Polish (AI Gateway with Auto-Detection)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(appState.l("Optional Cloud AI Polish"))
                                .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                                .foregroundStyle(.primary)
                            Spacer()
                            Toggle("", isOn: $appState.enableCloudAI)
                                .toggleStyle(.switch)
                                .labelsHidden()
                        }

                        if appState.enableCloudAI {
                            VStack(alignment: .leading, spacing: 7) {
                                HStack(spacing: 8) {
                                    let activeProvider = detectedGatewayProvider
                                    HStack(spacing: 4) {
                                        Image(systemName: activeProvider?.iconName ?? "wand.and.stars")
                                            .font(.system(size: 10, weight: .semibold))
                                        Text(activeProvider?.shortDisplayName ?? appState.l("Auto"))
                                            .font(.system(size: 10.5, weight: .bold, design: .rounded))
                                    }
                                    .foregroundStyle(activeProvider != nil ? .green : .secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        Capsule()
                                            .fill(activeProvider != nil ? Color.green.opacity(0.14) : Color.primary.opacity(0.06))
                                    )
                                    .overlay(
                                        Capsule()
                                            .strokeBorder(activeProvider != nil ? Color.green.opacity(0.35) : Color.primary.opacity(0.1), lineWidth: 0.8)
                                    )

                                    Group {
                                        if isGatewayKeyVisible {
                                            TextField(appState.l("Paste API key..."), text: $gatewayKeyInput)
                                        } else {
                                            SecureField(appState.l("Paste API key..."), text: $gatewayKeyInput)
                                        }
                                    }
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 12, design: .monospaced))
                                    .onSubmit {
                                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                            commitPendingGatewayKeyIfNeeded()
                                        }
                                    }

                                    Button(action: { isGatewayKeyVisible.toggle() }) {
                                        Image(systemName: isGatewayKeyVisible ? "eye.slash" : "eye")
                                            .font(.system(size: 11))
                                            .foregroundStyle(.secondary)
                                    }
                                    .buttonStyle(.plain)

                                    let canAddKey = !gatewayKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && appState.gatewayKeys.count < 10
                                    Button(action: {
                                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                            commitPendingGatewayKeyIfNeeded()
                                        }
                                    }) {
                                        HStack(spacing: 3) {
                                            Image(systemName: "plus.circle.fill")
                                                .font(.system(size: 10.5, weight: .bold))
                                            Text(appState.l("Add"))
                                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                        }
                                        .foregroundStyle(canAddKey ? uiAccentColor : .secondary.opacity(0.5))
                                        .padding(.horizontal, 9)
                                        .padding(.vertical, 4.5)
                                        .background(
                                            Capsule()
                                                .fill(canAddKey ? uiAccentColor.opacity(0.15) : Color.primary.opacity(0.04))
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(!canAddKey)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(RoundedRectangle(cornerRadius: 9).fill(Color.primary.opacity(0.045)))
                                .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(detectedGatewayProvider != nil ? Color.green.opacity(0.4) : Color.primary.opacity(0.12), lineWidth: 1))

                                if !appState.gatewayKeys.isEmpty {
                                    VStack(spacing: 5) {
                                        ForEach(Array(appState.gatewayKeys.enumerated()), id: \.element.id) { index, key in
                                            HStack(spacing: 8) {
                                                Text("#\(index + 1)")
                                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                                    .foregroundStyle(.secondary)
                                                    .frame(width: 20, alignment: .leading)

                                                Image(systemName: key.providerIcon)
                                                    .font(.system(size: 10.5, weight: .semibold))
                                                    .foregroundStyle(key.isEnabled ? uiAccentColor : .secondary)

                                                Text(key.maskedDisplay)
                                                    .font(.system(size: 11.5, weight: .medium, design: .monospaced))
                                                    .foregroundStyle(key.isEnabled ? .primary : .secondary)

                                                if index == 0 {
                                                    Text(appState.l("Primary"))
                                                        .font(.system(size: 8.5, weight: .semibold, design: .rounded))
                                                        .padding(.horizontal, 5)
                                                        .padding(.vertical, 1.5)
                                                        .background(Capsule().fill(uiAccentColor.opacity(0.14)))
                                                        .foregroundStyle(uiAccentColor)
                                                }

                                                Spacer()

                                                Toggle("", isOn: Binding(
                                                    get: { key.isEnabled },
                                                    set: { _ in appState.toggleGatewayKey(id: key.id) }
                                                ))
                                                .toggleStyle(.switch)
                                                .controlSize(.mini)
                                                .labelsHidden()

                                                Button(action: {
                                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                                        appState.removeGatewayKey(id: key.id)
                                                    }
                                                }) {
                                                    Image(systemName: "trash")
                                                        .font(.system(size: 10.5, weight: .medium))
                                                        .foregroundStyle(.secondary)
                                                        .frame(width: 22, height: 22)
                                                        .background(Color.primary.opacity(0.05))
                                                        .clipShape(RoundedRectangle(cornerRadius: 5))
                                                }
                                                .buttonStyle(.plain)
                                            }
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 5)
                                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.03)))
                                            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.primary.opacity(0.07), lineWidth: 0.8))
                                        }
                                    }
                                }
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                }
            }
        }
    }

    // MARK: - Step 4: Customization

    private var customizationStepView: some View {
        VStack(spacing: 12) {
            GlassSection(title: appState.l("Customize Look"), icon: "paintbrush.fill") {
                VStack(spacing: 12) {
                    // Theme picker (Single clean row of all 6 themes)
                    HStack(spacing: 14) {
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
                    .padding(.vertical, 4)

                    Divider().padding(.horizontal, 4)

                    // Overlay style picker
                    HStack {
                        Text(appState.l("Overlay Style"))
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        LiquidGlassSegmentedPicker(
                            items: OverlayStyle.allCases,
                            selection: Binding(
                                get: { appState.selectedOverlayStyle },
                                set: { appState.selectedOverlayStyle = $0; appState.showSettingsPreviewFor5Seconds() }
                            ),
                            label: { ("", $0.icon) }
                        )
                    }

                    // Overlay size picker
                    HStack {
                        Text(appState.l("Overlay Size"))
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        LiquidGlassSegmentedPicker(
                            items: OverlaySize.allCases,
                            selection: Binding(
                                get: { appState.selectedOverlaySize },
                                set: { appState.selectedOverlaySize = $0; appState.showSettingsPreviewFor5Seconds() }
                            ),
                            label: { (appState.l($0.shortName), $0.icon) }
                        )
                    }

                    // Panel appearance picker
                    HStack {
                        Text(appState.l("Appearance"))
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        LiquidGlassSegmentedPicker(
                            items: PanelAppearance.allCases,
                            selection: Binding(
                                get: { appState.selectedPanelAppearance },
                                set: {
                                    appState.selectedPanelAppearance = $0
                                    appState.selectedOverlayAppearance = $0
                                    appState.showSettingsPreviewFor5Seconds()
                                }
                            ),
                            label: { (appState.l($0.displayName), $0.icon) }
                        )
                    }

                    Divider().padding(.horizontal, 4)

                    // Live Preview
                    HStack {
                        Image(systemName: "text.bubble.fill")
                            .font(.system(size: 13.5, weight: .semibold))
                            .foregroundStyle(uiAccentColor)
                        Text(appState.l("Live Preview"))
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { appState.livePreviewEnabled },
                            set: { newValue in
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
                    }

                    // Sound feedback toggle
                    HStack {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 13.5, weight: .semibold))
                            .foregroundStyle(uiAccentColor)
                        Text(appState.l("Sound Feedback"))
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                        Spacer()
                        Toggle("", isOn: $appState.soundFeedbackEnabled)
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }

                    // Timer toggle
                    HStack {
                        Image(systemName: "timer")
                            .font(.system(size: 13.5, weight: .semibold))
                            .foregroundStyle(uiAccentColor)
                        Text(appState.l("Show Recording Timer"))
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { appState.durationVisible },
                            set: {
                                appState.durationVisible = $0
                                appState.showSettingsPreviewFor5Seconds()
                            }
                        ))
                        .toggleStyle(.switch)
                        .labelsHidden()
                    }

                    // Show target application in overlay toggle
                    HStack {
                        Image(systemName: "macwindow")
                            .font(.system(size: 13.5, weight: .semibold))
                            .foregroundStyle(uiAccentColor)
                        Text(appState.l("Show Target Application"))
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { appState.showTargetAppInOverlay },
                            set: {
                                appState.showTargetAppInOverlay = $0
                                appState.showSettingsPreviewFor5Seconds()
                            }
                        ))
                        .toggleStyle(.switch)
                        .labelsHidden()
                    }
                }
            }
        }
    }

    // MARK: - Step 5: Profile & Mic Check

    private var profileAndTestStepView: some View {
        VStack(spacing: 12) {
            GlassSection(title: appState.l("Profile"), icon: "person.circle.fill") {
                VStack(alignment: .leading, spacing: 10) {
                    Text(appState.l("What should we call you?"))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)

                    // Name Input Box
                    HStack(spacing: 10) {
                        Image(systemName: "person.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(uiAccentColor)

                        TextField(appState.l("Your Name or Nickname"), text: activeUserNameBinding)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13.5, weight: .medium, design: .rounded))
                            .foregroundStyle(.primary)

                        if !activeUserNameBinding.wrappedValue.isEmpty {
                            Button(action: { activeUserNameBinding.wrappedValue = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.045)))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [uiAccentColor.opacity(0.45), Color.primary.opacity(0.12)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )

                    // Optional City / Region Input
                    VStack(alignment: .leading, spacing: 6) {
                        Text(appState.l("Your City or Region (Optional)"))
                            .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary)

                        HStack(spacing: 10) {
                            Image(systemName: "mappin.and.ellipse")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(uiAccentColor)

                            TextField(appState.l("e.g. New York, London, Dubai..."), text: activeCityLocationBinding)
                                .textFieldStyle(.plain)
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(.primary)

                            if !activeCityLocationBinding.wrappedValue.isEmpty {
                                Button(action: { activeCityLocationBinding.wrappedValue = "" }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.035)))
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.primary.opacity(0.1), lineWidth: 1))
                    }
                }
            }

            // Interactive Voice Test Section
            GlassSection(title: appState.l("Voice Test"), icon: "mic.fill") {
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(isTestingVoice ? uiAccentColor.opacity(0.15) : Color.primary.opacity(0.05))
                            .frame(width: 64 + CGFloat(voiceTestLevel * 22), height: 64 + CGFloat(voiceTestLevel * 22))
                            .animation(.easeOut(duration: 0.12), value: voiceTestLevel)

                        Circle()
                            .fill(isTestingVoice ? uiAccentColor.opacity(0.22) : Color.primary.opacity(0.06))
                            .frame(width: 60, height: 60)

                        if voiceTestSuccess {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 30))
                                .foregroundStyle(.green)
                        } else {
                            Image(systemName: isTestingVoice ? "waveform" : "mic.fill")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundStyle(isTestingVoice ? uiAccentColor : .secondary)
                        }
                    }

                    Text(displayedVoiceTestPrompt)
                        .font(.system(size: 12.5, weight: .medium, design: .rounded))
                        .foregroundStyle(voiceTestSuccess ? .green : .primary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)

                    if !voiceTestSuccess {
                        HStack(spacing: 12) {
                            Button(action: {
                                if isTestingVoice {
                                    stopVoiceTest()
                                    isTestingVoice = false
                                } else {
                                    startVoiceTest()
                                }
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: isTestingVoice ? "stop.fill" : "mic.fill")
                                        .font(.system(size: 11, weight: .bold))
                                    Text(isTestingVoice ? appState.l("Stop Test") : appState.l("Start Test"))
                                        .font(.system(size: 12.5, weight: .bold, design: .rounded))
                                }
                                .foregroundStyle(isTestingVoice ? Color.white : (isLightAppearance ? Color.white : Color(white: 0.12)))
                                .padding(.horizontal, 18)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(
                                            isTestingVoice
                                                ? LinearGradient(colors: [Color.red, Color.red.opacity(0.85)], startPoint: .top, endPoint: .bottom)
                                                : (isLightAppearance
                                                    ? LinearGradient(colors: [Color(white: 0.14), Color(white: 0.24)], startPoint: .top, endPoint: .bottom)
                                                    : LinearGradient(colors: [Color.white, Color(white: 0.92)], startPoint: .top, endPoint: .bottom))
                                        )
                                )
                            }
                            .buttonStyle(.plain)

                            if !voiceTestSkipped {
                                Button(action: {
                                    if isTestingVoice { stopVoiceTest() }
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        voiceTestSkipped = true
                                    }
                                }) {
                                    Text(appState.l("Skip voice test"))
                                        .font(.system(size: 12, weight: .medium, design: .rounded))
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 8)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - Subviews & Helpers

    private var displayedVoiceTestPrompt: String {
        if voiceTestSuccess {
            return appState.l("Perfect! Your mic is working.")
        }
        if let err = voiceTestError {
            return err
        }
        if !voiceTestTranscript.isEmpty {
            return voiceTestTranscript
        }
        if isTestingVoice {
            return appState.l("Listening...")
        }
        return appState.l("Click 'Start Test' and say \"Testing microphone for Scribe\"")
    }

    private func isPresetApplied(_ preset: VocabularyPreset) -> Bool {
        let currentWords = Set(
            appState.vocabulary
                .components(separatedBy: CharacterSet(charactersIn: ",\n"))
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                .filter { !$0.isEmpty }
        )
        let sample = preset.words.prefix(5).map { $0.lowercased() }
        return !sample.isEmpty && sample.allSatisfy { currentWords.contains($0) }
    }

    private func togglePresetWords(_ preset: VocabularyPreset) {
        var existing = appState.vocabulary
            .components(separatedBy: CharacterSet(charactersIn: ",\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if isPresetApplied(preset) {
            let removeSet = Set(preset.words.map { $0.lowercased() })
            existing.removeAll { removeSet.contains($0.lowercased()) }
        } else {
            let existingLower = Set(existing.map { $0.lowercased() })
            for word in preset.words {
                let clean = word.normalizedPlainVocabularyWord()
                if !clean.isEmpty && !existingLower.contains(clean.lowercased()) {
                    existing.append(clean)
                }
            }
        }
        appState.vocabulary = existing.joined(separator: ", ")
    }

    private func featurePill(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9.5, weight: .bold))
                .foregroundStyle(uiAccentColor)
            Text(text)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary.opacity(0.85))
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4.5)
        .background(Capsule().fill(uiAccentColor.opacity(0.1)))
        .overlay(Capsule().stroke(uiAccentColor.opacity(0.24), lineWidth: 0.7))
    }

    private func engineOptionCard(
        title: String,
        subtitle: String,
        icon: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                action()
            }
        }) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(isSelected ? uiAccentColor : .secondary)
                    Text(title)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(uiAccentColor)
                    }
                }
                Text(subtitle)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? uiAccentColor.opacity(0.12) : Color.primary.opacity(0.035))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(isSelected ? uiAccentColor.opacity(0.45) : Color.primary.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func primaryContinueButton(enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: {
            if enabled { action() }
        }) {
            HStack(spacing: 8) {
                Text(appState.l("Continue"))
                    .font(.system(size: 14, weight: .bold, design: .rounded))

                if enabled {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .bold))
                }
            }
            .foregroundStyle(enabled ? (isLightAppearance ? Color.white : Color(white: 0.12)) : Color.primary.opacity(0.35))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(
                ZStack {
                    if enabled {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(
                                    colors: isLightAppearance
                                        ? [Color(white: 0.14), Color(white: 0.24)]
                                        : [Color.white, Color(white: 0.92)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(isLightAppearance ? Color.black.opacity(0.25) : Color.white.opacity(0.8), lineWidth: 1)
                            )
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.primary.opacity(0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                            )
                    }
                }
            )
            .shadow(color: enabled ? (isLightAppearance ? Color.black.opacity(0.18) : Color.white.opacity(0.35)) : .clear, radius: 10, y: 3)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: enabled)
    }

    private func primaryFinishButton(enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: {
            if enabled { action() }
        }) {
            HStack(spacing: 8) {
                Text(isTestRun ? appState.l("Exit Test") : appState.l("Get Started"))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                if enabled {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                }
            }
            .foregroundStyle(enabled ? (isLightAppearance ? Color.white : Color(white: 0.12)) : Color.primary.opacity(0.35))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(
                ZStack {
                    if enabled {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(
                                    colors: isLightAppearance
                                        ? [Color(white: 0.14), Color(white: 0.24)]
                                        : [Color.white, Color(white: 0.92)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(isLightAppearance ? Color.black.opacity(0.25) : Color.white.opacity(0.8), lineWidth: 1)
                            )
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.primary.opacity(0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                            )
                    }
                }
            )
            .shadow(color: enabled ? (isLightAppearance ? Color.black.opacity(0.18) : Color.white.opacity(0.35)) : .clear, radius: 10, y: 3)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: enabled)
    }

    // MARK: - Voice Test Audio Engine

    private func startVoiceTest() {
        isTestingVoice = true
        voiceTestError = nil
        voiceTestTranscript = ""
        voiceTestLevel = 0

        let preferredLang = appState.multilingualLanguages.first ?? "en"
        let localeId = TranscriptionService.localeIdentifier(for: preferredLang)
        let recognizer = SFSpeechRecognizer(locale: Locale(identifier: localeId)) ?? SFSpeechRecognizer()
        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        self.request = req

        if engine.isRunning {
            engine.stop()
        }

        let node = engine.inputNode
        node.removeTap(onBus: 0)

        let recordingFormat = node.outputFormat(forBus: 0)

        guard recordingFormat.channelCount > 0 else {
            isTestingVoice = false
            voiceTestError = appState.l("Microphone format unsupported.")
            return
        }

        node.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { @Sendable buffer, _ in
            req.append(buffer)
            if let channelData = buffer.floatChannelData?[0] {
                let frameLength = Int(buffer.frameLength)
                if frameLength > 0 {
                    var sum: Float = 0
                    for i in 0..<frameLength {
                        let sample = channelData[i]
                        sum += sample * sample
                    }
                    let rms = sqrt(sum / Float(frameLength))
                    let normalized = min(max(rms * 8.0, 0), 1.0)
                    DispatchQueue.main.async {
                        self.voiceTestLevel = normalized
                    }
                }
            }
        }

        engine.prepare()
        do {
            try engine.start()
            task = recognizer?.recognitionTask(with: request) { result, error in
                if let result = result {
                    let text = result.bestTranscription.formattedString
                    DispatchQueue.main.async {
                        if !text.isEmpty {
                            self.voiceTestTranscript = text
                        }
                        if text.count >= 4 {
                            if !self.voiceTestSuccess {
                                self.voiceTestSuccess = true
                                self.isTestingVoice = false
                                self.voiceTestLevel = 0
                                self.stopVoiceTest()
                            }
                        }
                    }
                }

                if let error = error {
                    DispatchQueue.main.async {
                        if !self.voiceTestSuccess {
                            self.isTestingVoice = false
                            self.voiceTestLevel = 0
                            self.voiceTestError = self.appState.l("Testing failed: ") + error.localizedDescription
                            self.stopVoiceTest()
                        }
                    }
                }
            }
        } catch {
            isTestingVoice = false
            voiceTestLevel = 0
            voiceTestError = appState.l("Failed to start audio engine.")
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
        voiceTestLevel = 0
    }
}

// MARK: - Sandbox Snapshot for Test Onboarding Runs

@MainActor
private struct OnboardingSettingsSnapshot: Codable {
    let userName: String
    let userCityLocation: String
    let hasCompletedFirstLaunchSetup: Bool
    let hasCompletedOnboardingNamePrompt: Bool
    let selectedUILanguage: String
    let selectedThemeRaw: String
    let selectedOverlayStyleRaw: String
    let selectedOverlaySizeRaw: String
    let overlayPositionModeRaw: String
    let selectedPanelAppearanceRaw: String
    let selectedOverlayAppearanceRaw: String
    let livePreviewEnabled: Bool
    let soundFeedbackEnabled: Bool
    let durationVisible: Bool
    let showTargetAppInOverlay: Bool
    let multilingualLanguages: [String]
    let recognitionEngine: String
    let pushToTalk: Bool
    let selectedPasteModeRaw: String
    let preserveClipboard: Bool
    let cleanFillerWords: Bool
    let enableCloudAI: Bool
    let cloudAIProviderRaw: String
    let groqAPIKey: String
    let cerebrasAPIKey: String
    let geminiAPIKey: String
    let openAIAPIKey: String
    let anthropicAPIKey: String
    let customOpenAIKey: String
    let aiGatewayKeysJSON: String
    let vocabulary: String
    let habitMonitorWasRunning: Bool
    let launchAtLoginWasEnabled: Bool

    static let backupDefaultsKey = "com.aleksei.scribe.testOnboardingBackup"

    init(from appState: AppState) {
        self.userName = appState.userName
        self.userCityLocation = appState.userCityLocation
        self.hasCompletedFirstLaunchSetup = UserDefaults.standard.bool(forKey: "hasCompletedFirstLaunchSetup")
        self.hasCompletedOnboardingNamePrompt = UserDefaults.standard.bool(forKey: "hasCompletedOnboardingNamePrompt")
        self.selectedUILanguage = appState.selectedUILanguage
        self.selectedThemeRaw = appState.selectedThemeRaw
        self.selectedOverlayStyleRaw = appState.selectedOverlayStyleRaw
        self.selectedOverlaySizeRaw = appState.selectedOverlaySizeRaw
        self.overlayPositionModeRaw = appState.overlayPositionModeRaw
        self.selectedPanelAppearanceRaw = appState.selectedPanelAppearanceRaw
        self.selectedOverlayAppearanceRaw = appState.selectedOverlayAppearanceRaw
        self.livePreviewEnabled = appState.livePreviewEnabled
        self.soundFeedbackEnabled = appState.soundFeedbackEnabled
        self.durationVisible = appState.durationVisible
        self.showTargetAppInOverlay = appState.showTargetAppInOverlay
        self.multilingualLanguages = appState.multilingualLanguages
        self.recognitionEngine = appState.recognitionEngine
        self.pushToTalk = appState.pushToTalk
        self.selectedPasteModeRaw = appState.selectedPasteModeRaw
        self.preserveClipboard = appState.preserveClipboard
        self.cleanFillerWords = appState.cleanFillerWords
        self.enableCloudAI = appState.enableCloudAI
        self.cloudAIProviderRaw = appState.cloudAIProviderRaw
        self.groqAPIKey = appState.groqAPIKey
        self.cerebrasAPIKey = appState.cerebrasAPIKey
        self.geminiAPIKey = appState.geminiAPIKey
        self.openAIAPIKey = appState.openAIAPIKey
        self.anthropicAPIKey = appState.anthropicAPIKey
        self.customOpenAIKey = appState.customOpenAIKey
        self.aiGatewayKeysJSON = appState.aiGatewayKeysJSON
        self.vocabulary = appState.vocabulary
        self.habitMonitorWasRunning = PersonalVocabularyMonitor.shared.isRunning
        self.launchAtLoginWasEnabled = LaunchAtLoginHelper.isEnabled
    }

    func restore(to appState: AppState) {
        appState.userName = userName
        appState.userCityLocation = userCityLocation
        UserDefaults.standard.set(userName, forKey: "userName")
        UserDefaults.standard.set(hasCompletedFirstLaunchSetup, forKey: "hasCompletedFirstLaunchSetup")
        UserDefaults.standard.set(hasCompletedOnboardingNamePrompt, forKey: "hasCompletedOnboardingNamePrompt")
        appState.selectedUILanguage = selectedUILanguage
        appState.selectedThemeRaw = selectedThemeRaw
        appState.selectedOverlayStyleRaw = selectedOverlayStyleRaw
        appState.selectedOverlaySizeRaw = selectedOverlaySizeRaw
        appState.overlayPositionModeRaw = overlayPositionModeRaw
        appState.selectedPanelAppearanceRaw = selectedPanelAppearanceRaw
        appState.selectedOverlayAppearanceRaw = selectedOverlayAppearanceRaw
        appState.livePreviewEnabled = livePreviewEnabled
        appState.soundFeedbackEnabled = soundFeedbackEnabled
        appState.durationVisible = durationVisible
        appState.showTargetAppInOverlay = showTargetAppInOverlay
        appState.multilingualLanguages = multilingualLanguages
        appState.recognitionEngine = recognitionEngine
        appState.pushToTalk = pushToTalk
        appState.selectedPasteModeRaw = selectedPasteModeRaw
        appState.preserveClipboard = preserveClipboard
        appState.cleanFillerWords = cleanFillerWords
        appState.enableCloudAI = enableCloudAI
        appState.cloudAIProviderRaw = cloudAIProviderRaw
        appState.groqAPIKey = groqAPIKey
        appState.cerebrasAPIKey = cerebrasAPIKey
        appState.geminiAPIKey = geminiAPIKey
        appState.openAIAPIKey = openAIAPIKey
        appState.anthropicAPIKey = anthropicAPIKey
        appState.customOpenAIKey = customOpenAIKey
        appState.aiGatewayKeysJSON = aiGatewayKeysJSON
        appState.loadGatewayKeys()
        appState.vocabulary = vocabulary
        if PersonalVocabularyMonitor.shared.isRunning != habitMonitorWasRunning {
            PersonalVocabularyMonitor.shared.toggleMonitoring()
        }
        if LaunchAtLoginHelper.isEnabled != launchAtLoginWasEnabled {
            LaunchAtLoginHelper.setEnabled(launchAtLoginWasEnabled)
        }
        UserDefaults.standard.removeObject(forKey: Self.backupDefaultsKey)
    }
}

// MARK: - Permission Window Manager

@MainActor
final class PermissionWindowManager {
    static let shared = PermissionWindowManager()

    var window: NSWindow?
    private var appState: AppState?
    private var testSnapshot: OnboardingSettingsSnapshot?
    private var terminationObserver: NSObjectProtocol?

    var windowFrame: NSRect? { window?.frame }

    func ensureMinimumY(_ minY: CGFloat) {
        // Intentionally no-op: do not push or constrain window during drag
    }

    /// Restores any leftover crash/termination backup from a previous test onboarding session.
    func restoreCrashBackupIfPresent(appState: AppState) {
        guard let data = UserDefaults.standard.data(forKey: OnboardingSettingsSnapshot.backupDefaultsKey),
              let decoded = try? JSONDecoder().decode(OnboardingSettingsSnapshot.self, from: data) else {
            return
        }
        decoded.restore(to: appState)
    }

    func updateWindowAppearance(_ appearance: PanelAppearance) {
        guard let window = window else { return }
        window.appearance = (appearance == .light)
            ? NSAppearance(named: .aqua)
            : NSAppearance(named: .darkAqua)
    }

    func animateToSize(_ size: CGSize) {
        guard let window = window else { return }

        let newHeight = min(size.height, 860)
        let currentFrame = window.frame
        let newX = currentFrame.midX - (size.width / 2)
        var newY = currentFrame.maxY - newHeight
        if let screenFrame = (window.screen ?? NSScreen.main)?.visibleFrame {
            if newY < screenFrame.minY + 96 {
                newY = max(screenFrame.minY + 32, screenFrame.midY - newHeight / 2)
            }
            if newY + newHeight > screenFrame.maxY - 16 {
                newY = screenFrame.maxY - newHeight - 16
            }
        }
        let newFrame = NSRect(x: newX, y: newY, width: size.width, height: newHeight)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.35
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().setFrame(newFrame, display: true)
        } completionHandler: {
            Task { @MainActor in
                PermissionWindowManager.shared.currentAppState?.moveSettingsPreviewPanelWithWindow()
            }
        }
    }

    func showWindow(appState: AppState? = nil, isTestRun: Bool = false) {
        if let appState = appState {
            self.appState = appState
            if !isTestRun {
                restoreCrashBackupIfPresent(appState: appState)
            }
        }

        if let existing = window {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        if isTestRun, let state = self.appState {
            // If a previous backup existed, restore it first before taking a clean snapshot
            restoreCrashBackupIfPresent(appState: state)
            let snapshot = OnboardingSettingsSnapshot(from: state)
            self.testSnapshot = snapshot
            if let encoded = try? JSONEncoder().encode(snapshot) {
                UserDefaults.standard.set(encoded, forKey: OnboardingSettingsSnapshot.backupDefaultsKey)
            }

            // Initialize test onboarding with fresh defaults (English only, Direct Typing)
            state.selectedUILanguage = "en"
            state.multilingualLanguages = ["en"]
            state.selectedPasteMode = .directType

            terminationObserver = NotificationCenter.default.addObserver(
                forName: NSApplication.willTerminateNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.restoreSnapshotIfNeeded()
                }
            }
        }

        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 540, height: 760),
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
        if let state = self.appState {
            newWindow.appearance = (state.selectedPanelAppearance == .light)
                ? NSAppearance(named: .aqua)
                : NSAppearance(named: .darkAqua)
        }
        newWindow.center()

        // Blur background — same as Settings window
        let blurView = NSVisualEffectView()
        blurView.material = .popover
        blurView.blendingMode = .behindWindow
        blurView.state = .active

        newWindow.delegate = PermissionWindowDelegate.shared

        let welcomeView = PermissionWelcomeView(
            isTestRun: isTestRun,
            onComplete: { [weak self] in
                guard let self = self else { return }
                let state = self.appState
                let wasTest = (self.testSnapshot != nil)
                self.closeWindow()
                if let state = state, !wasTest {
                    SettingsWindowManager.shared.showSettings(appState: state)
                }
            }
        )

        let hostingView = appState != nil
            ? NSHostingView(rootView: welcomeView.environmentObject(appState!))
            : NSHostingView(rootView: welcomeView.environmentObject(AppState()))
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

    func restoreSnapshotIfNeeded() {
        if let snapshot = testSnapshot, let state = appState {
            snapshot.restore(to: state)
            testSnapshot = nil
        }
        if let obs = terminationObserver {
            NotificationCenter.default.removeObserver(obs)
            terminationObserver = nil
        }
    }

    func closeWindow() {
        restoreSnapshotIfNeeded()
        appState?.hideSettingsPreviewPanel()
        window?.close()
        window = nil
    }

    var currentAppState: AppState? {
        return appState
    }

    func windowDidMove() {
        currentAppState?.moveSettingsPreviewPanelWithWindow()
    }
}

@MainActor
private class PermissionWindowDelegate: NSObject, NSWindowDelegate, @unchecked Sendable {
    static let shared = PermissionWindowDelegate()

    func windowDidMove(_ notification: Notification) {
        PermissionWindowManager.shared.windowDidMove()
    }

    func windowWillClose(_ notification: Notification) {
        PermissionWindowManager.shared.restoreSnapshotIfNeeded()
    }
}
