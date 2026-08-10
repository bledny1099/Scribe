import re

with open('/Users/aleksei/Documents/Scribe/Scribe/UI/PermissionView.swift', 'r') as f:
    content = f.read()

# 1. Update struct PermissionWelcomeView
old_decl = """struct PermissionWelcomeView: View {
    @ObservedObject var permissionManager = PermissionManager.shared
    @State private var showingSupportModal = false
    var onComplete: (() -> Void)? = nil

    var body: some View {"""

new_decl = """struct PermissionWelcomeView: View {
    enum OnboardingStep {
        case permissions
        case customization
        case voiceTest
    }

    @EnvironmentObject var appState: AppState
    @ObservedObject var permissionManager = PermissionManager.shared
    @State private var showingSupportModal = false
    @State private var currentStep: OnboardingStep = .permissions
    
    // Voice Test State
    @State private var isTestingVoice = false
    @State private var voiceTestText = "Click 'Start Test' and say \\"Testing microphone for Scribe\\""
    @State private var voiceTestSuccess = false
    
    var onComplete: (() -> Void)? = nil

    var body: some View {"""

content = content.replace(old_decl, new_decl)

# 2. Add transition wrapper and update content based on currentStep
old_scroll = """            // Scrollable Content
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {"""

new_scroll = """            // Scrollable Content
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    if currentStep == .permissions {"""

content = content.replace(old_scroll, new_scroll)

# 3. Replace the Get Started button in .permissions step to transition to Customization
old_btn = """                    let allGranted = permissionManager.isMicrophoneGranted && permissionManager.isAccessibilityGranted && permissionManager.isSpeechRecognitionGranted
                    Button(action: {
                        if let onComplete = onComplete {
                            onComplete()
                        } else {
                            PermissionWindowManager.shared.closeWindow()
                        }
                    }) {
                        HStack(spacing: 8) {
                            Text(allGranted ? "Get Started" : "Continue")"""

new_btn = """                    let allGranted = permissionManager.isMicrophoneGranted && permissionManager.isAccessibilityGranted && permissionManager.isSpeechRecognitionGranted
                    Button(action: {
                        if allGranted {
                            withAnimation {
                                currentStep = .customization
                            }
                        }
                    }) {
                        HStack(spacing: 8) {
                            Text(allGranted ? "Continue" : "Continue")"""

content = content.replace(old_btn, new_btn)

# 4. Add the Customization & Voice Test sections before the padding modifier
padding_match = re.search(r"(\s+})\s+\.padding\(\.horizontal, 24\)\s+\.padding\(\.bottom, 24\)\s+}", content)
if padding_match:
    end_of_permissions = padding_match.group(1)
    
    new_sections = """
                    } // end of .permissions

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
                                HStack {
                                    Text(appState.l("Overlay Style"))
                                        .font(.system(size: 14, weight: .medium, design: .rounded))
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    LiquidGlassSegmentedPicker(
                                        items: OverlayStyle.allCases,
                                        selection: Binding(
                                            get: { appState.selectedOverlayStyle },
                                            set: { appState.selectedOverlayStyle = $0; appState.showSettingsPreviewFor5Seconds() }
                                        ),
                                        label: { ("", $0.icon) }
                                    )
                                }
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
                    } // end of .customization

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
                                            .symbolEffect(.bounce, options: .repeating, isActive: isTestingVoice)
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
                                            SpeechRecognizer.shared.stopRecording()
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
                                SpeechRecognizer.shared.stopRecording()
                            }
                            if let onComplete = onComplete {
                                onComplete()
                            } else {
                                PermissionWindowManager.shared.closeWindow()
                            }
                        }) {
                            HStack(spacing: 8) {
                                Text("Get Started")
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
                            .opacity(voiceTestSuccess ? 1.0 : 0.5)
                        }
                        .buttonStyle(.plain)
                        .disabled(!voiceTestSuccess)
                    } // end of .voiceTest"""
    
    content = content[:padding_match.start(1)] + new_sections + content[padding_match.end(1):]


# 5. Add startVoiceTest() function to PermissionWelcomeView
startVoiceTestFunc = """
    private func startVoiceTest() {
        isTestingVoice = true
        voiceTestText = "Listening..."
        
        SpeechRecognizer.shared.startRecording(
            appState: appState,
            useLivePreview: true, // Show live text
            onTextChange: { partialText in
                DispatchQueue.main.async {
                    if !partialText.isEmpty {
                        self.voiceTestText = partialText
                    }
                    if partialText.count > 10 {
                        // Success!
                        self.voiceTestSuccess = true
                        self.isTestingVoice = false
                        self.voiceTestText = "Perfect! Your mic is working."
                        SpeechRecognizer.shared.stopRecording()
                    }
                }
            },
            onFinalText: { finalText in
                DispatchQueue.main.async {
                    if finalText.count > 10 {
                        self.voiceTestSuccess = true
                        self.isTestingVoice = false
                        self.voiceTestText = "Perfect! Your mic is working."
                    } else if !self.voiceTestSuccess {
                        self.isTestingVoice = false
                        self.voiceTestText = "Didn't quite catch that. Try again."
                    }
                }
            }
        )
    }
"""

# Insert before closing brace of PermissionWelcomeView
last_brace = content.rfind("}")
if last_brace != -1:
    # We want the closing brace of PermissionWelcomeView, but it is currently at the end of the view struct
    # We should search for "    }\n}\n\n// MARK: - Permission Window Manager"
    manager_mark = content.find("// MARK: - Permission Window Manager")
    if manager_mark != -1:
        insert_pos = content.rfind("}", 0, manager_mark)
        content = content[:insert_pos] + startVoiceTestFunc + "\n" + content[insert_pos:]

# 6. Fix PermissionWindowManager to inject environment object
window_manager_old = """        let welcomeView = PermissionWelcomeView(onComplete: { [weak self] in
            guard let self = self else { return }
            let state = self.appState
            self.closeWindow()
            if let state = state {
                SettingsWindowManager.shared.showSettings(appState: state)
            }
        })

        let hostingView = NSHostingView(rootView: welcomeView)"""

window_manager_new = """        let welcomeView = PermissionWelcomeView(onComplete: { [weak self] in
            guard let self = self else { return }
            let state = self.appState
            self.closeWindow()
            if let state = state {
                SettingsWindowManager.shared.showSettings(appState: state)
            }
        })
        
        let hostingView = appState != nil ? NSHostingView(rootView: welcomeView.environmentObject(appState!)) : NSHostingView(rootView: welcomeView.environmentObject(AppState()))"""

content = content.replace(window_manager_old, window_manager_new)

with open('/Users/aleksei/Documents/Scribe/Scribe/UI/PermissionView.swift', 'w') as f:
    f.write(content)
