with open("Scribe/UI/SettingsView.swift") as f:
    content = f.read()

integrations_code = """
// MARK: - Integrations Settings View
struct IntegrationsSettingsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        GlassSection(title: appState.l("Integrations"), icon: "link") {
            VStack(alignment: .leading, spacing: 16) {
                Text(appState.l("Select note apps to export to automatically:"))
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.8))

                HStack {
                    Text(appState.l("Target App"))
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.primary)
                    Spacer()
                    Picker("", selection: $appState.targetNoteApp) {
                        ForEach(NoteApp.allCases) { app in
                            Text(appState.l(app.displayName)).tag(app)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 150)
                }

                if appState.targetNoteApp == .obsidian {
                    Divider().background(Color.white.opacity(0.1))
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(appState.l("Obsidian Vault"))
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                            if let vaultURL = appState.obsidianVaultURL, !vaultURL.isEmpty, let url = URL(string: vaultURL) {
                                Text(url.lastPathComponent)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            } else {
                                Text(appState.l("Not Selected"))
                                    .font(.system(size: 12))
                                    .foregroundStyle(.red.opacity(0.8))
                            }
                        }
                        Spacer()
                        Button(appState.l("Select Folder")) {
                            selectObsidianVault(appState: appState)
                        }
                        .buttonStyle(ModernGlassButtonStyle())
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }

    private func selectObsidianVault(appState: AppState) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = appState.l("Select your Obsidian Vault folder")
        
        if panel.runModal() == .OK, let url = panel.url {
            appState.obsidianVaultURL = url.absoluteString
        }
    }
}
"""

if "struct IntegrationsSettingsView" not in content:
    content += "\n" + integrations_code

with open("Scribe/UI/SettingsView.swift", "w") as f:
    f.write(content)
