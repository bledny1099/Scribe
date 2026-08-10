import re

with open("Scribe/UI/SettingsView.swift", "r") as f:
    text = f.read()

# 1. Update IntegrationsSettingsView
integrations_old_pattern = r"struct IntegrationsSettingsView: View \{.*?\n\}\n"
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

# 2. Add Push-to-Talk to General
general_pattern = r"(HStack \{\n\s+Text\(appState\.l\(\"Auto-paste\"\)\))"
push_to_talk_ui = """HStack {
                    Text(appState.l("Hold to Dictate"))
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.primary)
                    Spacer()
                    Toggle("", isOn: $appState.holdToDictateEnabled)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }
                
                """
text = re.sub(general_pattern, push_to_talk_ui + r"\1", text)
print("Added Push-to-talk to General")

# 3. Move Sound Feedback to Appearance
sound_feedback = """                // Sound feedback
                HStack {
                    Text(appState.l("Sound Feedback"))
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.primary)
                    Spacer()
                    Toggle("", isOn: $appState.soundFeedbackEnabled)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }"""
text = text.replace(sound_feedback, "") # Remove from systemSettings

appearance_pattern = r"(VStack\(alignment: \.leading, spacing: 16\) \{\n\s+// Theme Selection)"
sound_feedback_ui = """                // Sound feedback
                HStack {
                    Text(appState.l("Sound Feedback"))
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.primary)
                    Spacer()
                    Toggle("", isOn: $appState.soundFeedbackEnabled)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }
                
"""
text = re.sub(appearance_pattern, r"\1\n" + sound_feedback_ui, text)
print("Moved Sound Feedback to Appearance")

# 4. Revert StatisticsSectionView to original without Gamification
stats_pattern = r"// Gamification: Level & Time Saved.*?\.cornerRadius\(12\)"
text = re.sub(stats_pattern, "", text, flags=re.DOTALL)
print("Reverted Stats to original design")

with open("Scribe/UI/SettingsView.swift", "w") as f:
    f.write(text)
