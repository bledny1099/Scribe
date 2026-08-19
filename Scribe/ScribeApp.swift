import SwiftUI
import KeyboardShortcuts

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}

@main
struct ScribeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState: AppState

    init() {
        let state = AppState()
        _appState = StateObject(wrappedValue: state)
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
    @ObservedObject var updateService = AppUpdateService.shared
    
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
        VStack(spacing: 10) {
            // User Header Card
            HStack(spacing: 10) {
                // Clicking avatar / name / level opens Statistics & Gamification
                Button {
                    SettingsWindowManager.shared.showSettings(appState: appState, tab: .statistics)
                } label: {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(history.currentLevelColor.opacity(0.18))
                                .frame(width: 36, height: 36)
                                .overlay(Circle().stroke(history.currentLevelColor.opacity(0.35), lineWidth: 1))

                            Text(String(displayName.prefix(1)).uppercased())
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(history.currentLevelColor)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(displayName)
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.primary)
                                .lineLimit(1)

                            Text("LVL \(history.currentLevel) • \(appState.l(history.currentLevelName))")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(history.currentLevelColor)
                                .lineLimit(1)
                        }
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                // Settings Gear Button on the right
                Button {
                    SettingsWindowManager.shared.showSettings(appState: appState, tab: .general)
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.secondary)
                        .padding(7)
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

            // Start / Stop Dictation Button
            Button {
                appState.toggleRecording()
            } label: {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(appState.isRecording ? Color.red.opacity(0.2) : Color.primary.opacity(0.1))
                            .frame(width: 32, height: 32)

                        Image(systemName: appState.isRecording ? "stop.fill" : "mic.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(appState.isRecording ? Color.red : Color.primary)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(appState.isRecording ? appState.l("Stop Dictation") : appState.l("Start Dictation"))
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(appState.isRecording ? Color.red : Color.primary)

                        Text(appState.isRecording ? (appState.formattedDuration.isEmpty ? "Recording…" : appState.formattedDuration) : appState.l("Hotkey: ⌥S"))
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(appState.isRecording ? Color.red.opacity(0.85) : Color.secondary)
                    }

                    Spacer()

                    Image(systemName: appState.isRecording ? "waveform" : "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(appState.isRecording ? Color.red : Color.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(appState.isRecording ? Color.red.opacity(0.12) : Color.primary.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(appState.isRecording ? Color.red.opacity(0.35) : Color.primary.opacity(0.12), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            // Footer
            HStack(spacing: 8) {
                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "power")
                            .font(.system(size: 11, weight: .semibold))
                        if !updateService.updateAvailable {
                            Text(appState.l("Quit Scribe"))
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                        }
                    }
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help(appState.l("Quit Scribe"))

                Spacer()

                if updateService.updateAvailable {
                    Button(action: {
                        updateService.performUpdate()
                    }) {
                        HStack(spacing: 4) {
                            if updateService.isDownloading {
                                ProgressView()
                                    .controlSize(.mini)
                                    .frame(width: 10, height: 10)
                            } else {
                                Image(systemName: "arrow.down.circle.fill")
                                    .font(.system(size: 8.5, weight: .bold))
                            }
                            Text(updateService.isDownloading ? appState.l("Updating...") : appState.l("Update available"))
                                .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                                .lineLimit(1)
                                .fixedSize()
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2.5)
                        .background(Color.green.opacity(0.18))
                        .foregroundStyle(.green)
                        .cornerRadius(5)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(Color.green.opacity(0.35), lineWidth: 0.8)
                        )
                    }
                    .buttonStyle(.plain)
                }

                Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "2.3.0")")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 4)
            .padding(.top, 2)
        }
        .padding(12)
        .frame(width: 290)
        .background(.ultraThinMaterial)
    }
}
