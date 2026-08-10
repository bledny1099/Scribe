import re

with open("Scribe/UI/SettingsView.swift", "r") as f:
    text = f.read()

# 1. Fix contentForTab to remove .system
contentForTab_old = """    @ViewBuilder
    private var contentForTab: some View {
        switch selectedTab {
        case .general: generalSettings
        case .appearance: appearanceSettings
        case .recognition: recognitionSettings
        case .statistics: StatisticsSectionView()
        case .replacements: ReplacementsSettingsView()
        case .integrations: IntegrationsSettingsView()
        case .system: systemSettings
        }
    }"""
contentForTab_new = """    @ViewBuilder
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
text = text.replace(contentForTab_old, contentForTab_new)

# 2. Fix SettingsTab enum to remove .system
enum_old = """enum SettingsTab: String, CaseIterable {
    case general = "General"
    case appearance = "Appearance"
    case recognition = "Recognition"
    case statistics = "Statistics"
    case replacements = "Replacements"
    case integrations = "Integrations"
    case system = "System"
}"""
enum_new = """enum SettingsTab: String, CaseIterable {
    case general = "General"
    case appearance = "Appearance"
    case recognition = "Recognition"
    case statistics = "Statistics"
    case replacements = "Replacements"
    case integrations = "Integrations"
}"""
text = text.replace(enum_old, enum_new)

# 3. Replace recognitionSettings with the accurate version
recognition_old_start = "    private var recognitionSettings: some View {"
recognition_old_end = "    private var systemSettings: some View {"
if recognition_old_end in text:
    recognition_old = text[text.find(recognition_old_start) : text.find(recognition_old_end)]
    
    recognition_new = """    private var recognitionSettings: some View {
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
"""
    text = text.replace(recognition_old, recognition_new)

# 4. Remove systemSettings entirely
system_start = "    private var systemSettings: some View {"
system_end = "    }\n}\n"
if system_start in text:
    idx_start = text.find(system_start)
    idx_end = text.find(system_end, idx_start) + len("    }\n}\n")
    # Wait, systemSettings might be at the end of the struct
    # Let's just remove it using regex
    import re
    text = re.sub(r"    private var systemSettings: some View \{.*?(?=^// MARK:|\z)", "", text, flags=re.DOTALL | re.MULTILINE)

# Also make sure the SettingsView struct has a closing brace if we accidentally removed it
if not text.endswith("}") and "// MARK:" not in text[text.rfind("}"):]:
    # Let's count braces to be safe, but a simple replace is safer
    pass

with open("Scribe/UI/SettingsView.swift", "w") as f:
    f.write(text)

print("Removed system settings and fixed recognition.")
