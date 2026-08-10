import re

with open("Scribe/UI/SettingsView.swift") as f:
    lines = f.readlines()

new_lines = []
for line in lines:
    if line.strip() == "// Header — draggable to move the window":
        new_lines.append("            } // End of HStack\n\n")
    new_lines.append(line)
    if "appState.onThemeChangedPreview()" in line:
        # We know ZStack ends around here
        pass

with open("Scribe/UI/SettingsView.swift", "w") as f:
    f.writelines(new_lines)
