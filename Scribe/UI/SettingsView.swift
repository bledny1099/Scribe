import SwiftUI
import KeyboardShortcuts
import FirebaseAuth

enum SettingsTab: String, CaseIterable {
    case general = "General"
    case appearance = "Appearance"
    case recognition = "Recognition"
    case vocabulary = "Vocabulary"
    case history = "History"
    case replacements = "Replacements"
    case integrations = "Integrations"
    case system = "System"
    case statistics = "Statistics"

    var icon: String {
        switch self {
        case .general:      return "slider.horizontal.3"
        case .appearance:   return "paintbrush.fill"
        case .recognition:  return "waveform.and.mic"
        case .vocabulary:   return "book.fill"
        case .history:      return "clock.arrow.circlepath"
        case .replacements: return "text.badge.plus"
        case .integrations: return "puzzlepiece.fill"
        case .system:       return "gearshape.fill"
        case .statistics:   return "chart.bar.fill"
        }
    }
}


/// Custom designed "Liquid Glass" settings view.
struct SettingsView: View {

    @State private var selectedTab: SettingsTab = .general
    @EnvironmentObject var appState: AppState
    @State private var showingSupportModal = false
    @State private var showingAuthModal = false
    @State private var showingAccountSettingsModal = false
    @State private var showingOnboardingNameModal = false

    // Supported multilingual models ordered by quality
    private let models: [(id: String, name: String, desc: String)] = [
        ("openai_whisper-small", "Small (Recommended)", "Great balance of high accuracy and speed (~460MB)"),
        ("openai_whisper-large-v3_turbo", "Large V3 Turbo", "Highest quality for complex speech & terms (~950MB)"),
        ("openai_whisper-base", "Base (Fastest)", "Lightweight and ultra fast, ideal for simple phrases (~140MB)")
    ]

    // Main settings categories in order (System as last main category)
    private let mainTabs: [SettingsTab] = [
        .general,
        .appearance,
        .recognition,
        .integrations,
        .vocabulary,
        .replacements,
        .history,
        .system
    ]

    var body: some View {
        ZStack(alignment: .top) {
            // Panel Appearance base background fill
            Group {
                switch appState.selectedPanelAppearance {
                case .dark:
                    Color(red: 0.05, green: 0.05, blue: 0.07).opacity(0.85)
                case .liquidGlass:
                    Color.clear
                case .light:
                    Color.white.opacity(0.85)
                }
            }
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.4), value: appState.selectedPanelAppearance)

            // Complex Cyber Ambient Background Glow & Neon Mesh (disabled on Liquid Glass for 100% crystal transparency)
            if appState.selectedPanelAppearance != .liquidGlass {
                ZStack {
                    RadialGradient(
                        gradient: Gradient(colors: [
                            appState.selectedTheme.glowColor.opacity(0.22),
                            appState.selectedTheme.gradientColors[0].opacity(0.08),
                            Color.clear
                        ]),
                        center: .topLeading,
                        startRadius: 10,
                        endRadius: 650
                    )
                    
                    RadialGradient(
                        gradient: Gradient(colors: [
                            appState.selectedTheme.gradientColors[1].opacity(0.12),
                            Color.clear
                        ]),
                        center: .bottomTrailing,
                        startRadius: 50,
                        endRadius: 500
                    )
                }
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.6), value: appState.selectedTheme)
            }

            TranscriptionHistory.shared.currentLevelColor.opacity(selectedTab == .statistics ? 0.12 : 0)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.5), value: selectedTab)
            
            HStack(alignment: .top, spacing: 0) {
                // Sidebar — Cyber Command Dock
                VStack(alignment: .leading, spacing: 6) {
                    // Main Categories (ending with System)
                    ForEach(mainTabs, id: \.self) { tab in
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedTab = tab
                            }
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: tab.icon)
                                    .font(.system(size: 13, weight: selectedTab == tab ? .bold : .medium))
                                    .foregroundStyle(selectedTab == tab ? .primary : .secondary)
                                    .frame(width: 18)

                                Text(appState.l(tab.rawValue))
                                    .font(.system(size: 13, weight: selectedTab == tab ? .bold : .medium, design: .rounded))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                                Spacer()
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(selectedTab == tab ? appState.selectedTheme.gradientColors.first!.opacity(0.2) : Color.clear)
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }

                    // Divider Line after System
                    Divider()
                        .opacity(0.4)
                        .padding(.vertical, 4)

                    // Statistics Tab Button
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedTab = .statistics
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: SettingsTab.statistics.icon)
                                .font(.system(size: 13, weight: selectedTab == .statistics ? .bold : .medium))
                                .foregroundStyle(selectedTab == .statistics ? .primary : .secondary)
                                .frame(width: 18)

                            Text(appState.l(SettingsTab.statistics.rawValue))
                                .font(.system(size: 13, weight: selectedTab == .statistics ? .bold : .medium, design: .rounded))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            Spacer()
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(selectedTab == .statistics ? appState.selectedTheme.gradientColors.first!.opacity(0.2) : Color.clear)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    // Support Scribe Button (Redesigned & Compact)
                    Button(action: {
                        showingSupportModal = true
                    }) {
                        HStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.pink.opacity(0.25), Color.orange.opacity(0.25)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 22, height: 22)
                                
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.pink, .orange],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            }

                            Text(appState.l("Support Scribe"))
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)

                            Spacer(minLength: 4)

                            Image(systemName: "cup.and.saucer.fill")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.secondary.opacity(0.7))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.primary.opacity(0.03))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(Color.pink.opacity(0.25), lineWidth: 0.8)
                        )
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    // Bottom Left Account & Subscription Footer
                    SidebarAccountFooterView(
                        showingAuthModal: $showingAuthModal,
                        showingAccountSettingsModal: $showingAccountSettingsModal
                    )
                }
                .frame(width: 200)
                .padding(.top, 88)
                .padding(.bottom, 16)
                .padding(.horizontal, 10)
                .background(Color.primary.opacity(0.015))
                .sheet(isPresented: $showingSupportModal) {
                    SupportDeveloperModal()
                }
                .sheet(isPresented: $showingAuthModal) {
                    AuthModalView()
                }
                .sheet(isPresented: $showingAccountSettingsModal) {
                    AccountSettingsModalView()
                }
                .sheet(isPresented: $showingOnboardingNameModal) {
                    OnboardingNameModalView()
                }
                .onAppear {
                    if !UserDefaults.standard.bool(forKey: "hasCompletedOnboardingNamePrompt") {
                        showingOnboardingNameModal = true
                    }
                }

                Rectangle()
                    .fill(Color.primary.opacity(0.06))
                    .frame(width: 1)

                // Main Content
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(spacing: 20) {
                        switch selectedTab {
                        case .general:
                            GeneralSettingsView()
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

                            // Show recording timer
                            HStack {
                                Text(appState.l("Show Recording Timer"))
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundStyle(.primary)
                                Spacer()
                                Toggle("", isOn: $appState.durationVisible)
                                    .toggleStyle(.switch)
                                    .labelsHidden()
                            }

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

                        case .recognition:
                    // SECTION: Language & Model
                    GlassSection(title: appState.l("Recognition"), icon: "waveform.and.mic") {
                        VStack(spacing: 16) {
                            // Aether Presentation
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        HStack(spacing: 6) {
                                            Text("Aether")
                                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                                .foregroundStyle(.primary)
                                            
                                            HStack(spacing: 4) {
                                                Circle()
                                                    .fill(Color.green)
                                                    .frame(width: 6, height: 6)
                                                Text(appState.l("3-Stage Pipeline Active"))
                                                    .font(.system(size: 10, weight: .medium, design: .rounded))
                                                    .foregroundStyle(.primary.opacity(0.85))
                                            }
                                            .padding(.horizontal, 7)
                                            .padding(.vertical, 2.5)
                                            .background(
                                                Capsule()
                                                    .fill(Color.primary.opacity(0.08))
                                                    .overlay(
                                                        Capsule().stroke(Color.primary.opacity(0.12), lineWidth: 0.5)
                                                    )
                                            )
                                        }
                                    }
                                    Spacer()
                                    LiquidGlassMenu(
                                        items: [
                                            "Aether Hybrid (Recommended)",
                                            "Aether Turbo",
                                            "Aether Instant"
                                        ],
                                        selection: $appState.recognitionEngine,
                                        title: { id in appState.l(id) },
                                        displayTitle: { id in
                                            id.contains("Hybrid") ? appState.l("Aether Hybrid") : appState.l(id)
                                        }
                                    )
                                }
                                
                                Text(appState.l("Aether combines Audio VAD, dynamic app context conditioning, and lexical fuzzy matching for zero-hallucination, studio-grade speech transcription."))
                                    .font(.system(size: 11, weight: .regular))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(3)
                            }

                            HStack {
                                Text(appState.l("Recognition Mode"))
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundStyle(.primary)
                                Spacer()
                                LiquidGlassMenu(
                                    items: ["multilingual", "singleLanguage"],
                                    selection: $appState.recognitionMode,
                                    title: { id in
                                        id == "multilingual" ? appState.l("Multilingual Mode (2-3 Languages)") : appState.l("Single Language Mode")
                                    },
                                    displayTitle: { id in
                                        id == "multilingual" ? appState.l("Multilingual Mode") : appState.l("Single Language Mode")
                                    }
                                )
                            }
                            
                            if appState.recognitionMode == "singleLanguage" {
                                HStack {
                                    Text(appState.l("Single Language"))
                                        .font(.system(size: 14, weight: .medium, design: .rounded))
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    LiquidGlassLanguageMenu(
                                        items: supportedLanguages.filter { $0.id != "auto" },
                                        selection: $appState.singleDictationLanguage
                                    )
                                }
                            } else {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(appState.l("Dictation Languages"))
                                            .font(.system(size: 14, weight: .medium, design: .rounded))
                                            .foregroundStyle(.primary)
                                        Text(appState.l("Select up to 3 languages for auto-switching"))
                                            .font(.system(size: 11))
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    LiquidGlassMultiLanguageMenu(
                                        items: supportedLanguages,
                                        selectedLanguages: appState.multilingualLanguages,
                                        onToggle: { appState.toggleMultilingualLanguage($0) }
                                    )
                                }
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
                        }
                    }



                        case .statistics:
                            StatisticsSectionView()
                        case .replacements:
                            ReplacementsSettingsView()
                        case .integrations:
                            IntegrationsSettingsView()
                        case .vocabulary:
                            VocabularySettingsView()
                        case .history:
                            GlassSection(title: appState.l("History"), icon: "clock.arrow.circlepath") {
                                HistoryView(inSettings: true)
                            }
                        case .system:
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

                            PermissionsCard()
                        }
                    }
                    }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 88)
                    .padding(.bottom, 24)
                }
            }
            
            // Header — Draggable Cyber Glass Console Header
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Text("Scribe")
                            .font(.system(size: 20, weight: .bold, design: .default))
                            .tracking(1.2)
                            .foregroundStyle(.primary)
                    }

                    Spacer()

                    // Sleek Cyber Close Button
                    Button(action: { SettingsWindowManager.shared.closeWindow() }) {
                        ZStack {
                            Circle()
                                .fill(Color.primary.opacity(0.06))
                                .frame(width: 28, height: 28)

                            Image(systemName: "xmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.primary.opacity(0.75))
                        }
                        .overlay(
                            Circle()
                                .stroke(Color.primary.opacity(0.14), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 22)
                .padding(.top, 16)
                .padding(.bottom, 14)
                .background(WindowDragView())
            }
        }
        .ignoresSafeArea(.container, edges: .top)
                .frame(height: 620)
        .onAppear {
            if let tab = appState.requestedSettingsTab {
                selectedTab = tab
                appState.requestedSettingsTab = nil
            }
        }
        .onChange(of: appState.requestedSettingsTab) { newTab in
            if let tab = newTab {
                selectedTab = tab
                appState.requestedSettingsTab = nil
            }
        }
        .onChange(of: selectedTab) { _ in
        }
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
        .preferredColorScheme(
            appState.selectedPanelAppearance == .dark ? .dark : (appState.selectedPanelAppearance == .light ? .light : nil)
        )
    }
}

// MARK: - Statistics Section Component


enum CertificateColorTheme: String, CaseIterable, Identifiable {
    case gold = "Gold Theme"
    case levelColor = "Level Theme"

    var id: String { rawValue }
}

