import re

with open("Scribe/UI/SettingsView.swift", "r") as f:
    text = f.read()

general_pattern = r"(if selectedTab == \.general \{.*?)if selectedTab == \.appearance \{"
general_match = re.search(general_pattern, text, re.DOTALL)
general_code = general_match.group(1).strip() if general_match else ""

appearance_pattern = r"(if selectedTab == \.appearance \{.*?)if selectedTab == \.recognition \{"
appearance_match = re.search(appearance_pattern, text, re.DOTALL)
appearance_code = appearance_match.group(1).strip() if appearance_match else ""

recognition_pattern = r"(if selectedTab == \.recognition \{.*?)\n\s*if selectedTab == \.system \{"
recognition_match = re.search(recognition_pattern, text, re.DOTALL)
recognition_code = recognition_match.group(1).strip() if recognition_match else ""

system_pattern = r"(if selectedTab == \.system \{.*?SupportDeveloperModal\(\)\s*\.environmentObject\(appState\)\s*\})"
system_match = re.search(system_pattern, text, re.DOTALL)
system_code = system_match.group(1).strip() if system_match else ""

if all([general_code, appearance_code, recognition_code, system_code]):
    new_scrollview = f"""                ScrollView(.vertical, showsIndicators: true) {{
                    VStack(spacing: 20) {{
                        {general_code}
                        
                        {appearance_code}
                        
                        {recognition_code}
                                }} // End VStack
                            }} // End GlassSection
                        }} // End if recognition
                        
                        {system_code}
                            }} // End .sheet
                        }} // End if system
                        
                        if selectedTab == .statistics {{
                            StatisticsSectionView()
                        }}
                        if selectedTab == .replacements {{
                            ReplacementsSettingsView()
                        }}
                        if selectedTab == .integrations {{
                            IntegrationsSettingsView()
                        }}
                    }}
                    .padding(.horizontal, 24)
                    .padding(.top, 116)
                    .padding(.bottom, 24)
                }}"""

    replace_pattern = r"ScrollView\(\.vertical, showsIndicators: true\) \{.*\.padding\(\.bottom, 24\)\n\s*\}"
    new_text = re.sub(replace_pattern, new_scrollview, text, flags=re.DOTALL)
    
    with open("Scribe/UI/SettingsView.swift", "w") as f:
        f.write(new_text)
    
    print("Replaced successfully.")
