import re

# 1. AppState: Fix Preview Position and Add Vocabulary
with open("Scribe/AppState.swift", "r") as f:
    app_state = f.read()

# Add Vocabulary
if "var vocabulary:" not in app_state:
    app_state = app_state.replace('@AppStorage("notionPageId") var notionPageId: String = ""',
                                  '@AppStorage("notionPageId") var notionPageId: String = ""\n    @AppStorage("vocabulary") var vocabulary: String = ""')

# Fix targetPreviewOrigin
preview_pos_old = """        if let settingsFrame = SettingsWindowManager.shared.windowFrame ?? PermissionWindowManager.shared.windowFrame {
            // ALWAYS put on the right side of the window
            let preferredX = settingsFrame.maxX + 20
            let maxAllowedX = screenFrame.maxX - size.width - 20
            let x = min(preferredX, maxAllowedX)
            let preferredY = settingsFrame.midY - size.height / 2
            let y = max(screenFrame.minY + 20, min(preferredY, screenFrame.maxY - size.height - 20))
            return NSPoint(x: x, y: y)
        }"""
preview_pos_new = """        if let settingsFrame = SettingsWindowManager.shared.windowFrame ?? PermissionWindowManager.shared.windowFrame {
            // Put below the window, centered
            let preferredX = settingsFrame.midX - size.width / 2
            let maxAllowedX = screenFrame.maxX - size.width - 20
            let x = max(screenFrame.minX + 20, min(preferredX, maxAllowedX))
            let preferredY = settingsFrame.minY - size.height - 20
            let y = max(screenFrame.minY + 20, preferredY)
            return NSPoint(x: x, y: y)
        }"""
app_state = app_state.replace(preview_pos_old, preview_pos_new)

with open("Scribe/AppState.swift", "w") as f:
    f.write(app_state)


# 2. SettingsView changes
with open("Scribe/UI/SettingsView.swift", "r") as f:
    settings = f.read()

# Remove Common Export Settings from Integrations
export_settings_pattern = r"                Divider\(\)\n                \n                // Common Export Settings.*?\n                }\n"
settings = re.sub(export_settings_pattern, "", settings, flags=re.DOTALL)

# Add Vocabulary Tab to Enum
if 'case vocabulary = "Vocabulary"' not in settings:
    settings = settings.replace('case system = "System"', 'case vocabulary = "Vocabulary"\n    case system = "System"')

# Add Vocabulary Tab logic
vocab_ui = """                        case .vocabulary:
                    GlassSection(title: appState.l("Vocabulary"), icon: "text.book.closed.fill") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(appState.l("Add custom words, names, or acronyms to help Scribe recognize them correctly. Separate words with commas."))
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                            
                            TextEditor(text: $appState.vocabulary)
                                .font(.system(size: 14))
                                .frame(height: 120)
                                .padding(8)
                                .background(Color.primary.opacity(0.04))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                                )
                        }
                        .padding(14)
                    }
"""
if 'case .vocabulary:' not in settings:
    settings = settings.replace('case .system:', vocab_ui + '                        case .system:')


# Move Sound Feedback in Appearance under Theme picker
# It's currently in Appearance. Let's find it.
sound_feedback_ui = """
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(appState.l("Sound Feedback"))
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundStyle(.primary)
                        }
                        Spacer()
                        Toggle("", isOn: $appState.soundEnabled)
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }
"""
settings = settings.replace(sound_feedback_ui, "") # remove it from current location

# insert it under theme picker
theme_picker_pattern = r"(\s*\}\n\s*\}\n\s*\.padding\(14\)\n\s*\}\n\s*// SECTION: Recording Panel)"
settings = re.sub(theme_picker_pattern, sound_feedback_ui + r"\1", settings)


with open("Scribe/UI/SettingsView.swift", "w") as f:
    f.write(settings)

print("Basic changes applied!")