struct StatisticsSectionView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var history = TranscriptionHistory.shared
    @State private var timeFrame: StatsTimeFrame = .today
    @AppStorage("goldCertColorTheme") private var certColorThemeRaw: String = CertificateColorTheme.gold.rawValue
    @State private var showTopWords: Bool = false

    private var selectedTheme: CertificateColorTheme {
        CertificateColorTheme(rawValue: certColorThemeRaw) ?? .gold
    }
    
    // Animation states
    @State private var isPulsing = false
    @State private var isShimmering = false
    @State private var appearAnimation = false

    var body: some View {
        VStack(spacing: 20) {
            // Certificate Color Theme Switcher Row
            HStack {
                Text(appState.l("Certificate Color"))
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
                LiquidGlassSegmentedPicker(
                    items: CertificateColorTheme.allCases,
                    selection: Binding(
                        get: { selectedTheme },
                        set: { certColorThemeRaw = $0.rawValue }
                    ),
                    label: { (appState.l($0.rawValue), "") }
                )
            }

            // Imperial Certificate Card
            GoldCertificateCardView(
                isPulsing: isPulsing,
                isShimmering: isShimmering,
                showTopWords: $showTopWords
            )
            .scaleEffect(appearAnimation ? 1 : 0.96)
            .opacity(appearAnimation ? 1 : 0)
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: certColorThemeRaw)
            
            // Top Spoken Words Expansion Drawer
            if showTopWords {
                GlassSection(title: appState.l("Top Spoken Words"), icon: "text.quote") {
                    VStack(alignment: .leading, spacing: 10) {
                        if history.topSpokenWords.isEmpty {
                            Text(appState.l("No dictation history yet"))
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        } else {
                            FlowLayout(spacing: 8) {
                                ForEach(history.topSpokenWords, id: \.word) { item in
                                    HStack(spacing: 5) {
                                        Text(item.word)
                                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                                            .foregroundStyle(.primary)
                                        Text("\(item.count)")
                                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 1)
                                            .background(Color.primary.opacity(0.1))
                                            .cornerRadius(6)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(.ultraThinMaterial)
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                                    )
                                }
                            }
                        }
                    }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            // Transcription Stats Grid
            GlassSection(title: appState.l("Statistics"), icon: "chart.bar.fill") {
                VStack(spacing: 14) {
                    LiquidGlassSegmentedPicker(
                        items: StatsTimeFrame.allCases,
                        selection: $timeFrame,
                        label: { (appState.l($0.rawValue), "") }
                    )

                    let stats = history.stats(for: timeFrame)

                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                        StatCard(title: appState.l("Words Spoken"), value: formatNumber(stats.wordCount), icon: "text.quote", color: .blue)
                        StatCard(title: appState.l("Characters"), value: formatNumber(stats.charCount), icon: "textformat", color: .purple)
                        StatCard(title: appState.l("Time Dictated"), value: formatDuration(stats.duration), icon: "timer", color: .orange)
                        StatCard(title: appState.l("Sessions"), value: formatNumber(stats.sessionCount), icon: "mic.fill", color: .green)
                    }
                }
            }
        }
        .onAppear {
            isPulsing = true
            withAnimation(.linear(duration: 2.5).repeatForever(autoreverses: false)) {
                isShimmering = true
            }
            appearAnimation = true
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
        if hours > 0 { return "\(hours)h \(mins)m" }
        else if mins > 0 { return "\(mins)m \(secs)s" }
        else { return "\(secs)s" }
    }
}
// MARK: - Profile Card 1: Cyber Glass Shield VIP Pass
struct CyberShieldCardView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var history = TranscriptionHistory.shared
    var isPulsing: Bool
    var isShimmering: Bool

    var body: some View {
        VStack(spacing: 16) {
            // Top Header: Holographic Shield Badge & VIP Rank Pill
            HStack(alignment: .center) {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(history.currentLevelColor.opacity(0.18))
                            .frame(width: 36, height: 36)
                            .shadow(color: history.currentLevelColor.opacity(0.4), radius: 6)

                        Image(systemName: "bolt.shield.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(history.currentLevelColor)
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        Text("SCRIBE VIP PASS")
                            .font(.system(size: 9, weight: .black, design: .rounded))
                            .foregroundStyle(.secondary)
                            .tracking(1.4)

                        Text("\(appState.l(history.currentLevelName))")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(history.currentLevelColor)
                    }
                }

                Spacer()

                // Glowing Level Badge Pill
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(history.currentLevelColor)

                    Text("LEVEL \(history.currentLevel)")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(.primary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(history.currentLevelColor.opacity(0.15))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(history.currentLevelColor.opacity(0.35), lineWidth: 1)
                )
            }

            // User Name Title Row
            VStack(alignment: .leading, spacing: 2) {
                TextField(appState.l("Name or Nickname"), text: $appState.userName)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .textFieldStyle(.plain)
                    .foregroundStyle(.primary)

                Text(appState.l("Voice Dictation & Speech Mastery"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Divider().opacity(0.3)

            // Dual Frosted Glass Metric Cards
            HStack(spacing: 12) {
                // Metric 1: Streak Card
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.orange.opacity(0.18))
                            .frame(width: 36, height: 36)

                        Image(systemName: "flame.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(
                                LinearGradient(colors: [.orange, .yellow], startPoint: .bottom, endPoint: .top)
                            )
                            .scaleEffect(isPulsing ? 1.12 : 0.95)
                            .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: isPulsing)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(appState.l("DAY STREAK"))
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .foregroundStyle(.secondary)

                        Text("\(history.dayStreak) \(appState.l("Days"))")
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .foregroundStyle(.orange)
                    }
                    Spacer(minLength: 0)
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.orange.opacity(0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.orange.opacity(0.2), lineWidth: 1)
                        )
                )

                // Metric 2: Total Words Card
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(history.currentLevelColor.opacity(0.18))
                            .frame(width: 36, height: 36)

                        Image(systemName: "text.quote")
                            .font(.system(size: 16))
                            .foregroundStyle(history.currentLevelColor)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(appState.l("WORDS SPOKEN"))
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .foregroundStyle(.secondary)

                        Text("\(history.totalWords)")
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .foregroundStyle(.primary)
                    }
                    Spacer(minLength: 0)
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(history.currentLevelColor.opacity(0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(history.currentLevelColor.opacity(0.2), lineWidth: 1)
                        )
                )
            }

            // XP Progress Bar with Floating Diamond Runner Node
            VStack(spacing: 6) {
                HStack {
                    Text(appState.l("LEVEL XP PROGRESS"))
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text("\(history.totalWords) / \(history.totalWords + history.wordsToNextLevel) XP (\(Int(history.currentLevelProgress * 100))%)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(history.currentLevelColor)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.primary.opacity(0.06))

                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [history.currentLevelColor, history.currentLevelColor.opacity(0.65), history.currentLevelColor],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(8, geo.size.width * CGFloat(history.currentLevelProgress)))
                            .shadow(color: history.currentLevelColor.opacity(0.5), radius: 6)

                        // Floating Glowing Diamond Node
                        Image(systemName: "rhombus.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(history.currentLevelColor)
                            .shadow(color: history.currentLevelColor, radius: 5)
                            .offset(x: max(0, min(geo.size.width - 10, geo.size.width * CGFloat(history.currentLevelProgress) - 5)))
                    }
                }
                .frame(height: 8)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.primary.opacity(0.035))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(
                    LinearGradient(
                        colors: [history.currentLevelColor.opacity(0.6), Color.primary.opacity(0.08), history.currentLevelColor.opacity(0.35)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        .shadow(color: Color.black.opacity(0.08), radius: 14, x: 0, y: 6)
    }
}

// MARK: - Profile Card 2: Imperial Royal Certificate
struct GoldCertificateCardView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var history = TranscriptionHistory.shared
    @AppStorage("goldCertColorTheme") private var colorThemeRaw: String = CertificateColorTheme.gold.rawValue
    var isPulsing: Bool
    var isShimmering: Bool
    @Binding var showTopWords: Bool

    private var isLevelTheme: Bool {
        colorThemeRaw == CertificateColorTheme.levelColor.rawValue
    }

    private var themeColor: Color {
        isLevelTheme ? history.currentLevelColor : .yellow
    }

    private var secondaryThemeColor: Color {
        isLevelTheme ? history.currentLevelColor.opacity(0.8) : .orange
    }

    private var themeGradient: LinearGradient {
        if isLevelTheme {
            return LinearGradient(colors: [history.currentLevelColor, history.currentLevelColor.opacity(0.7), history.currentLevelColor], startPoint: .leading, endPoint: .trailing)
        } else {
            return LinearGradient(colors: [.yellow, Color(red: 0.95, green: 0.75, blue: 0.2), .yellow], startPoint: .leading, endPoint: .trailing)
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            // Filigree Header Line
            HStack {
                Text("✦ \(appState.l("OFFICIAL RECORD").uppercased()) ✦")
                    .font(.system(size: 8, weight: .black, design: .serif))
                    .foregroundStyle(themeGradient)
                    .tracking(2.5)

                Spacer()

                Text("EST. 2026")
                    .font(.system(size: 8, weight: .bold, design: .serif))
                    .foregroundStyle(.secondary)
            }

            // Header Section: Crown & Title & Wax Ribbon Seal
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(themeGradient)

                        Text(appState.l("CERTIFICATE OF MASTERY"))
                            .font(.system(size: 10, weight: .black, design: .serif))
                            .foregroundStyle(themeColor)
                            .tracking(1.8)
                    }

                    TextField(appState.l("Name or Nickname"), text: $appState.userName)
                        .font(.system(size: 24, weight: .bold, design: .serif))
                        .textFieldStyle(.plain)
                        .foregroundStyle(themeGradient)
                        .shadow(color: secondaryThemeColor.opacity(0.3), radius: 6)

                    Text(appState.l("Conferred for outstanding dedication and voice dictation mastery"))
                        .font(.system(size: 11, weight: .medium, design: .serif))
                        .italic()
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Wax Seal Badge
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: isLevelTheme ?
                                    [history.currentLevelColor, history.currentLevelColor.opacity(0.7), history.currentLevelColor] :
                                    [.yellow, .orange, Color(red: 0.8, green: 0.5, blue: 0.0)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)
                        .shadow(color: secondaryThemeColor.opacity(0.5), radius: 8)

                    Circle()
                        .stroke(Color.white.opacity(0.4), lineWidth: 1)
                        .frame(width: 42, height: 42)

                    Image(systemName: "rosette")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white)
                }
            }

            Divider().opacity(0.3)

            // 4 Imperial Gold Seals Grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                // Seal 1: Level Rank
                HStack(spacing: 10) {
                    ZStack {
                        Circle().fill(themeColor.opacity(0.15)).frame(width: 32, height: 32)
                        Image(systemName: "star.fill").font(.system(size: 14)).foregroundStyle(themeColor)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text(appState.l("RANK TIER"))
                            .font(.system(size: 8, weight: .bold, design: .serif))
                            .foregroundStyle(.secondary)
                        Text(appState.l(history.currentLevelName))
                            .font(.system(size: 11, weight: .bold, design: .serif))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .padding(8)
                .background(themeColor.opacity(0.04))
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(themeColor.opacity(0.2), lineWidth: 1))

                // Seal 2: Day Streak
                HStack(spacing: 10) {
                    ZStack {
                        Circle().fill(Color.orange.opacity(0.15)).frame(width: 32, height: 32)
                        Image(systemName: "flame.fill").font(.system(size: 14)).foregroundStyle(.orange)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text(appState.l("STREAK HONOUR"))
                            .font(.system(size: 8, weight: .bold, design: .serif))
                            .foregroundStyle(.secondary)
                        Text("\(history.dayStreak) \(appState.l("Active Days"))")
                            .font(.system(size: 11, weight: .bold, design: .serif))
                            .foregroundStyle(.orange)
                    }
                    Spacer(minLength: 0)
                }
                .padding(8)
                .background(Color.orange.opacity(0.04))
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.orange.opacity(0.2), lineWidth: 1))

                // Seal 3: Volume Dictated (Clickable to Toggle Top Spoken Words!)
                Button(action: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                        showTopWords.toggle()
                    }
                }) {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle().fill(themeColor.opacity(0.15)).frame(width: 32, height: 32)
                            Image(systemName: "text.quote").font(.system(size: 13)).foregroundStyle(themeColor)
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            HStack(spacing: 4) {
                                Text(appState.l("VOLUME AWARD"))
                                    .font(.system(size: 8, weight: .bold, design: .serif))
                                    .foregroundStyle(.secondary)
                                Image(systemName: showTopWords ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(themeColor)
                            }
                            Text("\(history.totalWords) \(appState.l("Words"))")
                                .font(.system(size: 11, weight: .bold, design: .serif))
                                .foregroundStyle(.primary)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(8)
                    .background(themeColor.opacity(showTopWords ? 0.12 : 0.04))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(themeColor.opacity(showTopWords ? 0.4 : 0.2), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

                // Seal 4: XP Distinction
                HStack(spacing: 10) {
                    ZStack {
                        Circle().fill(themeColor.opacity(0.15)).frame(width: 32, height: 32)
                        Image(systemName: "chart.line.uptrend.xyaxis").font(.system(size: 13)).foregroundStyle(themeColor)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text(appState.l("PROGRESS"))
                            .font(.system(size: 8, weight: .bold, design: .serif))
                            .foregroundStyle(.secondary)
                        Text("\(Int(history.currentLevelProgress * 100))% \(appState.l("Mastery"))")
                            .font(.system(size: 11, weight: .bold, design: .serif))
                            .foregroundStyle(themeColor)
                    }
                    Spacer(minLength: 0)
                }
                .padding(8)
                .background(themeColor.opacity(0.04))
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(themeColor.opacity(0.2), lineWidth: 1))
            }

            // Progress Filament with Remaining Words Counter Below
            VStack(spacing: 8) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.primary.opacity(0.06))
                        Capsule()
                            .fill(themeGradient)
                            .frame(width: max(6, geo.size.width * CGFloat(history.currentLevelProgress)))
                            .shadow(color: secondaryThemeColor.opacity(0.5), radius: 5)
                    }
                }
                .frame(height: 8)

                // Subtitle: Words remaining for next level
                HStack {
                    Text("\(history.wordsToNextLevel) \(appState.l("words to Level")) \(history.currentLevel + 1)")
                        .font(.system(size: 11, weight: .semibold, design: .serif))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text("\(history.totalWords) / \(history.totalWords + history.wordsToNextLevel) \(appState.l("words"))")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(themeColor)
                }
                .padding(.top, 4)
            }
        }
        .padding(20)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 22)
                    .fill(Color(nsColor: .windowBackgroundColor).opacity(0.7))
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))

                // Filigree Border
                RoundedRectangle(cornerRadius: 22)
                    .stroke(themeGradient, lineWidth: 1.8)
            }
        )
        .shadow(color: secondaryThemeColor.opacity(0.12), radius: 18, x: 0, y: 8)
    }
}

// MARK: - Profile Card 3: Apple Executive Rings
struct AppleRingsCardView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var history = TranscriptionHistory.shared
    var isPulsing: Bool

    var body: some View {
        HStack(spacing: 20) {
            // Dual Concentric XP Activity Rings
            ZStack {
                // Outer Ring: Level XP Progress
                Circle()
                    .stroke(history.currentLevelColor.opacity(0.15), lineWidth: 7)
                    .frame(width: 68, height: 68)

                Circle()
                    .trim(from: 0, to: CGFloat(history.currentLevelProgress))
                    .stroke(
                        LinearGradient(colors: [history.currentLevelColor, .yellow], startPoint: .top, endPoint: .bottom),
                        style: StrokeStyle(lineWidth: 7, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 68, height: 68)
                    .shadow(color: history.currentLevelColor.opacity(0.4), radius: 6)

                // Inner Ring: Day Streak Progress
                Circle()
                    .stroke(Color.orange.opacity(0.15), lineWidth: 5)
                    .frame(width: 50, height: 50)

                Circle()
                    .trim(from: 0, to: min(1.0, CGFloat(history.dayStreak) / 7.0))
                    .stroke(
                        LinearGradient(colors: [.orange, .red], startPoint: .top, endPoint: .bottom),
                        style: StrokeStyle(lineWidth: 5, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 50, height: 50)

                VStack(spacing: 0) {
                    Text("\(history.currentLevel)")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(.primary)
                    Text("LVL")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                TextField(appState.l("Name or Nickname"), text: $appState.userName)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .textFieldStyle(.plain)

                HStack(spacing: 8) {
                    // Pill 1: Day Streak
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill").font(.system(size: 11)).foregroundStyle(.orange)
                        Text("\(history.dayStreak) \(appState.l("Days"))")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.12))
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.orange.opacity(0.2), lineWidth: 1))

                    // Pill 2: Rank
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill").font(.system(size: 10)).foregroundStyle(history.currentLevelColor)
                        Text(appState.l(history.currentLevelName))
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(history.currentLevelColor.opacity(0.12))
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(history.currentLevelColor.opacity(0.2), lineWidth: 1))
                }

                Text("\(history.totalWords) / \(history.totalWords + history.wordsToNextLevel) \(appState.l("words spoken"))")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.primary.opacity(0.035))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 5)
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
                    .foregroundStyle(Color.primary.opacity(0.72))
            }
            .padding(.horizontal, 4)

            content
                .padding(16)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial.opacity(0.6))
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.primary.opacity(0.06))
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
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
                        .fill(
                            LinearGradient(
                                colors: [Color.primary.opacity(0.045), Color.primary.opacity(0.02)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.primary.opacity(0.09), lineWidth: 1)
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
struct LiquidGlassSegmentedPicker<T: Hashable>: View {
    let items: [T]
    @Binding var selection: T
    let label: (T) -> (name: String, icon: String)

    @Namespace private var segmentAnimation

    var body: some View {
        HStack(spacing: 3) {
            ForEach(items, id: \.self) { item in
                let isSelected = (item as AnyHashable) == (selection as AnyHashable)
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.75)) {
                        selection = item
                    }
                } label: {
                    let info = label(item)
                    HStack(spacing: (!info.icon.isEmpty && !info.name.isEmpty) ? 6 : 0) {
                        if !info.icon.isEmpty {
                            Image(systemName: info.icon)
                                .font(.system(size: 11, weight: isSelected ? .bold : .semibold))
                                .foregroundStyle(isSelected ? .white : .primary.opacity(0.7))
                        }
                        if !info.name.isEmpty {
                            Text(info.name)
                                .font(.system(size: 12, weight: isSelected ? .bold : .medium, design: .rounded))
                                .foregroundStyle(isSelected ? .white : .primary.opacity(0.75))
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(
                        ZStack {
                            if isSelected {
                                // 1. Base Glass Material
                                Capsule()
                                    .fill(.ultraThinMaterial)
                                    .matchedGeometryEffect(id: "segmentBgMaterial", in: segmentAnimation)

                                // 2. Liquid Glass Gradient Tint
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.28),
                                                Color.white.opacity(0.12),
                                                Color.white.opacity(0.04)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .matchedGeometryEffect(id: "segmentBg", in: segmentAnimation)

                                // 3. Glossy Top Specular Reflection Glare
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.45),
                                                Color.white.opacity(0.15),
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
                                                Color.white.opacity(0.75),
                                                Color.white.opacity(0.35),
                                                Color.white.opacity(0.15)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1.0
                                    )
                                    .matchedGeometryEffect(id: "segmentBorder", in: segmentAnimation)
                            }
                        }
                    )
                    .shadow(color: isSelected ? Color.black.opacity(0.35) : Color.clear, radius: 6, x: 0, y: 3)
                    .shadow(color: isSelected ? Color.white.opacity(0.2) : Color.clear, radius: 4, x: 0, y: -1)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            ZStack {
                Capsule()
                    .fill(.ultraThinMaterial.opacity(0.85))

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.25),
                                Color.black.opacity(0.15)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
        )
        .overlay(
            Capsule()
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.25),
                            Color.white.opacity(0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.0
                )
        )
    }
}

