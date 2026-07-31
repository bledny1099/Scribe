import SwiftUI
import KeyboardShortcuts

/// Custom designed "Liquid Glass" settings view.
struct SettingsView: View {

    @EnvironmentObject var appState: AppState

    // Supported multilingual models ordered by quality
    private let models: [(id: String, name: String, desc: String)] = [
        ("openai_whisper-small", "Small (Recommended)", "Great balance of high accuracy and speed (~460MB)"),
        ("openai_whisper-large-v3_turbo", "Large V3 Turbo", "Highest quality for complex speech & terms (~950MB)"),
        ("openai_whisper-base", "Base (Fastest)", "Lightweight and ultra fast, ideal for simple phrases (~140MB)")
    ]

    var body: some View {
        ZStack(alignment: .top) {
            // Scrollable Content
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
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
                                Toggle("", isOn: Binding(
                                    get: { appState.livePreviewEnabled },
                                    set: { newValue in
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            appState.livePreviewEnabled = newValue
                                        }
                                    }
                                ))
                                    .toggleStyle(.switch)
                                    .labelsHidden()
                            }

                            if appState.livePreviewEnabled {
                                HStack {
                                    Text(appState.l("Preview Background"))
                                        .font(.system(size: 14, weight: .medium, design: .rounded))
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    LiquidGlassSegmentedPicker(
                                        items: SubtitleBackground.allCases,
                                        selection: Binding(
                                            get: { appState.livePreviewBackground },
                                            set: { appState.livePreviewBackground = $0 }
                                        ),
                                        label: { (appState.l($0.displayName), $0.icon) }
                                    )
                                }
                                .padding(.top, 4)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                    }

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
                        }
                    }

                    // SECTION: Language & Model
                    GlassSection(title: appState.l("Recognition"), icon: "waveform.and.mic") {
                        VStack(spacing: 16) {
                            HStack {
                                Text(appState.l("Dictation Language"))
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundStyle(.primary)
                                Spacer()
                                LiquidGlassLanguageMenu(
                                    items: supportedLanguages,
                                    selection: $appState.selectedLanguage
                                )
                            }

                            HStack {
                                Text(appState.l("Auto Translate to Selected Language"))
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundStyle(.primary)
                                Spacer()
                                Toggle("", isOn: $appState.autoTranslate)
                                    .toggleStyle(.switch)
                                    .labelsHidden()
                            }

                            HStack {
                                Text(appState.l("Interface Language"))
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundStyle(.primary)
                                Spacer()
                                LiquidGlassLanguageMenu(
                                    items: supportedLanguages,
                                    selection: $appState.selectedUILanguage
                                )
                            }

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
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                if appState.selectedLanguage == "auto" {
                                    HStack(alignment: .top, spacing: 6) {
                                        Image(systemName: "lightbulb.fill")
                                            .foregroundStyle(.yellow.opacity(0.8))
                                            .font(.system(size: 11))
                                            .padding(.top, 1)
                                        Text(appState.l("Setting a specific language improves accuracy on short phrases."))
                                            .lineLimit(2)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.secondary)
                                    .padding(.top, 4)
                                }
                            }
                            .padding(.top, -4)
                        }
                    }

                    // SECTION: System
                    GlassSection(title: appState.l("System"), icon: "lock.shield") {
                        VStack(alignment: .leading, spacing: 16) {
                            // Launch at login
                            HStack {
                                Text(appState.l("Launch at Login"))
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundStyle(.primary)
                                Spacer()
                                Toggle("", isOn: Binding(
                                    get: { LaunchAtLoginHelper.isEnabled },
                                    set: { LaunchAtLoginHelper.setEnabled($0) }
                                ))
                                .toggleStyle(.switch)
                                .labelsHidden()
                            }

                            // Sound feedback
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
                                HistoryWindowManager.shared.showWindow()
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
                }
                .padding(.horizontal, 24)
                .padding(.top, 116)
                .padding(.bottom, 24)
            }
            .mask(
                VStack(spacing: 0) {
                    Color.clear.frame(height: 80)
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .black, location: 1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 32)
                    Color.black
                }
            )
            
            // Header
            VStack(spacing: 0) {
                Color.clear.frame(height: 24)
                
                HStack {
                    Text(appState.l("Scribe Settings"))
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    Spacer()
                    Button(action: { SettingsWindowManager.shared.closeWindow() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 16)
            }
        }
        .ignoresSafeArea(.container, edges: .top)
        .frame(width: 440, height: 620)
        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
    }

    private var modelDescription: String {
        models.first(where: { $0.id == appState.selectedModel })?.desc ?? ""
    }
}

// MARK: - Reusable Components

struct GlassSection<Content: View>: View {
    let title: String
    let icon: String
    let content: Content

    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)

            content
                .padding(16)
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

struct GlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.primary.opacity(configuration.isPressed ? 0.05 : 0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.primary.opacity(0.15), lineWidth: 1)
            )
    }
}

