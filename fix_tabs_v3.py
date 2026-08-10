with open("Scribe/UI/SettingsView.swift") as f:
    lines = f.readlines()

new_lines = []
for i, line in enumerate(lines):
    if "if selectedTab == .system {" in line:
        # Before .system starts, we need to close .recognition!
        # .recognition opened a VStack, a GlassSection, and the if statement.
        new_lines.append("                                }\n") # close VStack
        new_lines.append("                            }\n") # close GlassSection
        new_lines.append("                        }\n\n") # close if selectedTab == .recognition
        new_lines.append(line)
        continue
    
    if "SupportDeveloperModal()" in line:
        new_lines.append(line)
        continue
        
    # Line 451 is the closing brace of the .sheet modifier.
    if i == 451 and line.strip() == "}":
        new_lines.append(line)
        
        # Now close .system! (VStack, GlassSection, if statement)
        new_lines.append("                        }\n") # close VStack
        new_lines.append("                    }\n") # close GlassSection
        new_lines.append("                    }\n\n") # close if selectedTab == .system
        
        # Insert the missing tabs!
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
        continue
        
    if "// Header — draggable to move the window" in line:
        # Before the header, we need to close the HStack containing the sidebar and the ScrollView!
        new_lines.append("            } // End of HStack\n\n")
        new_lines.append(line)
        continue
        
    new_lines.append(line)

with open("Scribe/UI/SettingsView.swift", "w") as f:
    f.writelines(new_lines)