// MARK: - Liquid Glass Menu

/// A liquid glass dropdown menu button matching macOS glossy glass style.
struct LiquidGlassMenu<T: Hashable>: View {
    let items: [T]
    @Binding var selection: T
    let title: (T) -> String
    var displayTitle: ((T) -> String)? = nil

    private func cleanDisplayTitle(_ raw: String) -> String {
        if let custom = displayTitle {
            return custom(selection)
        }
        // Remove anything in parentheses (e.g. " (Recommended)", " (2-3 Languages)", " (Рекомендуется)")
        if let regex = try? NSRegularExpression(pattern: "\\s*\\([^)]*\\)") {
            let range = NSRange(raw.startIndex..<raw.endIndex, in: raw)
            return regex.stringByReplacingMatches(in: raw, options: [], range: range, withTemplate: "").trimmingCharacters(in: .whitespaces)
        }
        return raw
    }

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
                Text(cleanDisplayTitle(title(selection)))
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

// MARK: - Liquid Glass Multi-Language Menu

/// A specialized menu button that supports multi-selecting 2-3 languages for multilingual mode.
struct LiquidGlassMultiLanguageMenu: View {
    let items: [LanguageOption]
    let selectedLanguages: [String]
    let onToggle: (String) -> Void

    private var displayTitle: String {
        let validItems = items.flatMap { [$0] + ($0.children ?? []) }
        let names = selectedLanguages.compactMap { id -> String? in
            guard let item = validItems.first(where: { $0.id == id }) else { return id.uppercased() }
            let clean = item.name.components(separatedBy: " (").first ?? item.name
            return clean
        }
        if names.isEmpty {
            return "Select 2-3 Languages"
        }
        return names.joined(separator: ", ")
    }

    var body: some View {
        Menu {
            ForEach(items.filter { $0.id != "auto" }, id: \.id) { lang in
                if let children = lang.children {
                    Menu(lang.name) {
                        ForEach(children, id: \.id) { child in
                            Button {
                                withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                                    onToggle(child.id)
                                }
                            } label: {
                                if selectedLanguages.contains(child.id) {
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
                            onToggle(lang.id)
                        }
                    } label: {
                        if selectedLanguages.contains(lang.id) {
                            Label(lang.name, systemImage: "checkmark")
                        } else {
                            Text(lang.name)
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(displayTitle)
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
            .frame(minWidth: 180, maxWidth: 220)
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
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(appState.l("Support Scribe") + " ☕️")
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
                Text(appState.l("Scribe is an independent project supported entirely by user donations. If you find it useful, consider supporting its development. Donations are completely optional. Thank you!"))
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
                        Text(appState.l("Buy Me a Coffee on Ko-fi"))
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
                    Text(appState.l("or Crypto"))
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

// MARK: - Window Drag Helper

/// An NSView-backed drag area that allows moving the parent window by dragging.
/// Used instead of `isMovableByWindowBackground` which intercepts ALL clicks on the window background.
struct WindowDragView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = WindowDragNSView()
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

private class WindowDragNSView: NSView {
    override var mouseDownCanMoveWindow: Bool { true }

    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }
}

// MARK: - App Icon Helpers & Renderers
struct AppIconHelper {
    static func icon(for bundleId: String, fallbackPath: String? = nil, resourceName: String? = nil) -> NSImage? {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        if let path = fallbackPath, FileManager.default.fileExists(atPath: path) {
            return NSWorkspace.shared.icon(forFile: path)
        }
        if let res = resourceName {
            if let img = NSImage(named: res) {
                return img
            }
            if let path = Bundle.main.path(forResource: res, ofType: "png"), let img = NSImage(contentsOfFile: path) {
                return img
            }
            let devPath = "/Users/aleksei/Documents/Scribe/Scribe/\(res).png"
            if FileManager.default.fileExists(atPath: devPath), let img = NSImage(contentsOfFile: devPath) {
                return img
            }
        }
        return nil
    }
}

struct AppleNotesAppIconView: View {
    var size: CGFloat = 26

    var body: some View {
        if let nsImage = AppIconHelper.icon(for: "com.apple.Notes", fallbackPath: "/System/Applications/Notes.app", resourceName: "AppleNotesIcon") {
            Image(nsImage: nsImage)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
                .shadow(color: Color.black.opacity(0.15), radius: 1, y: 0.5)
        } else {
            Image(systemName: "note.text")
                .font(.system(size: size * 0.6))
                .frame(width: size, height: size)
        }
    }
}

struct ObsidianAppIconView: View {
    var size: CGFloat = 26

    var body: some View {
        if let nsImage = AppIconHelper.icon(for: "md.obsidian", fallbackPath: "/Applications/Obsidian.app", resourceName: "ObsidianIcon") {
            Image(nsImage: nsImage)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
                .shadow(color: Color.black.opacity(0.15), radius: 1, y: 0.5)
        } else {
            Image(systemName: "doc.text.fill")
                .font(.system(size: size * 0.6))
                .frame(width: size, height: size)
        }
    }
}

struct NotionAppIconView: View {
    var size: CGFloat = 26

    var body: some View {
        if let nsImage = AppIconHelper.icon(for: "notion.id", fallbackPath: "/Applications/Notion.app", resourceName: "NotionIcon") {
            Image(nsImage: nsImage)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
                .shadow(color: Color.black.opacity(0.15), radius: 1, y: 0.5)
        } else {
            Image(systemName: "square.text.square.fill")
                .font(.system(size: size * 0.6))
                .frame(width: size, height: size)
        }
    }
}

// MARK: - Integrations Settings View
struct IntegrationsSettingsView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(spacing: 16) {
            // General Output Mode Card
            GlassSection(title: appState.l("Output Options"), icon: "slider.horizontal.3") {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(appState.l("Add Date & Time Header"))
                                .font(.system(size: 13, weight: .semibold))
                            Text(appState.l("Prefix exported notes with timestamp (e.g. 11.08.2026 17:21)"))
                                .font(.system(size: 11))
                                .foregroundStyle(Color.primary.opacity(0.70))
                        }
                        Spacer()
                        Toggle("", isOn: $appState.appendDateToNotes)
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }
                }
            }
            
            // Unified Note Apps Card (All apps together)
            GlassSection(title: appState.l("Supported Note Apps"), icon: "arrow.triangle.branch") {
                VStack(alignment: .leading, spacing: 16) {
                    // Apple Notes Row
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            HStack(spacing: 10) {
                                AppleNotesAppIconView(size: 26)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Apple Notes")
                                        .font(.system(size: 14, weight: .bold))
                                    Text(appState.l("Send transcripts directly to Apple Notes"))
                                        .font(.system(size: 11))
                                        .foregroundStyle(Color.primary.opacity(0.70))
                                }
                            }
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { appState.enableAppleNotes },
                                set: { val in
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                        appState.enableAppleNotes = val
                                    }
                                }
                            ))
                            .toggleStyle(.switch)
                            .labelsHidden()
                        }
                        
                        if appState.enableAppleNotes {
                            VStack(alignment: .leading, spacing: 10) {
                                // Mode Selector: New note vs Single note
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(appState.l("Save Destination:"))
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(.secondary)
                                    
                                    LiquidGlassSegmentedPicker(
                                        items: [ExportMode.append, ExportMode.newNote],
                                        selection: Binding(
                                            get: { appState.appleNotesExportMode },
                                            set: { appState.appleNotesExportMode = $0 }
                                        ),
                                        label: { mode in
                                            switch mode {
                                            case .append:
                                                return (name: appState.l("Single Note (Append)"), icon: "note.text")
                                            case .newNote:
                                                return (name: appState.l("New Note per Speech"), icon: "doc.badge.plus")
                                            }
                                        }
                                    )
                                }
                                
                                if appState.appleNotesExportMode == .append {
                                    HStack(spacing: 8) {
                                        Text(appState.l("Target Note:"))
                                            .font(.system(size: 12, weight: .medium))
                                        NotePickerView(
                                            targetNote: $appState.appleNotesTargetNote,
                                            appType: .appleNotes,
                                            vaultURL: ""
                                        )
                                        
                                        Button(action: {
                                            appState.appleNotesTargetNote = "Scribe Notes"
                                        }) {
                                            HStack(spacing: 4) {
                                                Image(systemName: "note.text.badge.plus")
                                                    .font(.system(size: 10))
                                                Text(appState.l("Use 'Scribe Notes'"))
                                                    .font(.system(size: 11, weight: .medium))
                                            }
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.primary.opacity(0.06))
                                            .cornerRadius(6)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 6)
                                                    .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
                                            )
                                        }
                                        .buttonStyle(.plain)
                                        .help(appState.l("Set destination to dedicated Scribe note"))
                                    }
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                                } else {
                                    HStack(spacing: 6) {
                                        Image(systemName: "doc.badge.plus")
                                            .font(.system(size: 11))
                                            .foregroundStyle(.secondary)
                                        Text(appState.l("Each dictation will automatically create a new note in Apple Notes with title and timestamp."))
                                            .font(.system(size: 11))
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(.vertical, 2)
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                                }
                            }
                            .padding(.leading, 36)
                            .transition(.opacity.combined(with: .move(edge: .top)).combined(with: .scale(scale: 0.98, anchor: .top)))
                        }
                    }

                    Divider().opacity(0.2)

                    // Obsidian Row
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            HStack(spacing: 10) {
                                ObsidianAppIconView(size: 26)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Obsidian")
                                        .font(.system(size: 14, weight: .bold))
                                    Text(appState.l("Send transcripts directly to Obsidian"))
                                        .font(.system(size: 11))
                                        .foregroundStyle(Color.primary.opacity(0.70))
                                }
                            }
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { appState.enableObsidian },
                                set: { val in
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                        appState.enableObsidian = val
                                    }
                                }
                            ))
                            .toggleStyle(.switch)
                            .labelsHidden()
                        }
                        
                        if appState.enableObsidian {
                            VStack(alignment: .leading, spacing: 8) {
                                Button(appState.l("Select Vault Folder")) {
                                    let panel = NSOpenPanel()
                                    panel.canChooseFiles = false
                                    panel.canChooseDirectories = true
                                    panel.allowsMultipleSelection = false
                                    panel.message = appState.l("Select your Obsidian Vault folder")
                                    
                                    if panel.runModal() == .OK, let url = panel.url {
                                        appState.obsidianVaultURL = url.absoluteString
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                
                                Text(appState.obsidianVaultURL.isEmpty ? appState.l("No vault selected") : appState.obsidianVaultURL)
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color.primary.opacity(0.70))
                                    
                                HStack {
                                    Text(appState.l("Target Note:"))
                                        .font(.system(size: 12, weight: .medium))
                                    TextField(appState.l("e.g. Scribe Transcriptions"), text: $appState.obsidianTargetNote)
                                        .textFieldStyle(.roundedBorder)
                                }
                            }
                            .padding(.leading, 36)
                            .transition(.opacity.combined(with: .move(edge: .top)).combined(with: .scale(scale: 0.98, anchor: .top)))
                        }
                    }

                    Divider().opacity(0.2)

                    // Notion Row
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            HStack(spacing: 10) {
                                NotionAppIconView(size: 26)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Notion")
                                        .font(.system(size: 14, weight: .bold))
                                    Text(appState.l("Send transcripts directly to Notion"))
                                        .font(.system(size: 11))
                                        .foregroundStyle(Color.primary.opacity(0.70))
                                }
                            }
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { appState.enableNotion },
                                set: { val in
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                        appState.enableNotion = val
                                    }
                                }
                            ))
                            .toggleStyle(.switch)
                            .labelsHidden()
                        }
                        
                        if appState.enableNotion {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(appState.l("API Token:"))
                                        .font(.system(size: 12, weight: .medium))
                                    SecureField(appState.l("Secret Token"), text: $appState.notionIntegrationToken)
                                        .textFieldStyle(.roundedBorder)
                                }
                                HStack {
                                    Text(appState.l("Page ID:"))
                                        .font(.system(size: 12, weight: .medium))
                                    TextField(appState.l("Target Page ID"), text: $appState.notionPageId)
                                        .textFieldStyle(.roundedBorder)
                                }
                            }
                            .padding(.leading, 36)
                            .transition(.opacity.combined(with: .move(edge: .top)).combined(with: .scale(scale: 0.98, anchor: .top)))
                        }
                    }
                }
            }
        }
    }
}
// MARK: - Replacements Settings View
struct ReplacementsSettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var newPhrase: String = ""
    @State private var newReplacement: String = ""
    
    var body: some View {
        GlassSection(title: appState.l("Replacements"), icon: "text.badge.plus") {
            VStack(spacing: 16) {
                // Add new replacement at the TOP ("upper everything")
                HStack {
                    TextField(appState.l("Original phrase"), text: $newPhrase)
                        .textFieldStyle(.roundedBorder)
                    Image(systemName: "arrow.right")
                        .foregroundColor(.secondary)
                    TextField(appState.l("Replacement"), text: $newReplacement)
                        .textFieldStyle(.roundedBorder)
                    Button(action: {
                        if !newPhrase.isEmpty && !newReplacement.isEmpty {
                            appState.textReplacements.append(Replacement(id: UUID(), phrase: newPhrase, replacement: newReplacement))
                            newPhrase = ""
                            newReplacement = ""
                        }
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.blue)
                            .font(.system(size: 20))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 8)
                
                Divider()
                
                // Existing replacements below
                VStack(spacing: 12) {
                    ForEach(appState.textReplacements) { r in
                        HStack {
                            Text(r.phrase).font(.system(size: 13, weight: .bold)).frame(maxWidth: .infinity, alignment: .leading)
                            Image(systemName: "arrow.right").foregroundColor(.secondary)
                            Text(r.replacement).font(.system(size: 13)).frame(maxWidth: .infinity, alignment: .leading)
                            Spacer()
                            Button(action: {
                                appState.textReplacements.removeAll { $0.id == r.id }
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(14)
        }
    }
}

// MARK: - FlowLayout for Tag Chips
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 300
        var height: CGFloat = 0
        var x: CGFloat = 0
        var y: CGFloat = 0
        var maxHeightInRow: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width {
                x = 0
                y += maxHeightInRow + spacing
                maxHeightInRow = 0
            }
            maxHeightInRow = max(maxHeightInRow, size.height)
            x += size.width + spacing
        }
        height = y + maxHeightInRow
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var maxHeightInRow: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX {
                x = bounds.minX
                y += maxHeightInRow + spacing
                maxHeightInRow = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            maxHeightInRow = max(maxHeightInRow, size.height)
            x += size.width + spacing
        }
    }
}

// MARK: - Create Preset Modal View
struct CreatePresetModalView: View {
    var category: String = "vocabulary"
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState

    @State private var presetName: String = ""
    @State private var presetDescription: String = ""
    @State private var wordInput: String = ""
    @State private var words: [String] = []
    @State private var shareCode: String = ""
    @State private var copiedCode: Bool = false

    private var isBlocked: Bool { category == "blocked" }

    private func isValidItem(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return false }
        return trimmed.rangeOfCharacter(from: .alphanumerics) != nil
    }

    private func addWord() {
        let trimmed = wordInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let items = trimmed.components(separatedBy: CharacterSet(charactersIn: ",\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { isValidItem($0) }
        for w in items {
            if !words.contains(where: { $0.caseInsensitiveCompare(w) == .orderedSame }) {
                words.append(w)
            }
        }
        wordInput = ""
    }

    private func savePreset() {
        let trimmedName = presetName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !words.isEmpty else { return }
        let preset = VocabularyPreset(
            name: trimmedName,
            description: presetDescription.trimmingCharacters(in: .whitespacesAndNewlines),
            words: words,
            shareCode: shareCode.isEmpty ? VocabularyPreset.generateShareCode(category: category) : shareCode,
            category: category
        )
        if isBlocked {
            appState.customBlockedWordsPresets.append(preset)
            var current = appState.blockedWords
                .components(separatedBy: CharacterSet(charactersIn: ",\n"))
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            for w in words {
                if !current.contains(where: { $0.caseInsensitiveCompare(w) == .orderedSame }) {
                    current.append(w)
                }
            }
            appState.blockedWords = current.joined(separator: ", ")
        } else {
            appState.customVocabularyPresets.append(preset)
            var current = appState.vocabulary
                .components(separatedBy: CharacterSet(charactersIn: ",\n"))
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            for w in words {
                if !current.contains(where: { $0.caseInsensitiveCompare(w) == .orderedSame }) {
                    current.append(w)
                }
            }
            appState.vocabulary = current.joined(separator: ", ")
        }
        dismiss()
    }

    private var canSave: Bool {
        !presetName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !words.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: isBlocked ? "nosign" : "plus.square.fill.on.square.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(isBlocked ? Color.red : Color.primary)
                    Text(isBlocked ? appState.l("Create Blocked Words Preset") : appState.l("Create Vocabulary Preset"))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                }
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(20)

            Divider().opacity(0.3)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Preset Name
                    VStack(alignment: .leading, spacing: 6) {
                        Text(appState.l("Preset Name"))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                        TextField(isBlocked ? appState.l("e.g. Profanity Filter, Competitor Names, Sensitive Terms...") : appState.l("e.g. Gaming Slang, Medical Terms, Tech Stack..."), text: $presetName)
                            .textFieldStyle(.plain)
                            .padding(10)
                            .background(Color.primary.opacity(0.04))
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.primary.opacity(0.1), lineWidth: 1))
                    }

                    // Description (optional)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(appState.l("Description (Optional)"))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                        TextField(appState.l("Short description for your preset..."), text: $presetDescription)
                            .textFieldStyle(.plain)
                            .padding(10)
                            .background(Color.primary.opacity(0.04))
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.primary.opacity(0.1), lineWidth: 1))
                    }

                    // Words Input
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(isBlocked ? appState.l("Blocked Words & Phrases") : appState.l("Words & Acronyms"))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(appState.l("Min 2 characters"))
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                        }

                        HStack(spacing: 8) {
                            TextField(isBlocked ? appState.l("Add blocked word or comma-separated list...") : appState.l("Add word or comma-separated list..."), text: $wordInput, onCommit: addWord)
                                .textFieldStyle(.plain)
                                .padding(10)
                                .background(Color.primary.opacity(0.04))
                                .cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.primary.opacity(0.1), lineWidth: 1))

                            Button(action: addWord) {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus")
                                    Text(appState.l("Add"))
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(isValidItem(wordInput) ? (isBlocked ? Color.red.opacity(0.18) : Color.primary.opacity(0.12)) : Color.primary.opacity(0.05))
                                .foregroundStyle(isValidItem(wordInput) ? (isBlocked ? Color.red : Color.primary) : Color.secondary)
                                .cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(isValidItem(wordInput) ? (isBlocked ? Color.red.opacity(0.3) : Color.primary.opacity(0.15)) : Color.clear, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                            .disabled(!isValidItem(wordInput))
                        }

                        if !words.isEmpty {
                            ScrollView(.vertical, showsIndicators: true) {
                                FlowLayout(spacing: 6) {
                                    ForEach(words, id: \.self) { word in
                                        HStack(spacing: 4) {
                                            Text(word)
                                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                            Button(action: { words.removeAll { $0 == word } }) {
                                                Image(systemName: "xmark.circle.fill")
                                                    .font(.system(size: 10))
                                                    .foregroundStyle(isBlocked ? Color.red.opacity(0.7) : .secondary)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(isBlocked ? Color.red.opacity(0.08) : Color.primary.opacity(0.06))
                                        .cornerRadius(8)
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                            .frame(maxHeight: 130)
                            .padding(.top, 4)
                        }
                    }

                    // Share Code Preview
                    VStack(alignment: .leading, spacing: 6) {
                        Text(appState.l("Generated Share Code"))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)

                        HStack {
                            Text(shareCode.isEmpty ? VocabularyPreset.generateShareCode(category: category) : shareCode)
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                .foregroundStyle(isBlocked ? Color.red : Color.primary)

                            Spacer()

                            Button(action: {
                                NSPasteboard.general.clearContents()
                                let finalCode = shareCode.isEmpty ? VocabularyPreset.generateShareCode(category: category) : shareCode
                                let preset = VocabularyPreset(name: presetName.isEmpty ? "Preset" : presetName, words: words, shareCode: finalCode, category: category)
                                NSPasteboard.general.setString(preset.toExportCode(), forType: .string)
                                copiedCode = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copiedCode = false }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: copiedCode ? "checkmark" : "doc.on.doc")
                                    Text(copiedCode ? appState.l("Copied!") : appState.l("Copy Code"))
                                }
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(copiedCode ? .green : .secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(10)
                        .background(Color.primary.opacity(0.03))
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.primary.opacity(0.08), lineWidth: 1))
                    }
                }
                .padding(20)
            }

            Divider().opacity(0.3)

            // Footer Actions
            HStack(spacing: 12) {
                Button(action: { dismiss() }) {
                    Text(appState.l("Cancel"))
                        .font(.system(size: 13, weight: .medium))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.plain)

                Spacer()

                Button(action: savePreset) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark")
                        Text(appState.l("Save Preset"))
                    }
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(
                        canSave 
                            ? (isBlocked ? Color.red : appState.selectedTheme.gradientColors.first!) 
                            : Color.primary.opacity(0.1)
                    )
                    .foregroundStyle(
                        canSave 
                            ? Color.white 
                            : Color.secondary.opacity(0.7)
                    )
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(!canSave)
            }
            .padding(16)
        }
        .frame(width: 460, height: 480)
        .background(.ultraThinMaterial)
        .onAppear {
            if shareCode.isEmpty {
                shareCode = VocabularyPreset.generateShareCode(category: category)
            }
        }
    }
}

