with open("Scribe/UI/SettingsView.swift", "r") as f:
    lines = f.read().split("\n")

# Extract the sections precisely based on HEAD line numbers
general_code = "\n".join(lines[21:148])
appearance_code = "\n".join(lines[148:234])
recognition_code = "\n".join(lines[234:306])
system_code = "\n".join(lines[309:394])

# Build the new SettingsTab enum
enum_code = """
enum SettingsTab: String, CaseIterable {
    case general = "General"
    case appearance = "Appearance"
    case recognition = "Recognition"
    case statistics = "Statistics"
    case replacements = "Replacements"
    case integrations = "Integrations"
    case system = "System"
}
"""

# We need to insert the enum right after imports
import_idx = 0
for i, line in enumerate(lines):
    if line.startswith("import KeyboardShortcuts"):
        import_idx = i
        break

lines.insert(import_idx + 1, enum_code)

# Now we need to insert `@State private var selectedTab: SettingsTab = .general`
# into `SettingsView` struct
struct_idx = 0
for i, line in enumerate(lines):
    if "struct SettingsView: View {" in line:
        struct_idx = i
        break

lines.insert(struct_idx + 2, "    @State private var selectedTab: SettingsTab = .general")

# Now we find the ZStack(alignment: .top) { which was at line 18 in HEAD (now shifted down)
zstack_idx = 0
for i, line in enumerate(lines):
    if "ZStack(alignment: .top) {" in line:
        zstack_idx = i
        break

# Find the end of ScrollView. It's marked by `.padding(.bottom, 24)` and then `}`
end_idx = 0
for i in range(zstack_idx, len(lines)):
    if ".padding(.bottom, 24)" in lines[i]:
        end_idx = i + 1  # the closing brace
        break

# The new sidebar + main content
new_body = f"""        ZStack(alignment: .top) {{
            HStack(spacing: 0) {{
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

# Replace the old lines with new_body
lines = lines[:zstack_idx] + [new_body] + lines[end_idx+1:]

text = "\n".join(lines)

# Fix Dynamic width
text = text.replace(".frame(width: 440, height: 620)", 
                    ".frame(width: (selectedTab == .statistics || selectedTab == .replacements || selectedTab == .integrations) ? 600 : 440, height: 620)")

with open("Scribe/UI/SettingsView.swift", "w") as f:
    f.write(text)

print("Rewrote SettingsView successfully.")
