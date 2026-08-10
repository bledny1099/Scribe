with open("Scribe/UI/SettingsView.swift") as f:
    lines = f.readlines()

new_lines = []
for i, line in enumerate(lines):
    if i == 451: # line 452
        new_lines.append("                    }\n                }\n            }\n")
    else:
        new_lines.append(line)

with open("Scribe/UI/SettingsView.swift", "w") as f:
    f.writelines(new_lines)