// MARK: - Import Preset Modal View
struct ImportPresetModalView: View {
    var category: String = "vocabulary"
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState

    @State private var codeInput: String = ""
    @State private var parsedPreset: VocabularyPreset? = nil
    @State private var parseError: String? = nil
    @State private var applyDirectlyToActive: Bool = true

    private var isBlockedContext: Bool { category == "blocked" }

    private func parseCode() {
        let trimmed = codeInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            parsedPreset = nil
            parseError = nil
            return
        }

        if let preset = VocabularyPreset.fromExportCode(trimmed) {
            parsedPreset = preset
            parseError = nil
        } else if let existing = appState.customVocabularyPresets.first(where: { $0.shareCode == trimmed }) {
            parsedPreset = existing
            parseError = nil
        } else if let existing = appState.customBlockedWordsPresets.first(where: { $0.shareCode == trimmed }) {
            parsedPreset = existing
            parseError = nil
        } else {
            parsedPreset = nil
            parseError = "Invalid or unrecognized share code (must start with scr_)"
        }
    }

    private func importPreset() {
        guard let preset = parsedPreset else { return }
        let presetCategory = preset.category
        
        if presetCategory == "blocked" {
            if !appState.customBlockedWordsPresets.contains(where: { $0.shareCode == preset.shareCode || $0.name == preset.name }) {
                appState.customBlockedWordsPresets.append(preset)
            }
            if applyDirectlyToActive {
                var current = appState.blockedWords
                    .components(separatedBy: CharacterSet(charactersIn: ",\n"))
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                for w in preset.words {
                    if !current.contains(where: { $0.caseInsensitiveCompare(w) == .orderedSame }) {
                        current.append(w)
                    }
                }
                appState.blockedWords = current.joined(separator: ", ")
            }
        } else {
            if !appState.customVocabularyPresets.contains(where: { $0.shareCode == preset.shareCode || $0.name == preset.name }) {
                appState.customVocabularyPresets.append(preset)
            }
            if applyDirectlyToActive {
                var current = appState.vocabulary
                    .components(separatedBy: CharacterSet(charactersIn: ",\n"))
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                for w in preset.words {
                    if !current.contains(w) {
                        current.append(w)
                    }
                }
                appState.vocabulary = current.joined(separator: ", ")
            }
        }
        dismiss()
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: isBlockedContext ? "nosign" : "square.and.arrow.down.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(isBlockedContext ? Color.red : Color.primary)
                    Text(isBlockedContext ? appState.l("Import Blocked Preset") : appState.l("Import Vocabulary Preset"))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                }
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(18)

            Divider().opacity(0.3)

            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 16) {
                    // Code Input
                    VStack(alignment: .leading, spacing: 6) {
                        Text(appState.l("Share Code (scr_...)"))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)

                        HStack(spacing: 8) {
                            TextField(appState.l("Paste scr_ code here..."), text: $codeInput)
                                .textFieldStyle(.plain)
                                .padding(10)
                                .background(Color.primary.opacity(0.04))
                                .cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.primary.opacity(0.1), lineWidth: 1))
                                .onChange(of: codeInput) { _ in parseCode() }

                            Button(action: {
                                if let clip = NSPasteboard.general.string(forType: .string) {
                                    codeInput = clip
                                    parseCode()
                                }
                            }) {
                                HStack(spacing: 5) {
                                    Image(systemName: "doc.on.clipboard")
                                    Text(appState.l("Paste"))
                                }
                                .font(.system(size: 12, weight: .semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.primary.opacity(0.08))
                                .foregroundStyle(Color.primary)
                                .cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.primary.opacity(0.12), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }

                        if let err = parseError {
                            Text(err)
                                .font(.system(size: 11))
                                .foregroundStyle(.red)
                        }
                    }

                    // Preset Preview
                    if let preset = parsedPreset {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text(preset.name)
                                            .font(.system(size: 14, weight: .bold, design: .rounded))
                                        Text(preset.category == "blocked" ? appState.l("Blocked Words") : appState.l("Custom Vocabulary"))
                                            .font(.system(size: 9, weight: .bold))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(preset.category == "blocked" ? Color.red.opacity(0.15) : Color.blue.opacity(0.15))
                                            .foregroundStyle(preset.category == "blocked" ? Color.red : Color.blue)
                                            .cornerRadius(4)
                                    }
                                    if !preset.description.isEmpty {
                                        Text(preset.description)
                                            .font(.system(size: 11))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Text("\(preset.words.count) " + appState.l("words"))
                                    .font(.system(size: 10, weight: .bold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.green.opacity(0.15))
                                    .foregroundStyle(.green)
                                    .cornerRadius(6)
                            }

                            ScrollView(.vertical, showsIndicators: true) {
                                FlowLayout(spacing: 5) {
                                    ForEach(preset.words, id: \.self) { word in
                                        Text(word)
                                            .font(.system(size: 11, weight: .medium, design: .rounded))
                                            .padding(.horizontal, 7)
                                            .padding(.vertical, 3)
                                            .background(preset.category == "blocked" ? Color.red.opacity(0.08) : Color.primary.opacity(0.06))
                                            .cornerRadius(6)
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                            .frame(maxHeight: 160)

                            Divider().opacity(0.2)

                            Toggle(isBlockedContext ? appState.l("Also add to active blocked words") : appState.l("Also add words directly into active vocabulary"), isOn: $applyDirectlyToActive)
                                .font(.system(size: 12))
                        }
                        .padding(12)
                        .background(Color.primary.opacity(0.03))
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.green.opacity(0.3), lineWidth: 1))
                    }
                }
                .padding(18)
            }

            Divider().opacity(0.3)

            // Footer
            HStack(spacing: 12) {
                Button(action: { dismiss() }) {
                    Text(appState.l("Cancel"))
                        .font(.system(size: 13, weight: .medium))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.plain)

                Spacer()

                Button(action: importPreset) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.circle.fill")
                        Text(appState.l("Import Preset"))
                    }
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(
                        parsedPreset != nil 
                            ? (isBlockedContext ? Color.red : appState.selectedTheme.gradientColors.first!) 
                            : Color.primary.opacity(0.08)
                    )
                    .foregroundStyle(
                        parsedPreset != nil 
                            ? Color.white 
                            : Color.secondary.opacity(0.6)
                    )
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(parsedPreset == nil)
            }
            .padding(16)
        }
        .frame(width: 480, height: parsedPreset == nil ? 210 : 440)
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: parsedPreset != nil)
        .background(.ultraThinMaterial)
    }
}

// MARK: - Vocabulary Contribution Prompt Modal View
struct VocabularyContributionPromptModalView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            // Header Image / Icon
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.primary.opacity(0.08))
                        .frame(width: 58, height: 58)
                    
                    Image(systemName: "sparkles.rectangle.stack.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.primary)
                }
                .padding(.top, 22)

                Text(appState.l("Improve Scribe Vocabulary"))
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                Text(appState.l("Can Scribe anonymously use your added custom words and presets to train better recognition models and expand the built-in vocabulary for everyone?"))
                    .font(.system(size: 12))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
            }

            // Privacy Assurance Card
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.green)
                    Text(appState.l("100% Anonymous & Secure"))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.green)
                }

                Text(appState.l("No voice audio, full transcripts, notes, or personal identifiers are ever collected. Only isolated vocabulary terms and acronyms."))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .background(Color.green.opacity(0.08))
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.green.opacity(0.2), lineWidth: 1))
            .padding(.horizontal, 20)
            .padding(.top, 14)

            Spacer()

            Divider().opacity(0.3)

            // Actions
            HStack(spacing: 12) {
                Button(action: {
                    appState.allowAnonymousVocabularyContribution = false
                    appState.hasPromptedVocabularyDataSharing = true
                    dismiss()
                }) {
                    Text(appState.l("No, Thanks"))
                        .font(.system(size: 13, weight: .medium))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.primary.opacity(0.04))
                        .foregroundStyle(.secondary)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)

                Spacer()

                Button(action: {
                    appState.allowAnonymousVocabularyContribution = true
                    appState.hasPromptedVocabularyDataSharing = true
                    dismiss()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                        Text(appState.l("Allow & Improve"))
                    }
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .background(Color.primary.opacity(0.14))
                    .foregroundStyle(.primary)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.primary.opacity(0.18), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(16)
        }
        .frame(width: 440, height: 350)
        .background(.ultraThinMaterial)
    }
}

