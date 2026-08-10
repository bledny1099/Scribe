import re

with open("Scribe/UI/SettingsView.swift", "r") as f:
    text = f.read()

# Add SettingsTab enum at the top (after import SwiftUI)
if "enum SettingsTab" not in text:
    text = re.sub(r"import KeyboardShortcuts", 
                  "import KeyboardShortcuts\n\nenum SettingsTab: String, CaseIterable {\n    case general = \"General\"\n    case appearance = \"Appearance\"\n    case recognition = \"Recognition\"\n    case statistics = \"Statistics\"\n    case replacements = \"Replacements\"\n    case integrations = \"Integrations\"\n    case system = \"System\"\n}\n", 
                  text)

# Add selectedTab state variable inside SettingsView
if "@State private var selectedTab" not in text:
    text = re.sub(r"struct SettingsView: View \{\n\n    @EnvironmentObject var appState: AppState",
                  "struct SettingsView: View {\n\n    @EnvironmentObject var appState: AppState\n    @State private var selectedTab: SettingsTab = .general",
                  text)

# Extract sections
# General: lines 22-148
general_code = "\n".join(text.split("\n")[21:148])
# Appearance: lines 149-234
appearance_code = "\n".join(text.split("\n")[148:234])
# Recognition: lines 235-306
recognition_code = "\n".join(text.split("\n")[234:306])
# System: lines 310-394
system_code = "\n".join(text.split("\n")[309:394])

# Build the new UI structure
new_ui = f"""            HStack(spacing: 0) {{
                // Sidebar
                VStack(alignment: .leading, spacing: 4) {{
                    ForEach(SettingsTab.allCases, id: \\.self) {{ tab in
                        Button(action: {{
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {{
                                selectedTab = tab
                            }}
                        }}) {{
                            HStack {{
                                Text(appState.l(tab.rawValue))
                                    .font(.system(size: 13, weight: selectedTab == tab ? .bold : .medium, design: .rounded))
                                Spacer()
                            }}
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(selectedTab == tab ? Color.primary.opacity(0.1) : Color.clear)
                            .cornerRadius(8)
                        }}
                        .buttonStyle(.plain)
                    }}
                    Spacer()
                }}
                .frame(width: 150)
                .padding(.top, 116)
                .padding(.horizontal, 12)
                .background(Color.primary.opacity(0.02))

                Divider()

                // Main Content
                ScrollView(.vertical, showsIndicators: true) {{
                    VStack(spacing: 20) {{
                        switch selectedTab {{
                        case .general:
{general_code}
                        case .appearance:
{appearance_code}
                        case .recognition:
{recognition_code}
                        case .statistics:
                            StatisticsSectionView()
                        case .replacements:
                            ReplacementsSettingsView()
                        case .integrations:
                            IntegrationsSettingsView()
                        case .system:
{system_code}
                        }}
                    }}
                    .padding(.horizontal, 24)
                    .padding(.top, 116)
                    .padding(.bottom, 24)
                }}
            }}"""

# Replace the original ScrollView with the new Sidebar + ScrollView layout
# We match from `ScrollView(.vertical, showsIndicators: false) {` down to line 399 `}`
# Note: Original ScrollView was `showsIndicators: false` in my `view_file` output (line 20)
# But wait, earlier I saw `showsIndicators: true`? 
# Ah, line 20: `ScrollView(.vertical, showsIndicators: false) {`

# Let's use regex to replace from ScrollView to the closing brace before .mask
replace_pattern = r"ScrollView\(\.vertical, showsIndicators: false\) \{.*?\.padding\(\.bottom, 24\)\n\s*\}"
text = re.sub(replace_pattern, new_ui, text, flags=re.DOTALL)

# Dynamic width
text = text.replace(".frame(width: 440, height: 620)", ".frame(width: 600, height: 620)")

with open("Scribe/UI/SettingsView.swift", "w") as f:
    f.write(text)

print("Patch applied.")
