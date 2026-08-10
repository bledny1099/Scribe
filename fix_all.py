import re

with open("Scribe/UI/SettingsView.swift", "r") as f:
    text = f.read()

# Fix window size on open
old_onchange = """        .onChange(of: selectedTab) { newValue in
            let newWidth: CGFloat = (newValue == .statistics || newValue == .replacements || newValue == .integrations) ? 620 : 440
            SettingsWindowManager.shared.resizeWindow(to: newWidth)
        }"""
new_onchange = """        .onAppear {
            let newWidth: CGFloat = (selectedTab == .statistics || selectedTab == .replacements || selectedTab == .integrations) ? 620 : 440
            SettingsWindowManager.shared.resizeWindow(to: newWidth)
        }
        .onChange(of: selectedTab) { newValue in
            let newWidth: CGFloat = (newValue == .statistics || newValue == .replacements || newValue == .integrations) ? 620 : 440
            SettingsWindowManager.shared.resizeWindow(to: newWidth)
        }"""

text = text.replace(old_onchange, new_onchange)

with open("Scribe/UI/SettingsView.swift", "w") as f:
    f.write(text)

with open("Scribe/UI/PermissionView.swift", "r") as f:
    perm_text = f.read()

# Inject dummy AudioRecorder in PermissionWelcomeView
old_state = """    @State private var task: SFSpeechRecognitionTask?

    
    var onComplete: (() -> Void)? = nil"""
new_state = """    @State private var task: SFSpeechRecognitionTask?
    @StateObject private var previewRecorder = AudioRecorder()

    
    var onComplete: (() -> Void)? = nil"""
perm_text = perm_text.replace(old_state, new_state)

# Add RecordingOverlayView preview in customization step
old_customization = """                                    LiquidGlassSegmentedPicker(
                                        items: OverlayStyle.allCases,
                                        selection: Binding(
                                            get: { appState.selectedOverlayStyle },
                                            set: { appState.selectedOverlayStyle = $0; appState.showSettingsPreviewFor5Seconds() }
                                        ),
                                        label: { ("", $0.icon) }
                                    )
                                }
                            }
                        }"""
new_customization = """                                    LiquidGlassSegmentedPicker(
                                        items: OverlayStyle.allCases,
                                        selection: Binding(
                                            get: { appState.selectedOverlayStyle },
                                            set: { appState.selectedOverlayStyle = $0; appState.showSettingsPreviewFor5Seconds() }
                                        ),
                                        label: { ("", $0.icon) }
                                    )
                                }
                                
                                // Embedded Preview
                                VStack {
                                    Text("Live Preview")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(.secondary)
                                        .padding(.top, 10)
                                        
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(Color.primary.opacity(0.02))
                                            .frame(height: 140)
                                            
                                        RecordingOverlayView()
                                            .environmentObject(appState)
                                            .environmentObject(previewRecorder)
                                            .scaleEffect(0.6)
                                    }
                                }
                            }
                        }"""
perm_text = perm_text.replace(old_customization, new_customization)

with open("Scribe/UI/PermissionView.swift", "w") as f:
    f.write(perm_text)

print("Fixes applied.")