// MARK: - Share Active Words Modal View (with Word Selection)
struct ShareActiveWordsModalView: View {
    var category: String = "vocabulary"
    var allWords: [String] = []

    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState

    @State private var presetName: String = ""
    @State private var presetDescription: String = ""
    @State private var selectedWords: Set<String> = []
    @State private var searchText: String = ""
    @State private var copiedCode: Bool = false

    private var isBlocked: Bool { category == "blocked" }

    private var filteredWords: [String] {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return allWords
        }
        return allWords.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    private var selectedWordsList: [String] {
        allWords.filter { selectedWords.contains($0) }
    }

    private func toggleWord(_ word: String) {
        if selectedWords.contains(word) {
            selectedWords.remove(word)
        } else {
            selectedWords.insert(word)
        }
    }

    private func selectAll() {
        selectedWords = Set(allWords)
    }

    private func deselectAll() {
        selectedWords.removeAll()
    }

    private func copyShareCode() {
        guard !selectedWordsList.isEmpty else { return }
        let trimmedName = presetName.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = trimmedName.isEmpty ? (isBlocked ? "Active Blocked Words" : "Active Vocabulary") : trimmedName
        let trimmedDesc = presetDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalDesc = trimmedDesc.isEmpty ? "Exported from Scribe" : trimmedDesc

        let preset = VocabularyPreset(
            name: finalName,
            description: finalDesc,
            words: selectedWordsList,
            shareCode: VocabularyPreset.generateShareCode(category: category),
            category: category
        )

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(preset.toExportCode(), forType: .string)
        copiedCode = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            copiedCode = false
            dismiss()
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: isBlocked ? "nosign" : "square.and.arrow.up.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(isBlocked ? Color.red : Color.primary)
                    Text(isBlocked ? appState.l("Share Active Blocked Words") : appState.l("Share Active Words"))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                }
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(18)

            Divider().opacity(0.3)

            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 16) {
                    // Preset details
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(appState.l("Preset Name"))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.secondary)
                            TextField(isBlocked ? "Active Blocked Words" : "Active Vocabulary", text: $presetName)
                                .textFieldStyle(.plain)
                                .padding(10)
                                .background(Color.primary.opacity(0.04))
                                .cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.primary.opacity(0.1), lineWidth: 1))
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text(appState.l("Description (Optional)"))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.secondary)
                            TextField(appState.l("Short description for your preset..."), text: $presetDescription)
                                .textFieldStyle(.plain)
                                .padding(10)
                                .background(Color.primary.opacity(0.04))
                                .cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.primary.opacity(0.1), lineWidth: 1))
                        }
                    }

                    // Word Selector Section
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(appState.l("Select Words to Share"))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.secondary)

                            Spacer()

                            Text("\(selectedWords.count) / \(allWords.count) " + appState.l("selected"))
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(selectedWords.isEmpty ? Color.secondary : (isBlocked ? Color.red : Color.primary))

                            HStack(spacing: 8) {
                                Button(action: selectAll) {
                                    Text(appState.l("Select All"))
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(.primary.opacity(0.8))
                                }
                                .buttonStyle(.plain)

                                Text("•")
                                    .foregroundStyle(.tertiary)

                                Button(action: deselectAll) {
                                    Text(appState.l("Deselect All"))
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.leading, 6)
                        }

                        if allWords.count > 12 {
                            HStack(spacing: 6) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                TextField(appState.l("Filter words..."), text: $searchText)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 12))
                                if !searchText.isEmpty {
                                    Button(action: { searchText = "" }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 11))
                                            .foregroundStyle(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(Color.primary.opacity(0.03))
                            .cornerRadius(6)
                            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.primary.opacity(0.08), lineWidth: 1))
                        }

                        // Word Chips (Toggleable)
                        ScrollView(.vertical, showsIndicators: true) {
                            if filteredWords.isEmpty {
                                Text(appState.l("No words match your search."))
                                    .font(.system(size: 12))
                                    .foregroundStyle(.tertiary)
                                    .padding(.vertical, 20)
                                    .frame(maxWidth: .infinity, alignment: .center)
                            } else {
                                FlowLayout(spacing: 6) {
                                    ForEach(filteredWords, id: \.self) { word in
                                        let isSelected = selectedWords.contains(word)
                                        Button(action: { toggleWord(word) }) {
                                            HStack(spacing: 5) {
                                                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                                    .font(.system(size: 10, weight: .semibold))
                                                    .foregroundStyle(
                                                        isSelected 
                                                            ? (isBlocked ? Color.red : Color.primary) 
                                                            : Color.secondary.opacity(0.6)
                                                    )
                                                Text(word)
                                                    .font(.system(size: 12, weight: isSelected ? .semibold : .medium, design: .rounded))
                                                    .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                                            }
                                            .padding(.horizontal, 9)
                                            .padding(.vertical, 5)
                                            .background(
                                                isSelected 
                                                    ? (isBlocked ? Color.red.opacity(0.12) : Color.primary.opacity(0.12))
                                                    : Color.primary.opacity(0.04)
                                            )
                                            .cornerRadius(8)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .strokeBorder(
                                                        isSelected 
                                                            ? (isBlocked ? Color.red.opacity(0.3) : Color.primary.opacity(0.2))
                                                            : Color.primary.opacity(0.06),
                                                        lineWidth: 1
                                                    )
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .frame(maxHeight: 170)
                        .padding(10)
                        .background(Color.primary.opacity(0.02))
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.primary.opacity(0.06), lineWidth: 1))
                    }
                }
                .padding(18)
            }

            Divider().opacity(0.3)

            // Footer
            HStack(spacing: 12) {
                Button(action: { dismiss() }) {
                    Text(appState.l("Cancel"))
                        .font(.system(size: 13, weight: .medium))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.plain)

                Spacer()

                Button(action: copyShareCode) {
                    HStack(spacing: 6) {
                        Image(systemName: copiedCode ? "checkmark" : "doc.on.doc")
                        Text(copiedCode ? appState.l("Copied!") : appState.l("Copy Share Code"))
                    }
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(
                        !selectedWords.isEmpty 
                            ? (isBlocked ? Color.red : appState.selectedTheme.gradientColors.first!) 
                            : Color.primary.opacity(0.1)
                    )
                    .foregroundStyle(
                        !selectedWords.isEmpty 
                            ? Color.white 
                            : Color.secondary.opacity(0.7)
                    )
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(selectedWords.isEmpty)
            }
            .padding(16)
        }
        .frame(width: 500, height: 500)
        .background(.ultraThinMaterial)
        .onAppear {
            selectedWords = Set(allWords)
            if presetName.isEmpty {
                presetName = isBlocked ? "Active Blocked Words" : "Active Vocabulary"
            }
        }
    }
}

// MARK: - Vocabulary Settings View
enum VocabularyTab: String, CaseIterable, Identifiable {
    case vocabulary = "vocabulary"
    case blockedWords = "blocked_words"
    
    var id: String { rawValue }
}

