with open("Scribe/UI/SettingsView.swift") as f:
    lines = f.readlines()

new_lines = []
for i, line in enumerate(lines):
    if i == 451: # After line 451, we add 3 braces
        new_lines.append(line)
        new_lines.append("                    }\n")
        new_lines.append("                }\n")
        new_lines.append("            }\n")
        continue
    if "// Header — draggable to move the window" in line:
        new_lines.append("            } // End of HStack\n\n")
        new_lines.append(line)
        continue
    new_lines.append(line)

with open("Scribe/UI/SettingsView.swift", "w") as f:
    f.writelines(new_lines)
