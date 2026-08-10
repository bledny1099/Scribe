import re

with open("Scribe/UI/SettingsView.swift", "r") as f:
    text = f.read()

# Replace add text replacement
old_add = r"appState\.addTextReplacement\(phrase: newPhrase, replacement: newReplacement\)"
new_add = r"appState.textReplacements.append(Replacement(id: UUID(), phrase: newPhrase, replacement: newReplacement))"
text = re.sub(old_add, new_add, text)

# Replace remove text replacement
old_remove = r"appState\.removeTextReplacement\(id: r\.id\)"
new_remove = r"appState.textReplacements.removeAll { $0.id == r.id }"
text = re.sub(old_remove, new_remove, text)

with open("Scribe/UI/SettingsView.swift", "w") as f:
    f.write(text)

print("Fixed ReplacementsSettingsView")
