import re

with open("Scribe/UI/SettingsView.swift", "r") as f:
    text = f.read()

# Fix Display Mode wrapping
old_display = """                                            Text(appState.l("Display Mode"))
                                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                                .foregroundStyle(.primary)"""
new_display = """                                            Text(appState.l("Display Mode"))
                                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                                .foregroundStyle(.primary)
                                                .fixedSize(horizontal: true, vertical: false)"""
text = text.replace(old_display, new_display)

with open("Scribe/UI/SettingsView.swift", "w") as f:
    f.write(text)

print("Fixed Display Mode wrapping")
