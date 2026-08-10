with open("Scribe/UI/SettingsView.swift") as f:
    lines = f.readlines()

new_lines = []
inserted = False
for i, line in enumerate(lines):
    # Line 452 is `                }` just before `.padding(.horizontal, 24)`
    if i == 451 and line.strip() == "}":
        new_lines.append("""
                        if selectedTab == .statistics {
                            StatisticsSectionView()
                        }
                        if selectedTab == .replacements {
                            ReplacementsSettingsView()
                        }
                        if selectedTab == .integrations {
                            IntegrationsSettingsView()
                        }
""")
        new_lines.append(line)
        inserted = True
        continue
    new_lines.append(line)

with open("Scribe/UI/SettingsView.swift", "w") as f:
    f.writelines(new_lines)
