import re
import os

# 1. Run modify_settings.py first
os.system('python3 modify_settings.py')

# 2. Apply our new changes
with open('/Users/aleksei/Documents/Scribe/Scribe/UI/SettingsView.swift', 'r') as f:
    content = f.read()

# Update enum
enum_old = """    enum SettingsTab: String, CaseIterable, Identifiable {
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
    }"""
enum_new = """    enum SettingsTab: String, CaseIterable, Identifiable {
        case general = "General"
        case appearance = "Appearance"
        case recognition = "Recognition"
        case statistics = "Statistics"
        case system = "System"
        case history = "History"
        
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .general: return "keyboard"
            case .appearance: return "paintbrush.fill"
            case .recognition: return "waveform.and.mic"
            case .statistics: return "chart.bar.fill"
            case .system: return "lock.shield"
            case .history: return "clock.arrow.circlepath"
            }
        }
    }"""
content = content.replace(enum_old, enum_new)

# Sidebar Clickability
content = content.replace('.padding(.vertical, 10)\n                            .padding(.horizontal, 12)', '.contentShape(Rectangle())\n                            .padding(.vertical, 10)\n                            .padding(.horizontal, 12)')

# Paste Mode VStack
paste_regex = re.compile(r'                            HStack \{\s*Text\(appState\.l\("Paste Mode"\)\).*?LiquidGlassSegmentedPicker\([^)]+\)\s*\}', re.DOTALL)
paste_new = """                            VStack(alignment: .leading, spacing: 10) {
                                Text(appState.l("Paste Mode"))
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundStyle(.primary)
                                LiquidGlassSegmentedPicker(
                                    items: PasteMode.allCases,
                                    selection: Binding(
                                        get: { appState.selectedPasteMode },
                                        set: { appState.selectedPasteMode = $0 }
                                    ),
                                    label: { (appState.l($0.displayName), $0.icon) }
                                )
                            }"""
content = paste_regex.sub(paste_new, content)

# Remove old History Button completely (Regex)
history_btn_regex = re.compile(r'\s*// History Button\s*Button\(action: \{\s*HistoryWindowManager.*?\}\s*\.buttonStyle\(\.plain\)', re.DOTALL)
content = history_btn_regex.sub('', content)

# Insert History Tab
history_tab = """                    }
                        if selectedTab == .history {
                    // SECTION: History
                    GlassSection(title: appState.l("Transcription History"), icon: "clock.arrow.circlepath") {
                        VStack(spacing: 24) {
                            Text(appState.l("View and manage all your past transcribed text, export data, and track your gamification progress over time."))
                                .font(.system(size: 14, weight: .regular))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                                .padding(.top, 10)
                                
                            Button(action: {
                                HistoryWindowManager.shared.showWindow(appState: appState)
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: "clock.arrow.circlepath")
                                        .font(.system(size: 16, weight: .semibold))
                                    Text(appState.l("Open History Window"))
                                        .font(.system(size: 15, weight: .bold, design: .rounded))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(LinearGradient(colors: [Color.blue, Color.purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                                )
                                .foregroundStyle(.white)
                                .shadow(color: Color.blue.opacity(0.3), radius: 10, x: 0, y: 5)
                            }
                            .buttonStyle(.plain)
                            
                            Spacer().frame(height: 10)
                        }
                    }"""

content = content.replace("                        if selectedTab == .system {", history_tab + "\n                        } // End of history tab\n                        if selectedTab == .system {")

# Also need to fix StatisticsSectionView 
# Just use regex to replace the entire struct StatisticsSectionView {...} up to the end of the file.
new_stats = """// MARK: - Statistics Section Component

struct StatisticsSectionView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var history = TranscriptionHistory.shared
    @State private var timeFrame: StatsTimeFrame = .today

    var body: some View {
        GlassSection(title: appState.l("Statistics"), icon: "chart.bar.fill") {
            VStack(spacing: 24) {
                // GAMIFICATION DASHBOARD
                HStack(spacing: 20) {
                    // Level Badge
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [.blue.opacity(0.15), .purple.opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 74, height: 74)
                        
                        Circle()
                            .stroke(LinearGradient(colors: [.blue.opacity(0.8), .purple.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 3)
                            .frame(width: 74, height: 74)
                            
                        VStack(spacing: -2) {
                            Text("LVL")
                                .font(.system(size: 12, weight: .black, design: .rounded))
                                .foregroundStyle(.secondary.opacity(0.8))
                            Text("\\(history.currentLevel)")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary)
                        }
                    }
                    
                    // Level Info
                    VStack(alignment: .leading, spacing: 6) {
                        Text(history.currentLevelName)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing))
                            
                        if history.currentLevel < 50 {
                            Text("\\(history.wordsToNextLevel) words to next level")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Max Level Reached!")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        
                        // Custom Progress Bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.primary.opacity(0.1))
                                    .frame(height: 10)
                                    
                                Capsule()
                                    .fill(LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing))
                                    .frame(width: max(0, geo.size.width * history.currentLevelProgress), height: 10)
                                    .shadow(color: .blue.opacity(0.4), radius: 6, x: 0, y: 0)
                            }
                        }
                        .frame(height: 10)
                        .padding(.top, 2)
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.primary.opacity(0.04))
                        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Color.primary.opacity(0.08)))
                )
                
                // Segmented Time Frame Picker
                LiquidGlassSegmentedPicker(
                    items: StatsTimeFrame.allCases,
                    selection: $timeFrame,
                    label: { (appState.l($0.rawValue), "") }
                )
                
                let stats = history.stats(for: timeFrame)
                
                // 2x2 Grid of Stat Cards
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 16) {
                    ModernStatCard(
                        title: appState.l("Time Saved"),
                        value: formatDuration(stats.duration),
                        icon: "timer",
                        color: .orange
                    )
                    ModernStatCard(
                        title: appState.l("Words Spoken"),
                        value: formatNumber(stats.wordCount),
                        icon: "text.quote",
                        color: .blue
                    )
                    ModernStatCard(
                        title: appState.l("Characters"),
                        value: formatNumber(stats.charCount),
                        icon: "textformat",
                        color: .purple
                    )
                    ModernStatCard(
                        title: appState.l("Sessions"),
                        value: formatNumber(stats.sessionCount),
                        icon: "mic.fill",
                        color: .green
                    )
                }
            }
        }
    }

    private func formatNumber(_ num: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: num)) ?? "\\(num)"
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let totalSecs = Int(duration)
        let hours = totalSecs / 3600
        let mins = (totalSecs % 3600) / 60
        let secs = totalSecs % 60

        if hours > 0 {
            return "\\(hours)h \\(mins)m"
        } else if mins > 0 {
            return "\\(mins)m \\(secs)s"
        } else {
            return "\\(secs)s"
        }
    }
}

struct ModernStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(color)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.primary.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.primary.opacity(0.06), lineWidth: 1))
        )
    }
}
"""

stats_regex = re.compile(r'// MARK: - Statistics Section Component.*', re.DOTALL)
content = stats_regex.sub(new_stats, content)

with open('/Users/aleksei/Documents/Scribe/Scribe/UI/SettingsView.swift', 'w') as f:
    f.write(content)
