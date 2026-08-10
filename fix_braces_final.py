with open("Scribe/UI/SettingsView.swift") as f:
    lines = f.readlines()

new_lines = []
for i, line in enumerate(lines):
    if line.strip() == "}":
        if i == 472 or i == 473 or i == 474 or i == 475 or i == 476: # remove my mistakenly added braces from fix_braces3.py
            continue
    if i == 451: # At line 452, we add 3 braces
        new_lines.append(line)
        new_lines.append("                    }\n")
        new_lines.append("                }\n")
        new_lines.append("            }\n")
        continue
    if "Header — draggable to move the window" in line:
        new_lines.append("            } // End of HStack\n\n")
        new_lines.append(line)
        continue
    new_lines.append(line)

with open("Scribe/UI/SettingsView.swift", "w") as f:
    f.writelines(new_lines)
