import re

with open("Scribe/ScribeApp.swift", "r") as f:
    text = f.read()

# Let's forcefully show the Settings and Permissions windows
old_init = """    @StateObject private var appState = AppState()"""
new_init = """    @StateObject private var appState = AppState()

    init() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let state = AppState()
            PermissionWindowManager.shared.showWindow(appState: state)
            SettingsWindowManager.shared.showSettings(appState: state)
        }
    }"""

text = text.replace(old_init, new_init)

with open("Scribe/ScribeApp.swift", "w") as f:
    f.write(text)

print("Patched ScribeApp to auto-show windows")