struct VocabularySettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab: VocabularyTab = .vocabulary
    @State private var newWord: String = ""
    @State private var newBlockedWord: String = ""
    @State private var showingCreatePresetModal: Bool = false
    @State private var showingImportPresetModal: Bool = false
    @State private var showingShareActiveModal: Bool = false
    @State private var showingContributionPromptModal: Bool = false
    @State private var copiedPresetId: UUID? = nil
    @State private var appliedPresetId: UUID? = nil
    @State private var copiedActiveVocabularyFeedback: Bool = false
    @State private var copiedActiveBlockedWordsFeedback: Bool = false
    @State private var presetToDelete: VocabularyPreset? = nil
    @State private var addedHallucinationsFeedback: Bool = false

    private var wordsList: [String] {
        appState.vocabulary
            .components(separatedBy: CharacterSet(charactersIn: ",\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private var blockedWordsList: [String] {
        appState.blockedWords
            .components(separatedBy: CharacterSet(charactersIn: ",\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func isValidItem(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return false }
        return trimmed.rangeOfCharacter(from: .alphanumerics) != nil
    }

    private func addWord() {
        let trimmed = newWord.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isValidItem(trimmed) else { return }
        let items = trimmed.components(separatedBy: CharacterSet(charactersIn: ",\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { isValidItem($0) }
        var current = wordsList
        for w in items {
            if !current.contains(w) {
                current.append(w)
            }
        }
        appState.vocabulary = current.joined(separator: ", ")
        newWord = ""
    }

    private func removeWord(_ word: String) {
        var current = wordsList
        current.removeAll { $0 == word }
        appState.vocabulary = current.joined(separator: ", ")
    }

    private func addBlockedWord() {
        let trimmed = newBlockedWord.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isValidItem(trimmed) else { return }
        let items = trimmed.components(separatedBy: CharacterSet(charactersIn: ",\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { isValidItem($0) }
        var current = blockedWordsList
        for w in items {
            if !current.contains(where: { $0.caseInsensitiveCompare(w) == .orderedSame }) {
                current.append(w)
            }
        }
        appState.blockedWords = current.joined(separator: ", ")
        newBlockedWord = ""
    }

    private func removeBlockedWord(_ word: String) {
        var current = blockedWordsList
        current.removeAll { $0 == word }
        appState.blockedWords = current.joined(separator: ", ")
    }

    private func clearAllBlockedWords() {
        appState.blockedWords = ""
    }

    private func shareActiveVocabulary() {
        guard !wordsList.isEmpty else { return }
        showingShareActiveModal = true
    }

    private func shareActiveBlockedWords() {
        guard !blockedWordsList.isEmpty else { return }
        showingShareActiveModal = true
    }

    private func applyPreset(_ preset: VocabularyPreset) {
        var current = wordsList
        for w in preset.words {
            if !current.contains(w) {
                current.append(w)
            }
        }
        appState.vocabulary = current.joined(separator: ", ")
        appliedPresetId = preset.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            if appliedPresetId == preset.id { appliedPresetId = nil }
        }
    }

    private func sharePreset(_ preset: VocabularyPreset) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(preset.toExportCode(), forType: .string)
        copiedPresetId = preset.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            if copiedPresetId == preset.id { copiedPresetId = nil }
        }
    }

    private func deletePreset(_ preset: VocabularyPreset, removeWordsFromActive: Bool) {
        appState.customVocabularyPresets.removeAll { $0.id == preset.id }
        if removeWordsFromActive {
            var current = wordsList
            let presetWordsLower = Set(preset.words.map { $0.lowercased() })
            current.removeAll { presetWordsLower.contains($0.lowercased()) }
            appState.vocabulary = current.joined(separator: ", ")
        }
        presetToDelete = nil
    }

    private func applyBlockedPreset(_ preset: VocabularyPreset) {
        var current = blockedWordsList
        for w in preset.words {
            if !current.contains(where: { $0.caseInsensitiveCompare(w) == .orderedSame }) {
                current.append(w)
            }
        }
        appState.blockedWords = current.joined(separator: ", ")
        appliedPresetId = preset.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            if appliedPresetId == preset.id { appliedPresetId = nil }
        }
    }

    private func shareBlockedPreset(_ preset: VocabularyPreset) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(preset.toExportCode(), forType: .string)
        copiedPresetId = preset.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            if copiedPresetId == preset.id { copiedPresetId = nil }
        }
    }

    private func deleteBlockedPreset(_ preset: VocabularyPreset, removeWordsFromActive: Bool) {
        appState.customBlockedWordsPresets.removeAll { $0.id == preset.id }
        if removeWordsFromActive {
            var current = blockedWordsList
            let presetWordsLower = Set(preset.words.map { $0.lowercased() })
            current.removeAll { presetWordsLower.contains($0.lowercased()) }
            appState.blockedWords = current.joined(separator: ", ")
        }
        presetToDelete = nil
    }

    var body: some View {
        VStack(spacing: 16) {
            // SECTION 1: Header with Integrated Mode Switcher & Active Words Card
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: selectedTab == .vocabulary ? "text.book.closed.fill" : "nosign")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.primary)
                        Text((selectedTab == .vocabulary ? appState.l("Active Custom Vocabulary") : appState.l("Active Blocked Words")).uppercased())
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.primary.opacity(0.72))
                    }
                    .padding(.horizontal, 4)

                    Spacer()

                    LiquidGlassSegmentedPicker(
                        items: VocabularyTab.allCases,
                        selection: $selectedTab,
                        label: { tab in
                            switch tab {
                            case .vocabulary:
                                return (appState.l("Custom Vocabulary"), "text.book.closed.fill")
                            case .blockedWords:
                                return (appState.l("Blocked Words"), "nosign")
                            }
                        }
                    )
                }

                // Card Body
                VStack(alignment: .leading, spacing: 12) {
                    if selectedTab == .vocabulary {
                        // Custom Vocabulary Controls
                        Text(appState.l("All words below will be prioritized and automatically capitalized by Whisper."))
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)

                        HStack(spacing: 8) {
                            TextField(appState.l("Enter word or acronym..."), text: $newWord, onCommit: addWord)
                                .textFieldStyle(.plain)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(Color.primary.opacity(0.04))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                                )

                            Button(action: addWord) {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 12, weight: .bold))
                                    Text(appState.l("Add"))
                                        .font(.system(size: 12, weight: .semibold))
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(isValidItem(newWord) ? Color.primary.opacity(0.12) : Color.primary.opacity(0.05))
                                .foregroundStyle(isValidItem(newWord) ? Color.primary : Color.secondary)
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .strokeBorder(isValidItem(newWord) ? Color.primary.opacity(0.15) : Color.clear, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                            .disabled(!isValidItem(newWord))
                        }

                        if wordsList.isEmpty {
                            Text(appState.l("No custom words added yet."))
                                .font(.system(size: 12))
                                .foregroundStyle(.tertiary)
                                .padding(.vertical, 2)
                        } else {
                            ScrollView(.vertical, showsIndicators: true) {
                                FlowLayout(spacing: 6) {
                                    ForEach(wordsList, id: \.self) { word in
                                        HStack(spacing: 6) {
                                            Text(word)
                                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                                .foregroundStyle(.primary)

                                            Button(action: { removeWord(word) }) {
                                                Image(systemName: "xmark.circle.fill")
                                                    .font(.system(size: 11))
                                                    .foregroundStyle(.secondary)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(Color.primary.opacity(0.06))
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
                                        )
                                    }
                                }
                                .padding(.vertical, 4)
                                .padding(.trailing, 4)
                            }
                            .frame(maxHeight: 180)

                            HStack {
                                Button(action: shareActiveVocabulary) {
                                    HStack(spacing: 4) {
                                        Image(systemName: copiedActiveVocabularyFeedback ? "checkmark" : "square.and.arrow.up")
                                        Text(copiedActiveVocabularyFeedback ? appState.l("Copied!") : appState.l("Share Active Words"))
                                    }
                                    .font(.system(size: 11, weight: .semibold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(copiedActiveVocabularyFeedback ? Color.green.opacity(0.15) : Color.primary.opacity(0.06))
                                    .foregroundStyle(copiedActiveVocabularyFeedback ? .green : .secondary)
                                    .cornerRadius(6)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)

                                Spacer()
                            }
                            .padding(.top, 2)
                        }
                    } else {
                        // Blocked Words Controls
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.green)
                            Text(appState.l("Scribe automatically filters common Whisper hallucination artifacts (subtitles, credits). Add your custom blocked words and sensitive terms below."))
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        .padding(9)
                        .background(Color.primary.opacity(0.03))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
                        )

                        // Action selector (Remove or Mask)
                        HStack {
                            Text(appState.l("Action for blocked words:"))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.primary)

                            Spacer()

                            LiquidGlassSegmentedPicker(
                                items: ["remove", "mask"],
                                selection: $appState.blockedWordsActionRaw,
                                label: { action in
                                    if action == "remove" {
                                        return (appState.l("Remove from text"), "xmark.circle")
                                    } else {
                                        return (appState.l("Mask with ***"), "eye.slash")
                                    }
                                }
                            )
                        }

                        // Input field
                        HStack(spacing: 8) {
                            TextField(appState.l("Enter blocked word or phrase..."), text: $newBlockedWord, onCommit: addBlockedWord)
                                .textFieldStyle(.plain)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(Color.primary.opacity(0.04))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                                )

                            Button(action: addBlockedWord) {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 12, weight: .bold))
                                    Text(appState.l("Add"))
                                        .font(.system(size: 12, weight: .semibold))
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(isValidItem(newBlockedWord) ? Color.red.opacity(0.15) : Color.primary.opacity(0.05))
                                .foregroundStyle(isValidItem(newBlockedWord) ? Color.red : Color.secondary)
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .strokeBorder(isValidItem(newBlockedWord) ? Color.red.opacity(0.3) : Color.clear, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                            .disabled(!isValidItem(newBlockedWord))
                        }

                        // Clear All & Blocked words list
                        if blockedWordsList.isEmpty {
                            Text(appState.l("No blocked words added yet."))
                                .font(.system(size: 12))
                                .foregroundStyle(.tertiary)
                                .padding(.vertical, 2)
                        } else {
                            ScrollView(.vertical, showsIndicators: true) {
                                FlowLayout(spacing: 6) {
                                    ForEach(blockedWordsList, id: \.self) { word in
                                        HStack(spacing: 6) {
                                            Text(word)
                                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                                .foregroundStyle(.primary)

                                            Button(action: { removeBlockedWord(word) }) {
                                                Image(systemName: "xmark.circle.fill")
                                                    .font(.system(size: 11))
                                                    .foregroundStyle(.red.opacity(0.7))
                                            }
                                            .buttonStyle(.plain)
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(Color.red.opacity(0.08))
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .strokeBorder(Color.red.opacity(0.2), lineWidth: 1)
                                        )
                                    }
                                }
                                .padding(.vertical, 4)
                                .padding(.trailing, 4)
                            }
                            .frame(maxHeight: 180)

                            HStack {
                                Button(action: shareActiveBlockedWords) {
                                    HStack(spacing: 4) {
                                        Image(systemName: copiedActiveBlockedWordsFeedback ? "checkmark" : "square.and.arrow.up")
                                        Text(copiedActiveBlockedWordsFeedback ? appState.l("Copied!") : appState.l("Share Active Blocked Words"))
                                    }
                                    .font(.system(size: 11, weight: .semibold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(copiedActiveBlockedWordsFeedback ? Color.green.opacity(0.15) : Color.primary.opacity(0.06))
                                    .foregroundStyle(copiedActiveBlockedWordsFeedback ? .green : .secondary)
                                    .cornerRadius(6)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)

                                Spacer()

                                Button(action: clearAllBlockedWords) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "trash")
                                        Text(appState.l("Clear All"))
                                    }
                                    .font(.system(size: 11, weight: .medium))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.top, 2)
                        }
                    }
                }
                .padding(14)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial.opacity(0.6))
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.primary.opacity(0.06))
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
                )
            }

            if selectedTab == .vocabulary {
                // SECTION: Cities & Street Locations
                GlassSection(title: appState.l("Cities & Locations"), icon: "mappin.and.ellipse") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(appState.l("Specify your city, frequent neighborhoods or street names (comma-separated). Scribe will bias the transcription model to accurately recognize local addresses, street prefixes, and locations."))
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .lineSpacing(2)

                        HStack(spacing: 8) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                            TextField(appState.l("e.g. Москва, Тверская, Арбат or Dubai, Marina..."), text: $appState.userCityLocation)
                                .textFieldStyle(.plain)
                                .font(.system(size: 12, design: .rounded))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Color.primary.opacity(0.04))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                        )

                        // Quick City Tags
                        VStack(alignment: .leading, spacing: 6) {
                            Text(appState.l("Quick presets:"))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)

                            FlowLayout(spacing: 6) {
                                ForEach(["Москва", "Санкт-Петербург", "Дубай", "Алматы", "Тбилиси", "Ереван", "Киев", "Минск", "Ташкент", "Баку", "London", "New York"], id: \.self) { city in
                                    Button(action: {
                                        var current = appState.userCityLocation.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                                        if current.contains(city) {
                                            current.removeAll { $0 == city }
                                        } else {
                                            current.append(city)
                                        }
                                        appState.userCityLocation = current.joined(separator: ", ")
                                    }) {
                                        let isSelected = appState.userCityLocation.contains(city)
                                        HStack(spacing: 4) {
                                            if isSelected {
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 9, weight: .bold))
                                            }
                                            Text(city)
                                                .font(.system(size: 11, weight: isSelected ? .semibold : .regular, design: .rounded))
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(isSelected ? Color.accentColor.opacity(0.2) : Color.primary.opacity(0.05))
                                        .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
                                        .cornerRadius(10)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .strokeBorder(isSelected ? Color.accentColor.opacity(0.4) : Color.primary.opacity(0.08), lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        Divider()
                            .padding(.vertical, 4)

                        Toggle(isOn: $appState.smartCasingEnabled) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(appState.l("Smart Lowercase in Mid-Sentence"))
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                Text(appState.l("Automatically lowers the first character when inserting into an already active sentence."))
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                    }
                    .padding(14)
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.ultraThinMaterial.opacity(0.6))
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.primary.opacity(0.06))
                        }
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
                    )
                }

                // SECTION 2: Custom Presets & Community Share (Vocabulary)
                GlassSection(title: appState.l("Vocabulary Presets"), icon: "square.grid.2x2.fill") {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .center, spacing: 12) {
                            Text(appState.l("Create custom word packs and share them instantly."))
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            HStack(spacing: 8) {
                                Button(action: { showingCreatePresetModal = true }) {
                                    HStack(spacing: 5) {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.system(size: 11, weight: .bold))
                                        Text(appState.l("Create Preset"))
                                            .font(.system(size: 11, weight: .bold, design: .rounded))
                                            .lineLimit(1)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 7)
                                    .background(Color.primary.opacity(0.06))
                                    .foregroundStyle(.primary)
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                                .fixedSize()

                                Button(action: { showingImportPresetModal = true }) {
                                    HStack(spacing: 5) {
                                        Image(systemName: "square.and.arrow.down.fill")
                                            .font(.system(size: 11, weight: .bold))
                                        Text(appState.l("Import Preset"))
                                            .font(.system(size: 11, weight: .bold, design: .rounded))
                                            .lineLimit(1)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 7)
                                    .background(Color.primary.opacity(0.06))
                                    .foregroundStyle(.primary)
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
                                        )
                                }
                                .buttonStyle(.plain)
                                .fixedSize()
                            }
                        }

                        if appState.customVocabularyPresets.isEmpty {
                            HStack(spacing: 8) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary)
                                Text(appState.l("No custom presets yet. Create one or import a share code to get started."))
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.primary.opacity(0.025))
                            .cornerRadius(8)
                        } else {
                            VStack(spacing: 8) {
                                ForEach(appState.customVocabularyPresets) { preset in
                                    HStack(spacing: 12) {
                                        VStack(alignment: .leading, spacing: 3) {
                                            HStack(spacing: 6) {
                                                Text(preset.name)
                                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                                    .foregroundStyle(.primary)

                                                Text("\(preset.words.count) " + appState.l("words"))
                                                    .font(.system(size: 9, weight: .bold))
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(Color.primary.opacity(0.08))
                                                    .foregroundStyle(Color.primary.opacity(0.85))
                                                    .cornerRadius(4)
                                            }

                                            if !preset.description.isEmpty {
                                                Text(preset.description)
                                                    .font(.system(size: 11))
                                                    .foregroundStyle(.secondary)
                                                    .lineLimit(1)
                                            }

                                            Text(preset.words.prefix(5).joined(separator: ", ") + (preset.words.count > 5 ? "..." : ""))
                                                .font(.system(size: 10))
                                                .foregroundStyle(.tertiary)
                                                .lineLimit(1)
                                        }

                                        Spacer()

                                        // Action buttons
                                        HStack(spacing: 6) {
                                            Button(action: { applyPreset(preset) }) {
                                                HStack(spacing: 4) {
                                                    Image(systemName: appliedPresetId == preset.id ? "checkmark" : "plus")
                                                    Text(appliedPresetId == preset.id ? appState.l("Applied!") : appState.l("Apply"))
                                                }
                                                .font(.system(size: 11, weight: .semibold))
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 5)
                                                .background(appliedPresetId == preset.id ? Color.green.opacity(0.15) : Color.primary.opacity(0.06))
                                                .foregroundStyle(appliedPresetId == preset.id ? .green : .primary)
                                                .cornerRadius(6)
                                            }
                                            .buttonStyle(.plain)

                                            Button(action: { sharePreset(preset) }) {
                                                HStack(spacing: 4) {
                                                    Image(systemName: copiedPresetId == preset.id ? "checkmark" : "square.and.arrow.up")
                                                    Text(copiedPresetId == preset.id ? appState.l("Copied!") : appState.l("Share"))
                                                }
                                                .font(.system(size: 11, weight: .semibold))
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 5)
                                                .background(copiedPresetId == preset.id ? Color.green.opacity(0.15) : Color.primary.opacity(0.08))
                                                .foregroundStyle(copiedPresetId == preset.id ? .green : .primary)
                                                .cornerRadius(6)
                                            }
                                            .buttonStyle(.plain)

                                            Button(action: { presetToDelete = preset }) {
                                                Image(systemName: "trash")
                                                    .font(.system(size: 11))
                                                    .foregroundStyle(.secondary)
                                                    .padding(6)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .padding(10)
                                    .background(Color.primary.opacity(0.03))
                                    .cornerRadius(10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                                    )
                                }
                            }
                        }
                    }
                    .padding(14)
                }

                // SECTION 3: Community & Model Improvement
                GlassSection(title: appState.l("Community Improvement"), icon: "network") {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(appState.l("Contribute to Scribe Vocabulary"))
                                .font(.system(size: 13, weight: .semibold))
                            Text(appState.l("Anonymously share added vocabulary terms to expand the built-in library for everyone."))
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: $appState.allowAnonymousVocabularyContribution)
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }
                    .padding(14)
                }
            } else {
                // SECTION 2: Custom Presets (Blocked Words)
                GlassSection(title: appState.l("Blocked Words Presets"), icon: "square.grid.2x2.fill") {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .center, spacing: 12) {
                            Text(appState.l("Create custom blocked word packs and share them instantly."))
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            HStack(spacing: 8) {
                                Button(action: { showingCreatePresetModal = true }) {
                                    HStack(spacing: 5) {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.system(size: 11, weight: .bold))
                                        Text(appState.l("Create Preset"))
                                            .font(.system(size: 11, weight: .bold, design: .rounded))
                                            .lineLimit(1)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 7)
                                    .background(Color.primary.opacity(0.06))
                                    .foregroundStyle(.primary)
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                                .fixedSize()

                                Button(action: { showingImportPresetModal = true }) {
                                    HStack(spacing: 5) {
                                        Image(systemName: "square.and.arrow.down.fill")
                                            .font(.system(size: 11, weight: .bold))
                                        Text(appState.l("Import Preset"))
                                            .font(.system(size: 11, weight: .bold, design: .rounded))
                                            .lineLimit(1)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 7)
                                    .background(Color.primary.opacity(0.06))
                                    .foregroundStyle(.primary)
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
                                        )
                                }
                                .buttonStyle(.plain)
                                .fixedSize()
                            }
                        }

                        if appState.customBlockedWordsPresets.isEmpty {
                            HStack(spacing: 8) {
                                Image(systemName: "shield.slash")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color.red.opacity(0.8))
                                Text(appState.l("No custom presets yet. Create one or import a share code to get started."))
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.primary.opacity(0.025))
                            .cornerRadius(8)
                        } else {
                            VStack(spacing: 8) {
                                ForEach(appState.customBlockedWordsPresets) { preset in
                                    HStack(spacing: 12) {
                                        VStack(alignment: .leading, spacing: 3) {
                                            HStack(spacing: 6) {
                                                Text(preset.name)
                                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                                    .foregroundStyle(.primary)

                                                Text("\(preset.words.count) " + appState.l("words"))
                                                    .font(.system(size: 9, weight: .bold))
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(Color.red.opacity(0.15))
                                                    .foregroundStyle(Color.red)
                                                    .cornerRadius(4)
                                            }

                                            if !preset.description.isEmpty {
                                                Text(preset.description)
                                                    .font(.system(size: 11))
                                                    .foregroundStyle(.secondary)
                                                    .lineLimit(1)
                                            }

                                            Text(preset.words.prefix(5).joined(separator: ", ") + (preset.words.count > 5 ? "..." : ""))
                                                .font(.system(size: 10))
                                                .foregroundStyle(.tertiary)
                                                .lineLimit(1)
                                        }

                                        Spacer()

                                        // Action buttons
                                        HStack(spacing: 6) {
                                            Button(action: { applyBlockedPreset(preset) }) {
                                                HStack(spacing: 4) {
                                                    Image(systemName: appliedPresetId == preset.id ? "checkmark" : "plus")
                                                    Text(appliedPresetId == preset.id ? appState.l("Applied!") : appState.l("Apply"))
                                                }
                                                .font(.system(size: 11, weight: .semibold))
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 5)
                                                .background(appliedPresetId == preset.id ? Color.green.opacity(0.15) : Color.primary.opacity(0.06))
                                                .foregroundStyle(appliedPresetId == preset.id ? .green : .primary)
                                                .cornerRadius(6)
                                            }
                                            .buttonStyle(.plain)

                                            Button(action: { shareBlockedPreset(preset) }) {
                                                HStack(spacing: 4) {
                                                    Image(systemName: copiedPresetId == preset.id ? "checkmark" : "square.and.arrow.up")
                                                    Text(copiedPresetId == preset.id ? appState.l("Copied!") : appState.l("Share"))
                                                }
                                                .font(.system(size: 11, weight: .semibold))
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 5)
                                                .background(copiedPresetId == preset.id ? Color.green.opacity(0.15) : Color.red.opacity(0.12))
                                                .foregroundStyle(copiedPresetId == preset.id ? .green : Color.red)
                                                .cornerRadius(6)
                                            }
                                            .buttonStyle(.plain)

                                            Button(action: { presetToDelete = preset }) {
                                                Image(systemName: "trash")
                                                    .font(.system(size: 11))
                                                    .foregroundStyle(.secondary)
                                                    .padding(6)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .padding(10)
                                    .background(Color.primary.opacity(0.03))
                                    .cornerRadius(10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .strokeBorder(Color.red.opacity(0.12), lineWidth: 1)
                                    )
                                }
                            }
                        }
                    }
                    .padding(14)
                }
            }
        }
        .alert(
            appState.l("Delete Preset"),
            isPresented: Binding(
                get: { presetToDelete != nil },
                set: { if !$0 { presetToDelete = nil } }
            ),
            presenting: presetToDelete
        ) { preset in
            Button(appState.l("Delete Preset & Remove Words"), role: .destructive) {
                if preset.category == "blocked" {
                    deleteBlockedPreset(preset, removeWordsFromActive: true)
                } else {
                    deletePreset(preset, removeWordsFromActive: true)
                }
            }
            Button(appState.l("Delete Preset & Keep Words")) {
                if preset.category == "blocked" {
                    deleteBlockedPreset(preset, removeWordsFromActive: false)
                } else {
                    deletePreset(preset, removeWordsFromActive: false)
                }
            }
            Button(appState.l("Cancel"), role: .cancel) {
                presetToDelete = nil
            }
        } message: { preset in
            Text(appState.l("Do you want to keep the words from this preset in your active dictionary, or remove them as well?"))
        }
        .onAppear {
            if !appState.hasPromptedVocabularyDataSharing {
                // Slight delay so the view transitions in smoothly before sheet appears
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    if !appState.hasPromptedVocabularyDataSharing {
                        showingContributionPromptModal = true
                    }
                }
            }
        }
        .sheet(isPresented: $showingCreatePresetModal) {
            CreatePresetModalView(category: selectedTab == .blockedWords ? "blocked" : "vocabulary")
        }
        .sheet(isPresented: $showingImportPresetModal) {
            ImportPresetModalView(category: selectedTab == .blockedWords ? "blocked" : "vocabulary")
        }
        .sheet(isPresented: $showingShareActiveModal) {
            ShareActiveWordsModalView(
                category: selectedTab == .blockedWords ? "blocked" : "vocabulary",
                allWords: selectedTab == .blockedWords ? blockedWordsList : wordsList
            )
        }
        .sheet(isPresented: $showingContributionPromptModal) {
            VocabularyContributionPromptModalView()
        }
    }
}

