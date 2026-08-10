import re

with open("Scribe/UI/SettingsView.swift.orig", "r") as f:
    orig = f.read()

imports = """import SwiftUI
import KeyboardShortcuts

enum SettingsTab: String, CaseIterable {
    case general = "General"
    case appearance = "Appearance"
    case recognition = "Recognition"
    case statistics = "Statistics"
    case replacements = "Replacements"
    case integrations = "Integrations"
}
"""

main_struct_start = """
/// Custom designed "Liquid Glass" settings view.
struct SettingsView: View {

    @State private var selectedTab: SettingsTab = .general
    @EnvironmentObject var appState: AppState
    @State private var showingSupportModal = false

    // Supported multilingual models ordered by quality
    private let models: [(id: String, name: String, desc: String)] = [
        ("openai_whisper-small", "Small (Recommended)", "Great balance of high accuracy and speed (~460MB)"),
        ("openai_whisper-large-v3_turbo", "Large V3 Turbo", "Highest quality for complex speech & terms (~950MB)"),
        ("openai_whisper-base", "Base (Fastest)", "Lightweight and ultra fast, ideal for simple phrases (~140MB)")
    ]
    
    private var modelDescription: String {
        appState.l(models.first(where: { $0.id == appState.selectedModel })?.desc ?? "")
    }

    var body: some View {
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
                    
                    // Support Developer Button in Sidebar
                    Button {
                        showingSupportModal = true
                    } label: {
                        HStack {
                            Image(systemName: "heart.fill")
                                .foregroundStyle(.red)
                            Text("Support Scribe")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.primary.opacity(0.04))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 8)
                }
                .frame(width: 150)
                .padding(.top, 116)
                .padding(.horizontal, 12)
                .background(Color.primary.opacity(0.02))
                .sheet(isPresented: $showingSupportModal) {
                    SupportDeveloperModal()
                        .environmentObject(appState)
                }

                Divider()

                // Main Content
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(spacing: 20) {
                        contentForTab
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
    }
    
    @ViewBuilder
    private var contentForTab: some View {
        switch selectedTab {
        case .general: generalSettings
        case .appearance: appearanceSettings
        case .recognition: recognitionSettings
        case .statistics: StatisticsSectionView()
        case .replacements: ReplacementsSettingsView()
        case .integrations: IntegrationsSettingsView()
        }
    }
"""

generalSettings = """
    private var generalSettings: some View {
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
    }
"""

appearanceSettings = """
    private var appearanceSettings: some View {
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
    }
"""

recognitionSettings = """
    private var recognitionSettings: some View {
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
                HStack {
                    Text(appState.l("Model Quality"))
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.primary)
                    Spacer()
                    LiquidGlassMenu(
                        items: models.map { $0.id },
                        selection: $appState.selectedModel,
                        title: { id in appState.l(models.first(where: { $0.id == id })?.name ?? id) }
                    )
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(appState.l(modelDescription))
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(.secondary)

                    if appState.selectedModel == "openai_whisper-large-v3_turbo" {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text(appState.l("May be slow on older Macs (M1/M2 recommended)"))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.orange)
                        }
                        .padding(.top, 2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, -8)
            }
        }
    }
}
"""

# Extract additional structs from Scribe/UI/SettingsView.swift.backup which has ALL original and appended stuff
with open("Scribe/UI/SettingsView.swift.backup", "r") as f:
    text = f.read()

# Grab all the structs below SettingsView
structs_split = text.split("\nstruct ")
additional_structs = []
for s in structs_split[1:]:
    if "SettingsView" in s and not s.startswith("StatisticsSectionView") and not s.startswith("IntegrationsSettingsView") and not s.startswith("ReplacementsSettingsView"):
        continue
    additional_structs.append("struct " + s)

final_text = imports + main_struct_start + generalSettings + appearanceSettings + recognitionSettings + "\n" + "\n".join(additional_structs)

with open("Scribe/UI/SettingsView.swift", "w") as f:
    f.write(final_text)

print("SettingsView fixed.")
