with open("Scribe/UI/SettingsView.swift") as f:
    lines = f.readlines()

new_lines = []
for i, line in enumerate(lines):
    if line.strip() == "// Header — draggable to move the window":
        new_lines.append("                    }\n                }\n            }\n        }\n    }\n")
    new_lines.append(line)

with open("Scribe/UI/SettingsView.swift", "w") as f:
    f.writelines(new_lines)
