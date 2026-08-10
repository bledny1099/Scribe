import re
import shutil

# Step 1: Start from the original
shutil.copy("Scribe/UI/SettingsView.swift.orig", "Scribe/UI/SettingsView.swift")

# Step 2: Extract the structs we need from the CURRENT file
with open("diff_settings.txt", "r") as f:
    diff_text = f.read()

# I will just write the appended structs manually
appended_structs = """
// MARK: - Integrations Settings View
struct IntegrationsSettingsView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        GlassSection(title: appState.l("Integrations"), icon: "link") {
            VStack(alignment: .leading, spacing: 16) {
                // Obsidian Integration
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Obsidian")
                            .font(.system(size: 14, weight: .bold))
                        Text(appState.obsidianVaultURL.isEmpty ? "Not configured" : appState.obsidianVaultURL)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $appState.obsidianIntegrationEnabled)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }
                
                if appState.obsidianIntegrationEnabled {
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
                    Toggle("", isOn: $appState.appleNotesIntegrationEnabled)
                        .toggleStyle(.switch)
                        .labelsHidden()
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
                    Toggle("", isOn: $appState.notionIntegrationEnabled)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }
            }
            .padding(14)
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
                    TextField("Original phrase", text: $newPhrase)
                        .textFieldStyle(.roundedBorder)
                    Image(systemName: "arrow.right")
                        .foregroundColor(.secondary)
                    TextField("Replacement", text: $newReplacement)
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
"""

with open("Scribe/UI/SettingsView.swift", "a") as f:
    f.write(appended_structs)

# Step 3: Insert them into the body ScrollView
with open("Scribe/UI/SettingsView.swift", "r") as f:
    text = f.read()

insertion_target = """                    // SECTION: Statistics
                    StatisticsSectionView()"""
                    
new_insertion = """                    // SECTION: Statistics
                    StatisticsSectionView()

                    // SECTION: Replacements
                    ReplacementsSettingsView()

                    // SECTION: Integrations
                    IntegrationsSettingsView()"""

text = text.replace(insertion_target, new_insertion)

# Step 4: Fix StatisticsSectionView Level and XP bar!
stats_target = """                    StatCard(
                        title: appState.l("Sessions"),
                        value: formatNumber(stats.sessionsCount),
                        icon: "rectangle.stack",
                        color: .green
                    )
                }
            }
        }
    }
}"""

stats_replacement = """                    StatCard(
                        title: appState.l("Sessions"),
                        value: formatNumber(stats.sessionsCount),
                        icon: "rectangle.stack",
                        color: .green
                    )
                }

                // Level and XP
                VStack(spacing: 8) {
                    HStack {
                        Text("\\(history.currentLevelName) - Level \\(history.currentLevel)")
                            .font(.system(size: 16, weight: .bold))
                            .shadow(color: history.currentLevelColor.opacity(0.8), radius: 8, x: 0, y: 0)
                        Spacer()
                        Text("\\(history.totalWords) / \\(history.totalWords + history.wordsToNextLevel) Words")
                            .font(.system(size: 13, weight: .medium))
                            .shadow(color: history.currentLevelColor.opacity(0.8), radius: 8, x: 0, y: 0)
                    }
                    
                    // Smooth glow progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.primary.opacity(0.1))
                            
                            RoundedRectangle(cornerRadius: 8)
                                .fill(
                                    LinearGradient(colors: [history.currentLevelColor, history.currentLevelColor.opacity(0.5)], startPoint: .leading, endPoint: .trailing)
                                )
                                .frame(width: max(0, geo.size.width * CGFloat(history.currentLevelProgress)))
                                .shadow(color: history.currentLevelColor.opacity(0.6), radius: 6, x: 0, y: 0)
                        }
                    }
                    .frame(height: 12)
                }
                .padding()
                .background(Color.primary.opacity(0.05))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(history.currentLevelColor.opacity(0.3), lineWidth: 1)
                        .shadow(color: history.currentLevelColor.opacity(0.3), radius: 10, x: 0, y: 0)
                )
            }
        }
    }
}"""

text = text.replace(stats_target, stats_replacement)

with open("Scribe/UI/SettingsView.swift", "w") as f:
    f.write(text)

print("Reverted to original and injected new sections.")

# Also revert SettingsWindowManager to original width / removing resize functionality
shutil.copy("Scribe/UI/SettingsWindowManager.swift", "Scribe/UI/SettingsWindowManager.swift.bak")
