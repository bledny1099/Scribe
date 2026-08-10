import re

with open("Scribe/UI/SettingsView.swift", "r") as f:
    text = f.read()

# 1. Reorder SettingsTab enum
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
    case system = "System"
    case replacements = "Replacements"
    case integrations = "Integrations"
}"""
if enum_old in text:
    text = text.replace(enum_old, enum_new)
    print("Reordered enum")

# 2. Add Push-to-Talk to General (case .general:)
# We'll insert it right after the Paste Mode HStack.
paste_mode_pattern = r"(HStack \{\n\s+Text\(appState\.l\(\"Paste Mode\"\)\)[\s\S]*?LiquidGlassSegmentedPicker[^\}]+\}\n\s+\}\n\s+\))"
push_to_talk_ui = """
                            HStack {
                                Text(appState.l("Hold to Dictate"))
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundStyle(.primary)
                                Spacer()
                                Toggle("", isOn: $appState.holdToDictateEnabled)
                                    .toggleStyle(.switch)
                                    .labelsHidden()
                            }
"""
text = re.sub(paste_mode_pattern, r"\1" + push_to_talk_ui, text)
print("Added Push-to-talk")


# 3. Move Sound Feedback to Appearance
sound_feedback_block = """                            // Sound feedback
                            HStack {
                                Text(appState.l("Sound Feedback"))
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundStyle(.primary)
                                Spacer()
                                Toggle("", isOn: $appState.soundFeedbackEnabled)
                                    .toggleStyle(.switch)
                                    .labelsHidden()
                            }"""
if sound_feedback_block in text:
    text = text.replace(sound_feedback_block, "")
    print("Removed Sound Feedback from System")

    appearance_pattern = r"(GlassSection\(title: appState\.l\(\"Appearance\"\), icon: \"paintbrush\.fill\"\) \{\n\s+VStack\(spacing: 16\) \{)"
    appearance_injection = r"\1" + "\n" + sound_feedback_block + "\n"
    text = re.sub(appearance_pattern, appearance_injection, text)
    print("Added Sound Feedback to Appearance")

# 4. Remove Gamification from StatisticsSectionView
stats_gamification_pattern = r"// Gamification: Level & Time Saved.*?\.cornerRadius\(12\)"
text = re.sub(stats_gamification_pattern, "", text, flags=re.DOTALL)

# But wait, in the backup, it might be called "Level and XP"! Let's check!
old_gamification_pattern = r"// Level and XP\s+VStack.*?\.shadow\(color: history\.currentLevelColor\.opacity\(0\.3\), radius: 10, x: 0, y: 0\)\n\s+\)"
if "// Level and XP" in text:
    text = re.sub(old_gamification_pattern, "", text, flags=re.DOTALL)
    print("Removed Gamification (Level and XP)")


# 5. Enhance IntegrationsSettingsView
integrations_old_pattern = r"struct IntegrationsSettingsView: View \{.*?\n\s+\}\n\}\n"
integrations_new = """struct IntegrationsSettingsView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        GlassSection(title: appState.l("Integrations"), icon: "link") {
            VStack(alignment: .leading, spacing: 16) {
                // Obsidian Integration
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Obsidian")
                            .font(.system(size: 14, weight: .bold))
                        Text("Send transcripts directly to Obsidian")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $appState.enableObsidian)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }
                
                if appState.enableObsidian {
                    VStack(alignment: .leading, spacing: 8) {
                        Button("Select Vault Folder") {
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
                        
                        Text(appState.obsidianVaultURL.isEmpty ? "No vault selected" : appState.obsidianVaultURL)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            
                        HStack {
                            Text("Target Note:")
                            TextField("e.g. Scribe Transcriptions", text: $appState.obsidianTargetNote)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                    .padding(.leading, 10)
                }

                Divider()

                // Apple Notes Integration
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Apple Notes")
                            .font(.system(size: 14, weight: .bold))
                        Text("Send transcripts directly to Apple Notes")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $appState.enableAppleNotes)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }
                
                if appState.enableAppleNotes {
                    HStack {
                        Text("Target Note:")
                        TextField("e.g. Scribe Transcriptions", text: $appState.appleNotesTargetNote)
                            .textFieldStyle(.roundedBorder)
                    }
                    .padding(.leading, 10)
                }

                Divider()

                // Notion Integration
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Notion")
                            .font(.system(size: 14, weight: .bold))
                        Text("Send transcripts directly to Notion")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $appState.enableNotion)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }
                
                if appState.enableNotion {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("API Token:")
                            SecureField("Secret Token", text: $appState.notionIntegrationToken)
                                .textFieldStyle(.roundedBorder)
                        }
                        HStack {
                            Text("Page ID:")
                            TextField("Target Page ID", text: $appState.notionPageId)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                    .padding(.leading, 10)
                }
                
                Divider()
                
                // Common Export Settings
                Text("Common Export Settings")
                    .font(.system(size: 13, weight: .semibold))
                    .padding(.top, 4)
                    
                Toggle("Append Date to Notes", isOn: $appState.appendDateToNotes)
                Toggle("Attach Audio to Notes", isOn: $appState.attachAudioToNotes)
                
                HStack {
                    Text("Tags:")
                    TextField("e.g. #transcription #meeting", text: $appState.defaultNoteTags)
                        .textFieldStyle(.roundedBorder)
                }
            }
            .padding(14)
        }
    }
}
"""
text = re.sub(integrations_old_pattern, integrations_new, text, flags=re.DOTALL)
print("Updated IntegrationsSettingsView")

# 6. Make sidebar tabs glow with theme color
target_glow = ".background(selectedTab == tab ? Color.primary.opacity(0.1) : Color.clear)"
replacement_glow = ".background(selectedTab == tab ? appState.selectedTheme.gradientColors.first!.opacity(0.2) : Color.clear)"
if target_glow in text:
    text = text.replace(target_glow, replacement_glow)
    print("Replaced Glow")

# 7. Add Support Developer Button to Sidebar
# Find the exact sidebar layout end in the backup
sidebar_end_pattern = r"(                }\n                \.frame\(width: 150\))"
support_button_ui = """                    Spacer()
                    
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
"""
if "Support Scribe" not in text:
    text = re.sub(sidebar_end_pattern, support_button_ui + r"\1", text)
    print("Added Support Button")

# 8. Add Support Modal sheet logic
sheet_pattern = r"(\.background\(Color\.primary\.opacity\(0\.02\)\))"
sheet_ui = """\1
                .sheet(isPresented: $showingSupportModal) {
                    SupportDeveloperModal()
                        .environmentObject(appState)
                }"""
if "isPresented: $showingSupportModal" not in text:
    text = re.sub(sheet_pattern, sheet_ui, text)
    print("Added Support Sheet")

# We also need to add the state variable for showingSupportModal if it's missing!
if "@State private var showingSupportModal = false" not in text:
    text = text.replace("@State private var selectedTab: SettingsTab = .general", "@State private var selectedTab: SettingsTab = .general\n    @State private var showingSupportModal = false")
    print("Added showingSupportModal state")


with open("Scribe/UI/SettingsView.swift", "w") as f:
    f.write(text)

print("Done")
