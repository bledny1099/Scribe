import SwiftUI
import KeyboardShortcuts
import UniformTypeIdentifiers

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
                .environmentObject(appState)
        } label: {
            if appState.isLectureRecording {
                HStack(spacing: 4) {
                    Image(systemName: "record.circle.fill")
                    Text(appState.formattedDuration.isEmpty ? "00:00" : appState.formattedDuration)
                }
            } else if appState.isImportTranscribing {
                HStack(spacing: 4) {
                    Image(systemName: "waveform.badge.magnifyingglass")
                    Text("Обработка…")
                }
            } else {
                Label("Scribe", systemImage: appState.isRecording ? "waveform" : "mic")
            }
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
    @State private var isTargetedForDrop: Bool = false
    
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

            // MARK: - Active Lecture Recording Card
            if appState.isLectureRecording {
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                        Text(appState.l("Запись лекции (без оверлея)"))
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(appState.formattedDuration.isEmpty ? "00:00" : appState.formattedDuration)
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundStyle(.red)
                    }

                    HStack(spacing: 8) {
                        Button {
                            appState.stopLectureRecording()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "stop.fill")
                                    .font(.system(size: 11))
                                Text(appState.l("Остановить и в Заметки"))
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.red.opacity(0.15))
                            .foregroundStyle(Color.red)
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)

                        Button {
                            appState.cancelRecording()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 11, weight: .bold))
                                .padding(8)
                                .background(Color.primary.opacity(0.06))
                                .foregroundStyle(.secondary)
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        .help(appState.l("Отменить запись"))
                    }
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.red.opacity(0.06)))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.red.opacity(0.25), lineWidth: 1))
            } else if appState.isImportTranscribing {
                // MARK: - File Import Progress Card
                HStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(appState.l("Транскрибация файла"))
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary)
                        Text(appState.importProgressMessage)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.blue.opacity(0.06)))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.blue.opacity(0.20), lineWidth: 1))
            } else {
                // MARK: - Start / Stop Dictation Button
                Button {
                    appState.toggleRecording()
                } label: {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(appState.isRecording ? Color.red.opacity(0.18) : Color.primary.opacity(0.08))
                                .frame(width: 36, height: 36)

                            Image(systemName: appState.isRecording ? "stop.fill" : "mic.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(appState.isRecording ? Color.red : Color.primary)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(appState.isRecording ? appState.l("Stop Dictation") : appState.l("Start Dictation"))
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(appState.isRecording ? Color.red : Color.primary)

                            Text(appState.isRecording ? (appState.formattedDuration.isEmpty ? "Recording…" : appState.formattedDuration) : appState.l("Hotkey: ⌥S"))
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundStyle(appState.isRecording ? Color.red.opacity(0.85) : Color.secondary)
                        }

                        Spacer()

                        Image(systemName: appState.isRecording ? "waveform" : "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(appState.isRecording ? Color.red : Color.secondary)
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(appState.isRecording ? Color.red.opacity(0.10) : Color.primary.opacity(0.04))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(appState.isRecording ? Color.red.opacity(0.30) : Color.primary.opacity(0.08), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

                // MARK: - Lecture Recording Action (Toolbar: Start/Stop only)
                if appState.showLectureControls && !appState.isLectureRecording {
                    Button {
                        appState.startLectureRecording()
                    } label: {
                        HStack(spacing: 7) {
                            Image(systemName: "mic.badge.plus")
                                .font(.system(size: 11.5, weight: .semibold))
                                .foregroundStyle(Color.indigo)
                            Text(appState.l("Start Lecture Recording"))
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "circle.fill")
                                .font(.system(size: 6))
                                .foregroundStyle(Color.indigo.opacity(0.6))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Color.primary.opacity(0.04))
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.06), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .help(appState.l("Record lecture in background without on-screen overlay and save to Notes"))
                }

                // MARK: - Quick AI Post-Processing Toggle Card
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        appState.enableCloudAI.toggle()
                    }
                } label: {
                    HStack(spacing: 8) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 7)
                                .fill(appState.enableCloudAI ? Color.purple.opacity(0.20) : Color.primary.opacity(0.06))
                                .frame(width: 24, height: 24)
                            Image(systemName: "sparkles")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(appState.enableCloudAI ? Color.purple : Color.secondary)
                        }

                        VStack(alignment: .leading, spacing: 1) {
                            HStack(spacing: 4) {
                                Text(appState.l("AI-обработка (Claude)"))
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.primary)
                                if appState.enableCloudAI {
                                    Text("ON")
                                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                                        .foregroundStyle(Color.purple)
                                }
                            }
                            Text(appState.enableCloudAI ? appState.l("Активно: пунктуация, грамматика, чистка пауз") : appState.l("Выключено: чистый Whisper"))
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Toggle("", isOn: $appState.enableCloudAI)
                            .toggleStyle(.switch)
                            .controlSize(.mini)
                            .labelsHidden()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(appState.enableCloudAI ? Color.purple.opacity(0.06) : Color.primary.opacity(0.03))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(appState.enableCloudAI ? Color.purple.opacity(0.25) : Color.primary.opacity(0.06), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .help(appState.l("Быстрое переключение AI-обработки текста"))
            }

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
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isTargetedForDrop ? Color.blue : Color.clear, lineWidth: 2)
                )
        )
        .onDrop(of: [.fileURL], isTargeted: $isTargetedForDrop) { providers in
            guard let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let fileURL = url, AudioFileImporter.isSupportedFile(url: fileURL) else { return }
                DispatchQueue.main.async {
                    appState.importAndTranscribeLecture(url: fileURL)
                }
            }
            return true
        }
    }
}
