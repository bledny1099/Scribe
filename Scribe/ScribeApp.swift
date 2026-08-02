import SwiftUI
import KeyboardShortcuts

@main
struct ScribeApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        // MARK: Menu Bar
        MenuBarExtra {
            ScribeMenuView(appState: appState)
        } label: {
            Label("Scribe", systemImage: appState.isRecording ? "waveform" : "mic")
        }
        .menuBarExtraStyle(.menu)

        // No native Settings scene — we use the custom SettingsWindowManager
    }
}

struct ScribeMenuView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        Button(appState.isRecording ? appState.l("Stop Dictation") : appState.l("Start Dictation")) {
            appState.toggleRecording()
        }

        Divider()

        if appState.isTranscribing {
            Button(appState.l("Transcribing…")) {}
                .disabled(true)
        }

        Button(appState.l("Hotkey: ⌥S")) {}
            .disabled(true)

        Divider()

        Button(appState.l("Settings…")) {
            SettingsWindowManager.shared.showSettings(appState: appState)
        }
        .keyboardShortcut(",")

        Divider()

        Menu(appState.l("Dictation Language")) {
            ForEach(supportedLanguages, id: \.id) { lang in
                if let children = lang.children {
                    Menu(lang.name) {
                        ForEach(children, id: \.id) { child in
                            Button {
                                appState.selectedLanguage = child.id
                            } label: {
                                HStack {
                                    Text(child.name)
                                    if appState.selectedLanguage == child.id {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    }
                } else {
                    Button {
                        appState.selectedLanguage = lang.id
                    } label: {
                        HStack {
                            Text(lang.name)
                            if appState.selectedLanguage == lang.id {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
        }

        Divider()

        Button(appState.l("Quit Scribe")) {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
