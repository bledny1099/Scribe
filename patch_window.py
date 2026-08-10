import re

with open("Scribe/UI/SettingsWindowManager.swift", "r") as f:
    text = f.read()

# Change initial width to 440
text = text.replace("width: 850, height: 620", "width: 440, height: 620")

# Add resize method
new_method = """    var windowFrame: NSRect? {
        window?.frame
    }

    func resizeWindow(to width: CGFloat) {
        guard let window = window else { return }
        var frame = window.frame
        let diff = width - frame.size.width
        frame.size.width = width
        frame.origin.x -= diff / 2 // Keep it centered
        window.setFrame(frame, display: true, animate: true)
    }"""
text = text.replace("    var windowFrame: NSRect? {\n        window?.frame\n    }", new_method)

with open("Scribe/UI/SettingsWindowManager.swift", "w") as f:
    f.write(text)

with open("Scribe/UI/SettingsView.swift", "r") as f:
    text = f.read()

# Remove the static .frame(width: ...) from SettingsView body 
# and add .onChange
old_frame = ".frame(width: (selectedTab == .statistics || selectedTab == .replacements || selectedTab == .integrations) ? 600 : 440, height: 620)"
new_frame = """        .onChange(of: selectedTab) { newValue in
            let newWidth: CGFloat = (newValue == .statistics || newValue == .replacements || newValue == .integrations) ? 620 : 440
            SettingsWindowManager.shared.resizeWindow(to: newWidth)
        }"""
text = text.replace(old_frame, new_frame)

with open("Scribe/UI/SettingsView.swift", "w") as f:
    f.write(text)

print("Patched dynamic window resizing")