// MARK: - General Settings View
struct GeneralSettingsView: View {
    @EnvironmentObject var appState: AppState
    var body: some View {
        VStack(spacing: 16) {
            // SECTION: Language
            GlassSection(title: appState.l("Language"), icon: "globe") {
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
            }

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

                    // Push-to-Talk Toggle
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(appState.l("Push-to-Talk (Hold to record)"))
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundStyle(.primary)
                            Text(appState.l("Hold the hotkey to record, release to stop"))
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: $appState.pushToTalk)
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }

                    // Enable Direct Note Feature Toggle
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(appState.l("Enable Direct Note Feature"))
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundStyle(.primary)
                            Text(appState.l("Quick shortcut to dictate straight to your notes app"))
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { appState.enableDirectNote },
                            set: { val in
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    appState.enableDirectNote = val
                                }
                            }
                        ))
                        .toggleStyle(.switch)
                        .labelsHidden()
                    }

                    if appState.enableDirectNote {
                        VStack(spacing: 14) {
                            // Direct Note Export Shortcut
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(appState.l("Direct Note Shortcut"))
                                        .font(.system(size: 14, weight: .medium, design: .rounded))
                                        .foregroundStyle(.primary)
                                    Text(appState.l("Send text straight to notes app"))
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                KeyboardShortcuts.Recorder(for: .directNoteRecording)
                            }

                            // Direct Note Export Target Apps (1 or more)
                            HStack(alignment: .center) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(appState.l("Target Apps"))
                                        .font(.system(size: 14, weight: .medium, design: .rounded))
                                        .foregroundStyle(.primary)
                                    Text(appState.l("Select 1 or more apps for direct export"))
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                HStack(spacing: 6) {
                                    ForEach([NoteApp.appleNotes, NoteApp.obsidian, NoteApp.notion], id: \.self) { app in
                                        let isSelected = appState.directNoteTargetApps.contains(app)
                                        Button {
                                            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                                                appState.toggleDirectNoteTargetApp(app)
                                            }
                                        } label: {
                                            HStack(spacing: 5) {
                                                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                                    .font(.system(size: 12, weight: .bold))
                                                Text(appState.l(app.displayName))
                                                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular, design: .rounded))
                                            }
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .fill(isSelected ? appState.selectedTheme.gradientColors.first!.opacity(0.18) : Color.primary.opacity(0.04))
                                            )
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .stroke(isSelected ? appState.selectedTheme.gradientColors.first!.opacity(0.4) : Color.primary.opacity(0.1), lineWidth: 1)
                                            )
                                            .foregroundStyle(isSelected ? appState.selectedTheme.gradientColors.first! : .secondary)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)).combined(with: .scale(scale: 0.98, anchor: .top)))
                    }
                    
                    if appState.selectedPasteMode == .integrationsOnly {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(appState.l("Insertion & Export Mode"))
                                        .font(.system(size: 14, weight: .bold))
                                    Text(appState.l("Choose where transcribed text goes when dictation ends"))
                                        .font(.system(size: 11))
                                        .foregroundStyle(Color.primary.opacity(0.70))
                                }
                                Spacer()
                                LiquidGlassMenu(
                                    items: ["both", "notesOnly"],
                                    selection: $appState.integrationExportMode,
                                    title: { id in
                                        switch id {
                                        case "both": return appState.l("Active Window + Notes")
                                        case "notesOnly": return appState.l("Notes Only (No Window Paste)")
                                        default: return id
                                        }
                                    }
                                )
                            }
                        }
                        .padding(14)
                        .background(Color.primary.opacity(0.04))
                        .cornerRadius(12)
                        .transition(.opacity.combined(with: .move(edge: .top)).combined(with: .scale(scale: 0.98, anchor: .top)))
                    }
                }
            }

            // SECTION: Recording Options
            GlassSection(title: appState.l("Options"), icon: "gearshape") {
                VStack(spacing: 16) {
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

                    if appState.livePreviewEnabled {
                        VStack(spacing: 10) {
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
                        .padding(.top, 4)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
        }
    }
}

// MARK: - Cloud AI Settings View
struct CloudAISettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var testingConnection = false
    @State private var testStatusMessage: String? = nil

    var body: some View {
        VStack(spacing: 20) {
            GlassSection(title: appState.l("Scribe App Edition"), icon: "sparkles.tv.fill") {
                VStack(alignment: .leading, spacing: 16) {
                    // Edition Selector Header
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(appState.enableCloudAI ? "Scribe Pro + Cloud AI" : "Scribe Base")
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundStyle(.primary)

                                Text(appState.enableCloudAI ? "PRO EDITION" : "BASE EDITION")
                                    .font(.system(size: 9, weight: .bold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(appState.enableCloudAI ? Color.purple.opacity(0.2) : Color.blue.opacity(0.2))
                                    .foregroundStyle(appState.enableCloudAI ? Color.purple : Color.blue)
                                    .cornerRadius(4)
                            }
                            Text(appState.enableCloudAI ? 
                                 appState.l("Pro Edition: Enables ultra-fast Cloud AI, LLM text refinement (summaries, executive tone, action items) & Cloud Sync.") :
                                 appState.l("Base Edition: Free offline dictation, local Whisper models, text replacements, and notes integrations."))
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: $appState.enableCloudAI)
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }

                    if appState.enableCloudAI {
                        Divider().opacity(0.3)

                        // Scribe Pro License Token Input
                        VStack(alignment: .leading, spacing: 8) {
                            Text(appState.l("Scribe Pro License Key / Token"))
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(.primary)

                            HStack {
                                SecureField(appState.l("Enter your Scribe Pro key (scribe_pro_...)"), text: $appState.groqAPIKey)
                                .textFieldStyle(.plain)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(Color.primary.opacity(0.04))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                                )

                                Button(action: testConnection) {
                                    if testingConnection {
                                        ProgressView().scaleEffect(0.7)
                                    } else {
                                        Text(appState.l("Activate"))
                                            .font(.system(size: 12, weight: .semibold))
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(appState.selectedTheme.gradientColors.first!.opacity(0.12))
                                .cornerRadius(8)
                                .buttonStyle(.plain)
                            }

                            if let msg = testStatusMessage {
                                Text(msg)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(msg.contains("Active") || msg.contains("Success") ? .green : .red)
                            }
                        }

                        Divider().opacity(0.3)

                        // AI Refinement Mode Selector
                        VStack(alignment: .leading, spacing: 8) {
                            Text(appState.l("Smart LLM Voice Refinement"))
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(.primary)
                            Text(appState.l("Automatically transforms your dictation after speech recognition completes"))
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)

                            LiquidGlassSegmentedPicker(
                                items: AIRefinementMode.allCases,
                                selection: $appState.selectedAIRefinementMode,
                                label: { ($0.displayName, $0.icon) }
                            )
                        }
                    }
                }
            }
        }
    }

    private func testConnection() {
        let key = appState.groqAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            testStatusMessage = "Please enter a valid Scribe Pro license key"
            return
        }
        testingConnection = true
        testStatusMessage = nil

        Task {
            do {
                _ = try await CloudAIService.shared.refineText(
                    text: "Test connection",
                    mode: .summary,
                    provider: .groq,
                    apiKey: key
                )
                testingConnection = false
                testStatusMessage = "Scribe Pro License Active! Cloud features enabled."
            } catch {
                testingConnection = false
                testStatusMessage = "License verification failed: \(error.localizedDescription)"
            }
        }
    }
}


// MARK: - Sidebar Account Footer View
struct SidebarAccountFooterView: View {
    @ObservedObject var authService = AuthService.shared
    @EnvironmentObject var appState: AppState
    @Binding var showingAuthModal: Bool
    @Binding var showingAccountSettingsModal: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
                .opacity(0.3)
                .padding(.bottom, 2)

            if let user = authService.currentUser {
                HStack(spacing: 8) {
                    // Profile details button (opens Account Settings)
                    Button {
                        showingAccountSettingsModal = true
                    } label: {
                        HStack(spacing: 8) {
                            // Avatar / Initials Circle
                            ZStack {
                                Circle()
                                    .fill(appState.selectedTheme.gradientColors.first!.opacity(0.2))
                                    .frame(width: 28, height: 28)

                                Text(user.initials)
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundStyle(appState.selectedTheme.gradientColors.first!)
                            }

                            VStack(alignment: .leading, spacing: 1) {
                                Text(user.name.isEmpty ? "User" : user.name)
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)

                                if !user.email.isEmpty && !user.email.contains("noreply.github.com") && !user.email.hasSuffix("@github.com") {
                                    Text(user.email)
                                        .font(.system(size: 9, weight: .semibold))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                        }
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    // Exit / Sign Out Button
                    Button(action: {
                        authService.signOut()
                    }) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Sign Out")
                }
                .padding(6)
                .background(Color.primary.opacity(0.04))
                .cornerRadius(8)
            } else {
                Button(action: {
                    showingAuthModal = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(appState.selectedTheme.gradientColors.first!)

                        Text(appState.l("Sign In"))
                            .font(.system(size: 11, weight: .semibold, design: .rounded))

                        Spacer()

                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 7)
                    .background(Color.primary.opacity(0.04))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Account Settings Modal View
struct AccountSettingsModalView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @ObservedObject var authService = AuthService.shared

    @State private var nickname: String = ""
    @State private var statusMessage: String? = nil
    @State private var isSuccessStatus = false
    @State private var showingDeleteAlert = false
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "gearshape.fill")
                        .font(.title2)
                        .foregroundStyle(appState.selectedTheme.gradientColors.first!)

                    Text(appState.l("Account Settings"))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                }
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

            if let user = authService.currentUser {
                VStack(spacing: 16) {
                    // Profile Header Card
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(appState.selectedTheme.gradientColors.first!.opacity(0.2))
                                .frame(width: 44, height: 44)

                            Text(user.initials)
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(appState.selectedTheme.gradientColors.first!)
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text(user.name.isEmpty ? "User" : user.name)
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary)

                            if !user.email.isEmpty && !user.email.contains("noreply.github.com") && !user.email.hasSuffix("@github.com") {
                                Text(user.email)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                    }
                    .padding(12)
                    .background(Color.primary.opacity(0.04))
                    .cornerRadius(12)

                    // Edit Nickname
                    VStack(alignment: .leading, spacing: 6) {
                        Text(appState.l("Nickname / Display Name"))
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)

                        HStack(spacing: 8) {
                            TextField(appState.l("Enter nickname"), text: $nickname)
                                .textFieldStyle(.plain)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.primary.opacity(0.04))
                                .cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.1), lineWidth: 1))

