import re

with open('/Users/aleksei/Documents/Scribe/Scribe/UI/SettingsView.swift', 'r') as f:
    content = f.read()

# 1. Add SettingsTab enum and selectedTab
enum_str = """    enum SettingsTab: String, CaseIterable, Identifiable {
        case general = "General"
        case appearance = "Appearance"
        case recognition = "Recognition"
        case statistics = "Statistics"
        case system = "System"
        
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .general: return "keyboard"
            case .appearance: return "paintbrush.fill"
            case .recognition: return "waveform.and.mic"
            case .statistics: return "chart.bar.fill"
            case .system: return "lock.shield"
            }
        }
    }

    @EnvironmentObject var appState: AppState
    @State private var showingSupportModal = false
    @State private var selectedTab: SettingsTab = .general
"""
content = content.replace('    @EnvironmentObject var appState: AppState\n    @State private var showingSupportModal = false\n', enum_str)

# 2. Remove FPS Slider
fps_regex = re.compile(r'(\s*// FPS Slider\s*VStack\(alignment: \.leading, spacing: 8\) \{.*?Slider\(value: \$appState\.visualizerFPS, in: 5\.\.\.60, step: 5\)\s*\.tint\(.*?\)\s*\})', re.DOTALL)
content = fps_regex.sub(r'                                    // FPS Slider removed', content)

# 3. Modify frame sizes (modal and settings frame)
content = content.replace('.frame(width: 440, height: 820)', '.frame(width: 600, height: 620)')

# 4. Implement Sidebar
sidebar_str = """        ZStack(alignment: .top) {
            HStack(spacing: 0) {
                // SIDEBAR
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(SettingsTab.allCases) { tab in
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedTab = tab
                            }
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: tab.icon)
                                    .font(.system(size: 14))
                                    .frame(width: 20)
                                Text(appState.l(tab.rawValue))
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                Spacer(minLength: 0)
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(selectedTab == tab ? (appState.selectedTheme.gradientColors.first ?? .accentColor).opacity(0.15) : Color.clear)
                            )
                            .foregroundStyle(selectedTab == tab ? (appState.selectedTheme.gradientColors.first ?? .accentColor) : .secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }
                .padding(.top, 90) // Account for draggable header
                .padding(.leading, 16)
                .padding(.trailing, 8)
                .frame(width: 180)
                
                Divider()
                    .padding(.vertical, 80)
                
                // MAIN CONTENT
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(spacing: 20) {
                        if selectedTab == .general {
                    // SECTION: Shortcut & Paste Mode"""

content = content.replace("""        ZStack(alignment: .top) {
            // Scrollable Content
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    // SECTION: Shortcut & Paste Mode""", sidebar_str)

sections = [
    ('// SECTION: Theme & Style', '}\n                        if selectedTab == .appearance {\n                    // SECTION: Theme & Style'),
    ('// SECTION: Language & Model', '}\n                        if selectedTab == .recognition {\n                    // SECTION: Language & Model'),
    ('// SECTION: Statistics', '}\n                        if selectedTab == .statistics {\n                    // SECTION: Statistics'),
    ('// SECTION: System', '}\n                        if selectedTab == .system {\n                    // SECTION: System'),
]
for section, replacement in sections:
    content = content.replace(section, replacement)

# Wrap Support Developer Button in .system tab
support_button_str = """                    // Support Developer Button"""
content = content.replace(support_button_str, """                        // Support Developer Button""")

# Fix the end braces
bottom_padding_str = """                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 116)
                .padding(.bottom, 24)
            }
            .mask("""

better_replacement_bottom = """                    }
                        } // End of system tab
                } // End of main content VStack
                .padding(.horizontal, 24)
                .padding(.top, 116)
                .padding(.bottom, 24)
            } // End of ScrollView
            .mask("""
content = content.replace(bottom_padding_str, better_replacement_bottom)

# And close the HStack right before the Drag header:
header_str = """            // Header — draggable to move the window"""
content = content.replace(header_str, """            } // End of HStack\n\n            // Header — draggable to move the window""")

# 6. Add Gamification UI to StatisticsSectionView
gamification_str = """            VStack(spacing: 14) {
                // Gamification: Level & Time Saved
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(appState.l("Time Saved"))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)
                        Text(formatDuration(history.timeSaved))
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 6) {
                        HStack(spacing: 8) {
                            Text("Level \\(history.currentLevel)")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(.secondary)
                            Text(history.currentLevelName)
                                .font(.system(size: 16, weight: .bold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                            
                        if history.currentLevel < 50 {
                            Text("\\(history.wordsToNextLevel) words to Level \\(history.currentLevel + 1)")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        } else {
                            Text("Max Level Reached!")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        
                        HStack(spacing: 8) {
                            ProgressView(value: history.currentLevelProgress, total: 1.0)
                                .progressViewStyle(.linear)
                                .frame(width: 100)
                        }
                    }
                }
                // Segmented Time Frame Picker"""

content = content.replace("""            VStack(spacing: 14) {
                // Segmented Time Frame Picker""", gamification_str)

with open('/Users/aleksei/Documents/Scribe/Scribe/UI/SettingsView.swift', 'w') as f:
    f.write(content)