// MARK: - Liquid Glass Segmented Picker

/// A single unified track containing liquid glass segment buttons with sliding highlight.
struct LiquidGlassSegmentedPicker<T: Hashable & Identifiable>: View {
    let items: [T]
    @Binding var selection: T
    let label: (T) -> (name: String, icon: String)

    @Namespace private var segmentAnimation

    var body: some View {
        HStack(spacing: 2) {
            ForEach(items) { item in
                let isSelected = (item as AnyHashable) == (selection as AnyHashable)
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.75)) {
                        selection = item
                    }
                } label: {
                    let info = label(item)
                    HStack(spacing: (!info.icon.isEmpty && !info.name.isEmpty) ? 5 : 0) {
                        if !info.icon.isEmpty {
                            Image(systemName: info.icon)
                                .font(.system(size: 11, weight: .semibold))
                        }
                        if !info.name.isEmpty {
                            Text(info.name)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        ZStack {
                            if isSelected {
                                Capsule()
                                    .fill(Color.primary.opacity(0.12))
                                    .matchedGeometryEffect(id: "segmentBg", in: segmentAnimation)

                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.3),
                                                Color.white.opacity(0.08),
                                                Color.clear
                                            ],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .matchedGeometryEffect(id: "segmentHighlight", in: segmentAnimation)
                            }
                        }
                    )
                    .clipShape(Capsule())
                    .overlay(
                        ZStack {
                            if isSelected {
                                Capsule()
                                    .strokeBorder(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.5),
                                                Color.white.opacity(0.15)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 0.5
                                    )
                                    .matchedGeometryEffect(id: "segmentBorder", in: segmentAnimation)
                            }
                        }
                    )
                    .shadow(color: isSelected ? .black.opacity(0.08) : .clear, radius: 4, x: 0, y: 2)
                    .foregroundStyle(.primary)
                    .opacity(isSelected ? 1.0 : 0.6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(
            ZStack {
                Capsule()
                    .fill(Color.primary.opacity(0.05))

                Capsule()
                    .fill(.ultraThinMaterial.opacity(0.6))
            }
        )
        .overlay(
            Capsule()
                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5)
        )
    }
}

// MARK: - Liquid Glass Menu

/// A liquid glass dropdown menu button matching macOS glossy glass style.
struct LiquidGlassMenu<T: Hashable>: View {
    let items: [T]
    @Binding var selection: T
    let title: (T) -> String

    var body: some View {
        Menu {
            ForEach(items, id: \.self) { item in
                Button {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                        selection = item
                    }
                } label: {
                    if item == selection {
                        Label(title(item), systemImage: "checkmark")
                    } else {
                        Text(title(item))
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(title(selection))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer(minLength: 4)

                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(width: 180)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.primary.opacity(0.05))

                    RoundedRectangle(cornerRadius: 10)
                        .fill(.ultraThinMaterial.opacity(0.6))
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Liquid Glass Language Menu

/// A specialized menu button for `LanguageOption` that supports hierarchical (nested) menus.
struct LiquidGlassLanguageMenu: View {
    let items: [LanguageOption]
    @Binding var selection: String

    var body: some View {
        Menu {
            ForEach(items, id: \.id) { lang in
                if let children = lang.children {
                    Menu(lang.name) {
                        ForEach(children, id: \.id) { child in
                            Button {
                                withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                                    selection = child.id
                                }
                            } label: {
                                if child.id == selection {
                                    Label(child.name, systemImage: "checkmark")
                                } else {
                                    Text(child.name)
                                }
                            }
                        }
                    }
                } else {
                    Button {
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                            selection = lang.id
                        }
                    } label: {
                        if lang.id == selection {
                            Label(lang.name, systemImage: "checkmark")
                        } else {
                            Text(lang.name)
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                // Find selected language name by searching top-level and children
                let selectedName = items.flatMap { [$0] + ($0.children ?? []) }
                    .first(where: { $0.id == selection })?.name ?? selection
                
                Text(selectedName)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer(minLength: 4)

                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(width: 180)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.primary.opacity(0.05))

                    RoundedRectangle(cornerRadius: 10)
                        .fill(.ultraThinMaterial.opacity(0.6))
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Theme Swatch Button

struct ThemeSwatchButton: View {
    let theme: AppTheme
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(theme.accentGradient)
                        .frame(width: 44, height: 44)
                        .shadow(color: theme.gradientColors[0].opacity(isSelected ? 0.5 : 0), radius: 8, x: 0, y: 4)

                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .overlay(
                    Circle()
                        .strokeBorder(.white.opacity(isSelected ? 0.6 : 0.2), lineWidth: isSelected ? 2.5 : 1)
                        .frame(width: 44, height: 44)
                )
                .scaleEffect(isSelected ? 1.08 : 1.0)

                Text(theme.displayName)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .animation(nil, value: isSelected)
            }
        }
        .buttonStyle(.plain)
    }
}