                            Button(appState.l("Save")) {
                                Task {
                                    do {
                                        try await authService.updateDisplayName(nickname)
                                        statusMessage = appState.l("Name updated successfully!")
                                        isSuccessStatus = true
                                    } catch {
                                        statusMessage = error.localizedDescription
                                        isSuccessStatus = false
                                    }
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }

                    if let msg = statusMessage {
                        Text(msg)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(isSuccessStatus ? Color.green : Color.red)
                            .multilineTextAlignment(.center)
                    }

                    Divider()
                        .padding(.vertical, 4)

                    // Account Actions
                    VStack(spacing: 10) {
                                             Button {
                            let isGoogle = user.id.hasPrefix("google_") || 
                                           user.email.hasSuffix("@gmail.com") || 
                                           user.email.hasSuffix("@googlemail.com") ||
                                           (Auth.auth().currentUser?.providerData.contains(where: { $0.providerID == "google.com" }) ?? false)
                            let isGitHub = user.id.hasPrefix("gh_")

                            if isGoogle {
                                if let url = URL(string: "https://myaccount.google.com/signinoptions/password") {
                                    NSWorkspace.shared.open(url)
                                }
                                statusMessage = appState.l("Opened official Google password reset page in browser.")
                                isSuccessStatus = true
                            } else if isGitHub || user.email.isEmpty {
                                if let url = URL(string: "https://github.com/password_reset") {
                                    NSWorkspace.shared.open(url)
                                }
                                statusMessage = appState.l("Opened GitHub password reset page in browser.")
                                isSuccessStatus = true
                            } else {
                                Task {
                                    do {
                                        try await authService.resetPassword()
                                        statusMessage = "\(appState.l("Password reset email sent to")) \(user.email). Check Spam/Inbox."
                                        isSuccessStatus = true
                                    } catch {
                                        statusMessage = error.localizedDescription
                                        isSuccessStatus = false
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                let isGoogle = user.id.hasPrefix("google_") || 
                                               user.email.hasSuffix("@gmail.com") || 
                                               user.email.hasSuffix("@googlemail.com") ||
                                               (Auth.auth().currentUser?.providerData.contains(where: { $0.providerID == "google.com" }) ?? false)
                                let isGitHub = user.id.hasPrefix("gh_")

                                Image(systemName: (isGoogle || isGitHub) ? "arrow.up.right.square" : "key.fill")
                                Text(isGoogle ? appState.l("Manage Password on Google.com") : (isGitHub ? appState.l("Reset Password on GitHub.com") : appState.l("Reset / Change Password")))
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color.primary.opacity(0.04))
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)

                        // Sign Out Button
                        Button {
                            authService.signOut()
                            dismiss()
                        } label: {
                            HStack {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                Text(appState.l("Sign Out"))
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color.primary.opacity(0.04))
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)

                        // Delete Account Button
                        Button {
                            showingDeleteAlert = true
                        } label: {
                            HStack {
                                Image(systemName: "trash.fill")
                                Text(appState.l("Delete Account"))
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                Spacer()
                            }
                            .foregroundStyle(.red)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color.red.opacity(0.08))
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                        .alert(appState.l("Delete Account"), isPresented: $showingDeleteAlert) {
                            Button(appState.l("Delete"), role: .destructive) {
                                Task {
                                    do {
                                        try await authService.deleteAccount()
                                        dismiss()
                                    } catch {
                                        statusMessage = error.localizedDescription
                                        isSuccessStatus = false
                                    }
                                }
                            }
                            Button(appState.l("Cancel"), role: .cancel) {}
                        } message: {
                            Text(appState.l("Are you sure you want to delete your account? This action cannot be undone and your synced data will be removed."))
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .onAppear {
                    nickname = user.name
                }
            }

            Spacer(minLength: 0)
        }
        .frame(width: 380, height: 430)
        .background(.ultraThinMaterial)
    }
}

// MARK: - Auth Modal View
struct AuthModalView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @ObservedObject var authService = AuthService.shared

    @State private var isWaitingForLogin = false
    @State private var waitingProviderName = "Google"
    @State private var waitingProviderIcon = "g.circle.fill"
    @State private var waitingProviderColor = Color(red: 0.9, green: 0.25, blue: 0.2)
    @State private var waitingUserCode: String? = nil
    @State private var showEmailForm = false
    @State private var showingGitHubInput = false
    @State private var showGoogleInput = false
    @State private var showForgotPassword = false
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var errorMessage: String? = nil
    @State private var successMessage: String? = nil
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    if showEmailForm || showingGitHubInput || showGoogleInput || showForgotPassword || isWaitingForLogin {
                        Button {
                            authService.cancelOAuth()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                showEmailForm = false
                                showingGitHubInput = false
                                showGoogleInput = false
                                showForgotPassword = false
                                isWaitingForLogin = false
                                waitingUserCode = nil
                                errorMessage = nil
                                successMessage = nil
                            }
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Image(systemName: "person.badge.key.fill")
                            .font(.title2)
                            .foregroundStyle(appState.selectedTheme.gradientColors.first!)
                    }

                    Text(headerTitle)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                }
                Spacer()
                Button {
                    authService.cancelOAuth()
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

            if isWaitingForLogin {
                WaitingForLoginView(
                    providerName: waitingProviderName,
                    providerIcon: waitingProviderIcon,
                    providerColor: waitingProviderColor,
                    userCode: waitingUserCode
                ) {
                    authService.cancelOAuth()
                    withAnimation {
                        isWaitingForLogin = false
                        waitingUserCode = nil
                    }
                }
            } else if showForgotPassword {
                // Password Reset View
                VStack(spacing: 12) {
                    Text(appState.l("Reset Account Password"))
                        .font(.system(size: 14, weight: .bold, design: .rounded))

                    VStack(alignment: .leading, spacing: 5) {
                        Text(appState.l("Email or Username"))
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)

                        TextField(appState.l("name@example.com or username"), text: $email)
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Color.primary.opacity(0.04))
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.1), lineWidth: 1))
                    }

                    if let err = errorMessage {
                        Text(err)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }

                    if let succ = successMessage {
                        Text(succ)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.green)
                            .multilineTextAlignment(.center)
                    }

                    Button {
                        isLoading = true
                        errorMessage = nil
                        successMessage = nil
                        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !cleanEmail.isEmpty else {
                            errorMessage = appState.l("Please enter your email address")
                            isLoading = false
                            return
                        }
                        Task {
                            do {
                                try await authService.resetPassword(email: cleanEmail)
                                successMessage = "\(appState.l("Reset link sent to")) \(cleanEmail). Check Inbox/Spam."
                            } catch {
                                errorMessage = error.localizedDescription
                            }
                            isLoading = false
                        }
                    } label: {
                        HStack {
                            Spacer()
                            if isLoading {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "envelope.fill")
                                    .font(.system(size: 12))
                                Text(appState.l("Send Email Reset Link"))
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color(NSColor.windowBackgroundColor))
                            }
                            Spacer()
                        }
                        .padding(.vertical, 9)
                        .background(Color.primary)
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)

                    Divider()
                        .padding(.vertical, 2)

                    HStack(spacing: 12) {
                        Button {
                            if let url = URL(string: "https://github.com/password_reset") {
                                NSWorkspace.shared.open(url)
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.up.right.square")
                                    .font(.system(size: 10))
                                Text("GitHub Reset")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)

                        Button {
                            if let url = URL(string: "https://accounts.google.com/signin/recovery") {
                                NSWorkspace.shared.open(url)
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.up.right.square")
                                    .font(.system(size: 10))
                                Text("Google Recovery")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
            } else if showGoogleInput {
                // Google Account Sign In View
                VStack(spacing: 12) {
                    Text(appState.l("Google Account Sign In"))
                        .font(.system(size: 14, weight: .bold, design: .rounded))

                    VStack(alignment: .leading, spacing: 5) {
                        Text(appState.l("Google Email"))
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)

                        TextField("user@gmail.com", text: $email)
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Color.primary.opacity(0.04))
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.1), lineWidth: 1))
                    }

                    if let err = errorMessage {
                        Text(err)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.red)
                    }

                    Button {
                        isLoading = true
                        errorMessage = nil
                        Task {
                            do {
                                try await authService.signInWithGoogleAccount(email: email)
                                isLoading = false
                                dismiss()
                            } catch {
                                isLoading = false
                                errorMessage = error.localizedDescription
                            }
                        }
                    } label: {
                        HStack {
                            Spacer()
                            if isLoading {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "g.circle.fill")
                                    .font(.system(size: 12))
                                Text(appState.l("Sign In with Google"))
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color(NSColor.windowBackgroundColor))
                            }
                            Spacer()
                        }
                        .padding(.vertical, 10)
                        .background(Color(red: 0.9, green: 0.25, blue: 0.2))
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
            } else if showEmailForm {
                // Email / Password Form View
                VStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Email")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)

                        TextField("name@example.com", text: $email)
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Color.primary.opacity(0.04))
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.1), lineWidth: 1))
                    }

                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text("Password")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button {
                                withAnimation {
                                    showForgotPassword = true
                                }
                            } label: {
                                Text(appState.l("Forgot?"))
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }

                        SecureField("••••••••", text: $password)
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Color.primary.opacity(0.04))
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.1), lineWidth: 1))
                    }

                    if let err = errorMessage {
                        Text(err)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.red)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                    }

                    Button {
                        isLoading = true
                        errorMessage = nil
                        Task {
                            do {
                                if isSignUp {
                                    try await authService.signUpWithEmail(email: email, password: password)
                                } else {
                                    try await authService.signInWithEmail(email: email, password: password)
                                }
                                isLoading = false
                                dismiss()
                            } catch {
                                isLoading = false
                                errorMessage = error.localizedDescription
                            }
                        }
                    } label: {
                        HStack {
                            Spacer()
                            if isLoading {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Text(isSignUp ? appState.l("Create Account") : appState.l("Sign In"))
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color(NSColor.windowBackgroundColor))
                            }
                            Spacer()
                        }
                        .padding(.vertical, 10)
                        .background(Color.primary)
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)

                    Button {
                        withAnimation {
                            isSignUp.toggle()
                            errorMessage = nil
                        }
                    } label: {
                        Text(isSignUp ? appState.l("Already have an account? Sign In") : appState.l("Need an account? Register"))
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
            } else if showingGitHubInput {
                // GitHub Account Sign In
                VStack(spacing: 12) {
                    Text(appState.l("GitHub Account Sign In"))
                        .font(.system(size: 14, weight: .bold, design: .rounded))

                    VStack(alignment: .leading, spacing: 5) {
                        Text(appState.l("GitHub Username or Email"))
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)

                        TextField(appState.l("octocat or user@github.com"), text: $email)
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Color.primary.opacity(0.04))
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.1), lineWidth: 1))
                    }

                    VStack(alignment: .leading, spacing: 5) {
                        Text(appState.l("GitHub Password or 2FA Token"))
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)

                        SecureField(appState.l("Password or ghp_token..."), text: $password)
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Color.primary.opacity(0.04))
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.1), lineWidth: 1))
                    }

                    Text(appState.l("If you have 2FA enabled, you can enter your Personal Access Token (PAT)."))
                        .font(.system(size: 10, weight: .regular, design: .rounded))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)

                    if let err = errorMessage {
                        Text(err)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.red)
                    }

                    Button {
                        isLoading = true
                        errorMessage = nil
                        Task {
                            do {
                                try await authService.signInWithGitHubAccount(username: email, tokenOrPassword: password)
                                isLoading = false
                                dismiss()
                            } catch {
                                isLoading = false
                                errorMessage = error.localizedDescription
                            }
                        }
                    } label: {
                        HStack {
                            Spacer()
                            if isLoading {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "lock.shield.fill")
                                    .font(.system(size: 12))
                                Text(appState.l("Sign In with GitHub Account"))
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color(NSColor.windowBackgroundColor))
                            }
                            Spacer()
                        }
                        .padding(.vertical, 10)
                        .background(Color.primary)
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .padding(.top, 10)
            } else {
                // Provider Selection View
                VStack(spacing: 14) {
                    Text(appState.l("Sign in to sync your statistics, history, and subscriptions in future across all your devices."))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 20)
                        .padding(.top, 10)

                    VStack(spacing: 10) {
                        // Google Sign In Button
                        AuthModalRow(
                            title: appState.l("Continue with Google"),
                            icon: "g.circle.fill",
                            iconColor: Color(red: 0.9, green: 0.25, blue: 0.2)
                        ) {
                            waitingProviderName = "Google"
                            waitingProviderIcon = "g.circle.fill"
                            waitingProviderColor = Color(red: 0.9, green: 0.25, blue: 0.2)
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                isWaitingForLogin = true
                            }
                            Task {
                                do {
                                    try await authService.signInWithGoogleOAuth()
                                    await MainActor.run {
                                        dismiss()
                                    }
                                } catch {
                                    await MainActor.run {
                                        isWaitingForLogin = false
                                        errorMessage = error.localizedDescription
                                    }
                                }
                            }
                        }

                        // GitHub Sign In Button
                        AuthModalRow(
                            title: appState.l("Continue with GitHub"),
                            icon: "chevron.left.forwardslash.chevron.right",
                            iconColor: .purple
                        ) {
                            waitingProviderName = "GitHub"
                            waitingProviderIcon = "chevron.left.forwardslash.chevron.right"
                            waitingProviderColor = .purple
                            errorMessage = nil
                            successMessage = nil
                            waitingUserCode = nil
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                isWaitingForLogin = true
                            }
                            Task {
                                do {
                                    try await authService.signInWithGitHubOAuth { code, _ in
                                        waitingUserCode = code
                                    }
                                    await MainActor.run {
                                        dismiss()
                                    }
                                } catch {
                                    await MainActor.run {
                                        isWaitingForLogin = false
                                        errorMessage = error.localizedDescription
                                    }
                                }
                            }
                        }

                        // Email / Password Button
                        AuthModalRow(
                            title: appState.l("Continue with Email"),
                            icon: "envelope.fill",
                            iconColor: .blue
                        ) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                showEmailForm = true
                            }
                        }
                    }
                    .padding(.horizontal, 20)

                    if let err = errorMessage {
                        VStack(spacing: 6) {
                            Text(err)
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(.red)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 12)
                            
                            if err.contains("Device Flow") || err.contains("GitHub") {
                                Button {
                                    if let url = URL(string: "https://github.com/settings/developers") {
                                        NSWorkspace.shared.open(url)
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "arrow.up.right.square")
                                        Text("Открыть настройки GitHub OAuth")
                                    }
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundStyle(.purple)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(8)
                        .background(Color.red.opacity(0.08))
                        .cornerRadius(8)
                        .padding(.horizontal, 20)
                    }

                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            showForgotPassword = true
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "questionmark.circle")
                                .font(.system(size: 11))
                            Text(appState.l("Forgot Password / Account Recovery"))
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                        }
                        .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 12)
                }
            }

            Spacer(minLength: 0)
        }
        .frame(width: 380, height: 380)
        .background(.ultraThinMaterial)
    }

    private var headerTitle: String {
        if isWaitingForLogin {
            return "Signing In…"
        } else if showForgotPassword {
            return appState.l("Password Recovery")
        } else if showGoogleInput {
            return "Google Sign In"
        } else if showingGitHubInput {
            return "GitHub Sign In"
        } else if showEmailForm {
            return isSignUp ? appState.l("Create Account") : appState.l("Email Sign In")
        } else {
            return appState.l("Sign In to Scribe")
        }
    }
}

struct WaitingForLoginView: View {
    let providerName: String
    let providerIcon: String
    let providerColor: Color
    var userCode: String? = nil
    let onCancel: () -> Void

    @State private var isSpinning = false
    @State private var isPulsing = false

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            ZStack {
                Circle()
                    .stroke(providerColor.opacity(0.15), lineWidth: 5)
                    .frame(width: 72, height: 72)

                Circle()
                    .trim(from: 0, to: 0.65)
                    .stroke(providerColor, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                    .frame(width: 72, height: 72)
                    .rotationEffect(.degrees(isSpinning ? 360 : 0))
                    .animation(.linear(duration: 1.1).repeatForever(autoreverses: false), value: isSpinning)

                Image(systemName: providerIcon)
                    .font(.system(size: 28))
                    .foregroundStyle(providerColor)
                    .scaleEffect(isPulsing ? 1.08 : 0.94)
                    .animation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true), value: isPulsing)
            }
            .onAppear {
                isSpinning = true
                isPulsing = true
            }

            VStack(spacing: 6) {
                Text(userCode != nil ? "Подтвердите вход в браузере" : "Ожидание входа через браузер…")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                if let code = userCode {
                    VStack(spacing: 4) {
                        HStack(spacing: 8) {
                            Text(code)
                                .font(.system(size: 18, weight: .black, design: .monospaced))
                                .foregroundStyle(providerColor)
                            
                            Image(systemName: "doc.on.doc.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(providerColor.opacity(0.12))
                        .cornerRadius(8)
                        
                        Text("Код скопирован в буфер. Вставьте его в браузере.")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("Завершите авторизацию в открывшемся окне браузера.")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
            }

            Button(action: onCancel) {
                Text("Отмена")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 7)
                    .background(Color.primary.opacity(0.06))
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .padding(.top, 2)

            Spacer()
        }
        .padding(.vertical, 12)
    }
}

struct AuthModalRow: View {
    let title: String
    let icon: String
    let iconColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(iconColor)
                }
                .frame(width: 24, height: 24, alignment: .center)

                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)

                Spacer()

                Image(systemName: "arrow.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.primary.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Onboarding Name Prompt Modal View
struct OnboardingNameModalView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @ObservedObject var authService = AuthService.shared

    @State private var nameInput: String = ""

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(appState.selectedTheme.gradientColors.first!.opacity(0.15))
                    .frame(width: 56, height: 56)

                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(appState.selectedTheme.gradientColors.first!)
            }
            .padding(.top, 10)

            VStack(spacing: 6) {
                Text(appState.l("What should we call you?"))
                    .font(.system(size: 18, weight: .bold, design: .rounded))

                Text(appState.l("Enter your name or nickname to personalize Scribe"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            TextField(appState.l("Your name or nickname..."), text: $nameInput)
                .textFieldStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.primary.opacity(0.04))
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.12), lineWidth: 1))
                .padding(.horizontal, 10)

            Button {
                let finalName = nameInput.trimmingCharacters(in: .whitespaces)
                if !finalName.isEmpty {
                    appState.userName = finalName
                    UserDefaults.standard.set(finalName, forKey: "userName")
                    Task {
                        try? await authService.updateDisplayName(finalName)
                    }
                }
                UserDefaults.standard.set(true, forKey: "hasCompletedOnboardingNamePrompt")
                dismiss()
            } label: {
                HStack {
                    Spacer()
                    Text(appState.l("Continue"))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(NSColor.windowBackgroundColor))
                    Spacer()
                }
                .padding(.vertical, 10)
                .background(Color.primary)
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 10)
        }
        .padding(24)
        .frame(width: 340, height: 320)
        .background(.ultraThinMaterial)
    }
}
