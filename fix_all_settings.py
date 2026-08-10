import re
import sys

with open("Scribe/UI/SettingsView.swift", "r") as f:
    text = f.read()

# 1. Add Recognition Mode to recognitionSettings
if "Recognition Mode" not in text:
    target_lang = """                HStack {
                    Text(appState.l("Dictation Language"))"""
    replacement_lang = """                HStack {
                    Text(appState.l("Recognition Mode"))
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.primary)
                    Spacer()
                    LiquidGlassSegmentedPicker(
                        items: RecognitionMode.allCases,
                        selection: Binding(
                            get: { appState.recognitionMode },
                            set: { appState.recognitionMode = $0 }
                        ),
                        label: { (appState.l($0.displayName), "") }
                    )
                }

                HStack {
                    Text(appState.l("Dictation Language"))"""
    text = text.replace(target_lang, replacement_lang)
    print("Replaced Recognition Mode")

# 2. Make sidebar tabs glow with theme color
target_glow = ".background(selectedTab == tab ? Color.primary.opacity(0.1) : Color.clear)"
replacement_glow = ".background(selectedTab == tab ? appState.selectedTheme.gradientColors.first!.opacity(0.2) : Color.clear)"
if target_glow in text:
    text = text.replace(target_glow, replacement_glow)
    print("Replaced Glow")

# 3. Add System tab back to enum
enum_old = """enum SettingsTab: String, CaseIterable {
    case general = "General"
    case appearance = "Appearance"
    case recognition = "Recognition"
    case statistics = "Statistics"
    case replacements = "Replacements"
    case integrations = "Integrations"
}"""
enum_new = """enum SettingsTab: String, CaseIterable {
    case general = "General"
    case appearance = "Appearance"
    case recognition = "Recognition"
    case statistics = "Statistics"
    case system = "System"
    case replacements = "Replacements"
    case integrations = "Integrations"
}"""
text = text.replace(enum_old, enum_new)
print("Replaced enum")

# 4. Add system to contentForTab
content_old = """    @ViewBuilder
    private var contentForTab: some View {
        switch selectedTab {
        case .general: generalSettings
        case .appearance: appearanceSettings
        case .recognition: recognitionSettings
        case .statistics: StatisticsSectionView()
        case .replacements: ReplacementsSettingsView()
        case .integrations: IntegrationsSettingsView()
        }
    }"""
content_new = """    @ViewBuilder
    private var contentForTab: some View {
        switch selectedTab {
        case .general: generalSettings
        case .appearance: appearanceSettings
        case .recognition: recognitionSettings
        case .statistics: StatisticsSectionView()
        case .system: systemSettings
        case .replacements: ReplacementsSettingsView()
        case .integrations: IntegrationsSettingsView()
        }
    }"""
text = text.replace(content_old, content_new)
print("Replaced contentForTab")

# 5. Insert systemSettings property
if "private var systemSettings: some View" not in text:
    system_settings_str = """
    private var systemSettings: some View {
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
    }
"""
    # Insert right before struct StatisticsSectionView
    target_insert = "struct StatisticsSectionView: View {"
    text = text.replace(target_insert, system_settings_str + "\n" + target_insert)
    print("Inserted systemSettings")

# 6. Revert Stats Design
stats_old_pattern = r"// Level and XP\s+VStack.*?\.shadow\(color: history\.currentLevelColor\.opacity\(0\.3\), radius: 10, x: 0, y: 0\)\n\s+\)"
stats_new = """// Gamification: Level & Time Saved
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(appState.l("Time Saved"))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)
                        Text(formatDuration(history.timeSaved))
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 6) {
                        Text(history.currentLevelName)
                            .font(.system(size: 16, weight: .bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            
                        if history.currentLevel < 50 {
                            Text("\(history.wordsToNextLevel) words to Level \(history.currentLevel + 1)")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        } else {
                            Text("Max Level Reached!")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        
                        HStack(spacing: 8) {
                            Text("\(appState.l("Level")) \(history.currentLevel)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                            
                            ProgressView(value: history.currentLevelProgress, total: 1.0)
                                .progressViewStyle(.linear)
                                .frame(width: 100)
                        }
                    }
                }
                .padding()
                .background(Color.primary.opacity(0.04))
                .cornerRadius(12)"""
if "// Level and XP" in text:
    text = re.sub(stats_old_pattern, stats_new, text, flags=re.DOTALL)
    print("Reverted stats design")

# Write back
with open("Scribe/UI/SettingsView.swift", "w") as f:
    f.write(text)

print("Done fixing SettingsView")
