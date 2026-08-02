import SwiftUI
import KeyboardShortcuts

/// Custom designed "Liquid Glass" settings view.
struct SettingsView: View {

    @EnvironmentObject var appState: AppState
    @State private var showingSupportModal = false

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
                                Text("\(Int(scaled.width)) × \(Int(scaled.height)) px")
                                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.primary.opacity(0.04))
                            .cornerRadius(8)
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

                    // SECTION: Statistics
                    StatisticsSectionView()

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

    private var modelDescription: String {
        models.first(where: { $0.id == appState.selectedModel })?.desc ?? ""
    }
}

// MARK: - Statistics Section Component

struct StatisticsSectionView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var history = TranscriptionHistory.shared
    @AppStorage("isStatisticsExpanded") private var isExpanded: Bool = true
    @State private var timeFrame: StatsTimeFrame = .today

    var body: some View {
        GlassCollapsibleSection(
            title: appState.l("Statistics"),
            icon: "chart.bar.fill",
            isExpanded: $isExpanded
        ) {
            VStack(spacing: 14) {
                // Segmented Time Frame Picker
                LiquidGlassSegmentedPicker(
                    items: StatsTimeFrame.allCases,
                    selection: $timeFrame,
                    label: { (appState.l($0.rawValue), "") }
                )

                let stats = history.stats(for: timeFrame)

                // 2x2 Grid of Stat Cards
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    StatCard(
                        title: appState.l("Words Spoken"),
                        value: formatNumber(stats.wordCount),
                        icon: "text.quote",
                        color: .blue
                    )
                    StatCard(
                        title: appState.l("Characters"),
                        value: formatNumber(stats.charCount),
                        icon: "textformat",
                        color: .purple
                    )
                    StatCard(
                        title: appState.l("Time Dictated"),
                        value: formatDuration(stats.duration),
                        icon: "timer",
                        color: .orange
                    )
                    StatCard(
                        title: appState.l("Sessions"),
                        value: formatNumber(stats.sessionCount),
                        icon: "mic.fill",
                        color: .green
                    )
                }
            }
        }
    }

    private func formatNumber(_ num: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: num)) ?? "\(num)"
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let totalSecs = Int(duration)
        let hours = totalSecs / 3600
        let mins = (totalSecs % 3600) / 60
        let secs = totalSecs % 60

        if hours > 0 {
            return "\(hours)h \(mins)m"
        } else if mins > 0 {
            return "\(mins)m \(secs)s"
        } else {
            return "\(secs)s"
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(color.gradient)
                Text(title)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.75)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.primary.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.primary.opacity(0.15), lineWidth: 0.5)
        )
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

struct GlassCollapsibleSection<Content: View>: View {
    let title: String
    let icon: String
    @Binding var isExpanded: Bool
    let content: Content

    @State private var contentHeight: CGFloat = 0

    init(title: String, icon: String, isExpanded: Binding<Bool>, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self._isExpanded = isExpanded
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: isExpanded ? 12 : 0) {
            Button(action: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(title.uppercased())
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.horizontal, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

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
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(key: CollapsibleHeightKey.self, value: geo.size.height)
                    }
                )
                .onPreferenceChange(CollapsibleHeightKey.self) { h in
                    if h > 0 { contentHeight = h }
                }
                .frame(height: isExpanded ? contentHeight : 0, alignment: .top)
                .clipped()
                .opacity(isExpanded ? 1 : 0)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.78), value: isExpanded)
    }
}

private struct CollapsibleHeightKey: PreferenceKey {
    nonisolated(unsafe) static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
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
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                    }
                    .padding(.horizontal, 10)
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
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(isSelected ? 0.7 : 0.2), lineWidth: isSelected ? 2 : 1)
                        )
                        .frame(width: 44, height: 44)
                        .shadow(color: theme.gradientColors[0].opacity(isSelected ? 0.4 : 0.1), radius: isSelected ? 8 : 3, x: 0, y: isSelected ? 4 : 2)

                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(theme == .whiteGlow ? Color.black : Color.white)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
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

// MARK: - Support Developer

struct SupportDeveloperModal: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Support Scribe ☕️")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            
            Divider()
            
            VStack(spacing: 16) {
                Text("Scribe is an independent project supported entirely by user donations. If you find it useful, consider supporting its development. Donations are completely optional. Thank you!")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal)
                    .padding(.top, 16)
                    .padding(.bottom, 10)
                
                // Ko-fi Button
                Button {
                    if let url = URL(string: "https://ko-fi.com/alekseit") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "cup.and.saucer.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                        Text("Buy Me a Coffee on Ko-fi")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(
                                    LinearGradient(
                                        colors: [Color(red: 1.0, green: 0.36, blue: 0.35), Color(red: 1.0, green: 0.45, blue: 0.25)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                            RoundedRectangle(cornerRadius: 12)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.2), Color.clear],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        }
                    )
                    .shadow(color: Color(red: 1.0, green: 0.36, blue: 0.35).opacity(0.4), radius: 8, y: 4)
                }
                .buttonStyle(.plain)
                .padding(.horizontal)

                HStack {
                    Rectangle().frame(height: 1).foregroundStyle(Color.primary.opacity(0.1))
                    Text("or Crypto")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.tertiary)
                    Rectangle().frame(height: 1).foregroundStyle(Color.primary.opacity(0.1))
                }
                .padding(.horizontal)
                
                VStack(spacing: 10) {
                    CopyAddressRow(title: "USDT (TRC20)", address: "TDxy3x7N33wCgyTCKzsNHnfPu5kAyqk4EX", icon: "t.circle.fill", color: .green)
                    CopyAddressRow(title: "USDT (TON)", address: "UQDGb_rPU7i3gJ5mzrofTHxM13hEKAeoBRtZdCRRmb8UV6fE", icon: "t.circle.fill", color: .blue)
                    CopyAddressRow(title: "Bitcoin (BTC)", address: "16L68nCPuXGUfecU6oxKGgmFPyvz2om5iT", icon: "bitcoinsign.circle.fill", color: .orange)
                    CopyAddressRow(title: "Ethereum (ERC20)", address: "0x89bb769cc0636720f0544634bd6a3de33b73150f", icon: "diamond.circle.fill", color: .purple)
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            
            Spacer(minLength: 0)
        }
        .frame(width: 420, height: 600)
        .background(.ultraThinMaterial)
    }
}

struct CopyAddressRow: View {
    let title: String
    let address: String
    let icon: String
    let color: Color
    
    @State private var copied = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
            }
            
            HStack {
                Text(address)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                Spacer(minLength: 8)
                
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(address, forType: .string)
                    withAnimation { copied = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation { copied = false }
                    }
                } label: {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(copied ? Color.green : Color.primary)
                        .padding(6)
                        .background(Color.primary.opacity(0.08))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            .padding(10)
            .background(Color.primary.opacity(0.04))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            )
        }
    }
}
