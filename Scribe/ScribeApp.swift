import SwiftUI
import KeyboardShortcuts

@main
struct ScribeApp: App {
    @StateObject private var appState: AppState

    init() {
        let state = AppState()
        _appState = StateObject(wrappedValue: state)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            SettingsWindowManager.shared.showSettings(appState: state)
        }
    }

    var body: some Scene {
        // MARK: Menu Bar
        MenuBarExtra {
            LiquidGlassMenuBarView(appState: appState)
        } label: {
            Label("Scribe", systemImage: appState.isRecording ? "waveform" : "mic")
        }
        .menuBarExtraStyle(.window)

        // No native Settings scene — we use the custom SettingsWindowManager
    }
}

// MARK: - Liquid Glass Menu Bar Popover View
struct LiquidGlassMenuBarView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var history = TranscriptionHistory.shared
    @ObservedObject var authService = AuthService.shared
    
    private var theme: AppTheme { appState.selectedTheme }
    private var displayName: String {
        let clean = appState.userName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !clean.isEmpty { return clean }
        if let authName = authService.currentUser?.name.trimmingCharacters(in: .whitespacesAndNewlines), !authName.isEmpty {
            return authName
        }
        return "Alex"
    }

    var body: some View {
        VStack(spacing: 12) {
            // User Header Card
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(theme.accentGradient.opacity(0.2))
                        .frame(width: 36, height: 36)
                        .overlay(Circle().stroke(theme.accentGradient.opacity(0.4), lineWidth: 1))

                    Text(String(displayName.prefix(1)).uppercased())
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(theme.gradientColors.first!)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(displayName)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)

                        Text("PRO")
                            .font(.system(size: 9, weight: .heavy, design: .rounded))
                            .foregroundStyle(theme.gradientColors.first!)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(theme.gradientColors.first!.opacity(0.15))
                            .cornerRadius(6)
                    }

                    Text("LVL \(history.currentLevel) • \(history.currentLevelName)")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    SettingsWindowManager.shared.showSettings(appState: appState)
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(6)
                        .background(Circle().fill(Color.primary.opacity(0.06)))
                }
                .buttonStyle(.plain)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.primary.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )

            // Big Start/Stop Dictation Button
            Button {
                appState.toggleRecording()
            } label: {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(appState.isRecording ? Color.red : theme.gradientColors.first!)
                            .frame(width: 28, height: 28)

                        Image(systemName: appState.isRecording ? "stop.fill" : "mic.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(appState.isRecording ? appState.l("Stop Dictation") : appState.l("Start Dictation"))
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)

                        Text(appState.isRecording ? (appState.formattedDuration.isEmpty ? "Recording…" : appState.formattedDuration) : appState.l("Hotkey: ⌥S"))
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.8))
                    }

                    Spacer()

                    Image(systemName: appState.isRecording ? "waveform" : "arrow.right.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(appState.isRecording ? LinearGradient(colors: [Color.red, Color.orange], startPoint: .leading, endPoint: .trailing) : theme.accentGradient)
                )
                .shadow(color: (appState.isRecording ? Color.red : theme.glowColor).opacity(0.35), radius: 6, y: 3)
            }
            .buttonStyle(.plain)

            // Quick Actions List (Liquid Glass)
            VStack(spacing: 2) {
                // Language Selector
                Menu {
                    ForEach(supportedLanguages.filter { $0.id != "auto" }, id: \.id) { lang in
                        if let children = lang.children {
                            Menu(lang.name) {
                                ForEach(children, id: \.id) { child in
                                    Button {
                                        appState.singleDictationLanguage = child.id
                                    } label: {
                                        HStack {
                                            Text(child.name)
                                            if appState.singleDictationLanguage == child.id {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            }
                        } else {
                            Button {
                                appState.singleDictationLanguage = lang.id
                            } label: {
                                HStack {
                                    Text(lang.name)
                                    if appState.singleDictationLanguage == lang.id {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "globe")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(theme.gradientColors.first!)
                            .frame(width: 20)
                        Text(appState.l("Language"))
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(supportedLanguages.first(where: { $0.id == appState.singleDictationLanguage })?.name ?? appState.singleDictationLanguage)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .contentShape(Rectangle())
                }
                .menuStyle(.borderlessButton)

                Divider().opacity(0.3)

                // History / Notes
                Button {
                    HistoryWindowManager.shared.showWindow(appState: appState)
                } label: {
                    HStack {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(theme.gradientColors.first!)
                            .frame(width: 20)
                        Text(appState.l("History & Statistics"))
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.primary)
                        Spacer()
                        Text("\(history.records.count)")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Divider().opacity(0.3)

                // Settings
                Button {
                    SettingsWindowManager.shared.showSettings(appState: appState)
                } label: {
                    HStack {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(theme.gradientColors.first!)
                            .frame(width: 20)
                        Text(appState.l("Settings…"))
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.primary)
                        Spacer()
                        Text("⌘,")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(4)
            .background(Color.primary.opacity(0.03))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            )

            // Footer
            HStack {
                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "power")
                            .font(.system(size: 11, weight: .semibold))
                        Text(appState.l("Quit Scribe"))
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                    }
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Spacer()

                Text("v1.0.0")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 4)
            .padding(.top, 2)
        }
        .padding(14)
        .frame(width: 280)
        .background(.ultraThinMaterial)
    }
}
