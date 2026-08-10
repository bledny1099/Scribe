import re

with open("Scribe/UI/SettingsView.swift", "r") as f:
    text = f.read()

# Make sure we have the SettingsTab enum at the top
enum_str = """
enum SettingsTab: String, CaseIterable {
    case general = "General"
    case appearance = "Appearance"
    case recognition = "Recognition"
    case statistics = "Statistics"
    case replacements = "Replacements"
    case integrations = "Integrations"
    case system = "System"
}
"""
if "enum SettingsTab" not in text:
    text = text.replace("import KeyboardShortcuts", "import KeyboardShortcuts\n" + enum_str)

# Add @State private var selectedTab
if "@State private var selectedTab" not in text:
    text = text.replace("@EnvironmentObject var appState", "@State private var selectedTab: SettingsTab = .general\n    @EnvironmentObject var appState")

# We need to rewrite the body
body_start = text.find("    var body: some View {")
body_end = text.find("    private var modelDescription: String {")

new_body = """    var body: some View {
        ZStack(alignment: .top) {
            HStack(alignment: .top, spacing: 0) {
                // Sidebar
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(SettingsTab.allCases, id: \\.self) { tab in
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedTab = tab
                            }
                        }) {
                            HStack {
                                Text(appState.l(tab.rawValue))
                                    .font(.system(size: 13, weight: selectedTab == tab ? .bold : .medium, design: .rounded))
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(selectedTab == tab ? Color.primary.opacity(0.1) : Color.clear)
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }
                .frame(width: 150)
                .padding(.top, 116)
                .padding(.horizontal, 12)
                .background(Color.primary.opacity(0.02))

                Divider()

                // Main Content
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(spacing: 20) {
                        switch selectedTab {
                        case .general:
                            // SECTION: Shortcut & Paste Mode
                            GlassSection(title: appState.l("Recording"), icon: "keyboard") {
                                VStack(spacing: 16) {
                                    HStack {
                                        Text(appState.l("Global Hotkey"))
                                            .font(.system(size: 14, weight: .medium, design: .rounded))
                                            .foregroundStyle(.primary)
                                        Spacer()
                                        KeyboardShortcuts.Recorder(for: .toggleRecording)
                                    }

                                    HStack {
                                        Text(appState.l("Paste Mode"))
                                            .font(.system(size: 14, weight: .medium, design: .rounded))
                                            .foregroundStyle(.primary)
                                        Spacer()
                                        LiquidGlassSegmentedPicker(
                                            items: PasteMode.allCases,
                                            selection: Binding(
                                                get: { appState.selectedPasteMode },
                                                set: { appState.selectedPasteMode = $0 }
                                            ),
                                            label: { (appState.l($0.displayName), $0.icon) }
                                        )
                                    }

                                    Text(appState.selectedPasteMode == .paste
                                        ? appState.l("Replaces clipboard content with transcribed text.")
                                        : appState.l("Appends transcribed text to current clipboard content.")
                                    )
                                    .font(.system(size: 11, weight: .regular))
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.top, -8)

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
                                    }

                                    if appState.livePreviewEnabled && appState.selectedOverlayStyle.supportsEmbeddedPreview {
                                        VStack(spacing: 10) {
                                            if appState.selectedOverlayStyle.supportsEmbeddedPreview {
                                                HStack {
                                                    Text(appState.l("Display Mode"))
                                                        .font(.system(size: 14, weight: .medium, design: .rounded))
                                                        .foregroundStyle(.primary)
                                                        .fixedSize(horizontal: true, vertical: false)
                                                    Spacer()
                                                    LiquidGlassSegmentedPicker(
                                                        items: LivePreviewMode.allCases,
                                                        selection: Binding(
                                                            get: { appState.livePreviewMode },
                                                            set: {
                                                                appState.livePreviewMode = $0
                                                                appState.showSettingsPreviewFor5Seconds()
                                                            }
                                                        ),
                                                        label: { (appState.l($0.displayName), $0.icon) }
                                                    )
                                                }
                                            }

                                            if appState.livePreviewMode == .external || !appState.selectedOverlayStyle.supportsEmbeddedPreview {
                                                HStack {
                                                    Text(appState.l("Preview Background"))
                                                        .font(.system(size: 14, weight: .medium, design: .rounded))
                                                        .foregroundStyle(.primary)
                                                    Spacer()
                                                    LiquidGlassSegmentedPicker(
                                                        items: SubtitleBackground.allCases,
                                                        selection: Binding(
                                                            get: { appState.livePreviewBackground },
                                                            set: {
                                                                appState.livePreviewBackground = $0
                                                                appState.showSettingsPreviewFor5Seconds()
                                                            }
                                                        ),
                                                        label: { (appState.l($0.displayName), $0.icon) }
                                                    )
                                                }
                                            }
                                        }
                                        .padding(.top, 4)
                                        .transition(.opacity.combined(with: .move(edge: .top)))
                                    }
                                }
                            }

                        case .appearance:
                            // SECTION: Theme & Style
                            GlassSection(title: appState.l("Appearance"), icon: "paintbrush.fill") {
                                VStack(spacing: 16) {
                                    // Theme picker
                                    HStack(alignment: .top, spacing: 14) {
                                        ForEach(AppTheme.allCases) { theme in
                                            ThemeSwatchButton(
                                                theme: theme,
                                                isSelected: appState.selectedTheme == theme
                                            ) {
                                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                    appState.selectedTheme = theme
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
                                                set: { appState.selectedOverlayStyle = $0 }
                                            ),
                                            label: { ("", $0.icon) }
                                        )
                                    }

                                    // Overlay size picker
                                    HStack {
                                        Text(appState.l("Overlay Size"))
                                            .font(.system(size: 14, weight: .medium, design: .rounded))
                                            .foregroundStyle(.primary)
                                        Spacer()
                                        LiquidGlassSegmentedPicker(
                                            items: OverlaySize.allCases,
                                            selection: Binding(
                                                get: { appState.selectedOverlaySize },
                                                set: { appState.selectedOverlaySize = $0 }
                                            ),
                                            label: { (appState.l($0.shortName), $0.icon) }
                                        )
                                    }

                                    // Background appearance picker
                                    HStack {
                                        Text(appState.l("Panel Appearance"))
                                            .font(.system(size: 14, weight: .medium, design: .rounded))
                                            .foregroundStyle(.primary)
                                        Spacer()
                                        LiquidGlassSegmentedPicker(
                                            items: PanelAppearance.allCases,
                                            selection: Binding(
                                                get: { appState.selectedPanelAppearance },
                                                set: { appState.selectedPanelAppearance = $0 }
                                            ),
                                            label: { (appState.l($0.displayName), $0.icon) }
                                        )
                                    }

                                    // Live Floating Preview Info Bar
                                    HStack {
                                        Label("Live Floating Preview", systemImage: "sparkles")
                                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                        let currentStyle = appState.selectedOverlayStyle
                                        let currentSize = appState.selectedOverlaySize
                                        let scaled = RecordingPanel.size(for: currentStyle, overlaySize: currentSize)
                                        Text("\\(Int(scaled.width)) × \\(Int(scaled.height)) px")
                                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                            .foregroundStyle(.tertiary)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color.primary.opacity(0.04))
                                    .cornerRadius(8)
                                }
                            }

                        case .recognition:
                            // SECTION: Language & Model
                            GlassSection(title: appState.l("Recognition"), icon: "waveform.and.mic") {
                                VStack(spacing: 16) {
                                    HStack {
                                        Text(appState.l("Language"))
                                            .font(.system(size: 14, weight: .medium, design: .rounded))
                                            .foregroundStyle(.primary)
                                        Spacer()
                                        Picker("", selection: $appState.selectedLanguage) {
                                            ForEach(appState.availableLanguages, id: \\.code) { lang in
                                                Text(lang.name).tag(lang.code)
                                            }
                                        }
                                        .frame(width: 150)
                                    }

                                    // Model Selection
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(appState.l("Model"))
                                            .font(.system(size: 14, weight: .medium, design: .rounded))
                                            .foregroundStyle(.primary)

                                        VStack(spacing: 8) {
                                            ForEach(models, id: \\.id) { model in
                                                ModelRow(
                                                    id: model.id,
                                                    name: model.name,
                                                    description: appState.l(model.desc),
                                                    isSelected: appState.selectedModel == model.id
                                                ) {
                                                    appState.selectedModel = model.id
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                        case .statistics:
                            StatisticsSectionView()
                            
                        case .replacements:
                            ReplacementsSettingsView()
                            
                        case .integrations:
                            IntegrationsSettingsView()

                        case .system:
                            // SECTION: System
                            GlassSection(title: appState.l("System"), icon: "lock.shield") {
                                VStack(spacing: 16) {
                                    HStack {
                                        Text(appState.l("Open at Login"))
                                            .font(.system(size: 14, weight: .medium, design: .rounded))
                                            .foregroundStyle(.primary)
                                        Spacer()
                                        Toggle("", isOn: $appState.launchAtLogin)
                                            .toggleStyle(.switch)
                                            .labelsHidden()
                                    }

                                    HStack {
                                        Text(appState.l("Sound Feedback"))
                                            .font(.system(size: 14, weight: .medium, design: .rounded))
                                            .foregroundStyle(.primary)
                                        Spacer()
                                        Toggle("", isOn: $appState.soundFeedbackEnabled)
                                            .toggleStyle(.switch)
                                            .labelsHidden()
                                    }

                                    PermissionsCard()

                                    // History Button
                                    Button(action: {
                                        HistoryWindowManager.shared.showWindow(appState: appState)
                                    }) {
                                        HStack {
                                            Image(systemName: "clock.arrow.circlepath")
                                                .font(.system(size: 14, weight: .medium))
                                            Text(appState.l("View Transcription History"))
                                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundStyle(.secondary)
                                        }
                                        .padding(12)
                                        .background(Color.primary.opacity(0.04))
                                        .cornerRadius(8)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }

                            // Support Developer Button
                            Button {
                                showingSupportModal = true
                            } label: {
                                HStack {
                                    Spacer()
                                    Image(systemName: "heart.fill")
                                        .foregroundStyle(.red)
                                    Text("Support Scribe ☕️")
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                    Spacer()
                                }
                                .padding(14)
                                .background(
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.primary.opacity(0.04))
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(.ultraThinMaterial.opacity(0.8))
                                    }
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                                )
                                .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 8)
                            .sheet(isPresented: $showingSupportModal) {
                                SupportDeveloperModal()
                                    .environmentObject(appState)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 116)
                    .padding(.bottom, 24)
                }
            }
            
            // App Header Overlay
            VStack {
                HStack(alignment: .center, spacing: 12) {
                    Image("AppIconImage")
                        .resizable()
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Scribe")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                        Text(appState.l("Voice Typing"))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button(action: {
                        SettingsWindowManager.shared.closeWindow()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 16)
                .background(WindowDragView())
            }
        }
        .ignoresSafeArea(.container, edges: .top)
        .frame(width: 650, height: 620)
        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
        .onDisappear {
            appState.hideSettingsPreviewPanel()
        }
        .onChange(of: appState.selectedOverlaySize) { _ in
            appState.showSettingsPreviewFor5Seconds()
        }
        .onChange(of: appState.selectedOverlayStyle) { _ in
            appState.showSettingsPreviewFor5Seconds()
        }
        .onChange(of: appState.selectedTheme) { _ in
            appState.onThemeChangedPreview()
        }
        .onChange(of: appState.selectedPanelAppearance) { _ in
            appState.showSettingsPreviewFor5Seconds()
        }
    }\n"""

text = text[:body_start] + new_body + text[body_end:]

with open("Scribe/UI/SettingsView.swift", "w") as f:
    f.write(text)

print("Rewrote SettingsView with perfect tabs.")

# Also update SettingsWindowManager back to size 650
import shutil
shutil.copy("Scribe/UI/SettingsWindowManager.swift.bak", "Scribe/UI/SettingsWindowManager.swift")
with open("Scribe/UI/SettingsWindowManager.swift", "r") as f:
    wm_text = f.read()

wm_text = wm_text.replace("width: 440, height: 620", "width: 650, height: 620")

with open("Scribe/UI/SettingsWindowManager.swift", "w") as f:
    f.write(wm_text)

print("Restored and patched SettingsWindowManager width to 650.")
