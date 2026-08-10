import re

with open("Scribe/UI/SettingsView.swift", "r") as f:
    text = f.read()

# 1. Add Push-to-talk to General tab
ptt_ui = """
                            Divider()
                            
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(appState.l("Push-to-Talk (Hold to record)"))
                                        .font(.system(size: 14, weight: .medium, design: .rounded))
                                        .foregroundStyle(.primary)
                                    Text(appState.l("Hold Option+S to record, release to stop"))
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Toggle("", isOn: $appState.pushToTalk)
                                    .toggleStyle(.switch)
                                    .labelsHidden()
                            }
"""
if "Push-to-Talk" not in text:
    target_paste_desc = r"(\.padding\(\.top, -8\))"
    text = re.sub(target_paste_desc, r"\1\n" + ptt_ui, text)


# 2. Fix Statistics Gamification and Blue Screen
# Replace StatisticsSectionView with one that has the gamification and a blue background if needed.
# Since Statistics is a tab, we can just remove GlassCollapsibleSection and replace it with a beautiful blue container!
gamification_ui = """
struct StatisticsSectionView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var history = TranscriptionHistory.shared
    @State private var timeFrame: StatsTimeFrame = .today

    var body: some View {
        VStack(spacing: 20) {
            // Gamification Header with Blue Gradient
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(history.currentLevelName) - Level \(history.currentLevel)")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .shadow(color: history.currentLevelColor.opacity(0.5), radius: 10, x: 0, y: 5)
                        
                        Text("\(history.totalWords) / \(history.totalWords + history.wordsToNextLevel) Words to next level")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    Spacer()
                    
                    Image(systemName: "star.circle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.white)
                        .shadow(color: history.currentLevelColor.opacity(0.8), radius: 15, x: 0, y: 0)
                }
                
                // Smooth glow progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.black.opacity(0.2))
                        
                        RoundedRectangle(cornerRadius: 10)
                            .fill(LinearGradient(colors: [.white.opacity(0.8), .white], startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(0, geo.size.width * CGFloat(history.currentLevelProgress)))
                            .shadow(color: .white.opacity(0.8), radius: 8, x: 0, y: 0)
                    }
                }
                .frame(height: 14)
            }
            .padding(20)
            .background(
                LinearGradient(
                    colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.6)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: Color.blue.opacity(0.3), radius: 15, x: 0, y: 10)

            // Regular Stats Grid
            GlassSection(title: appState.l("Statistics"), icon: "chart.bar.fill") {
                VStack(spacing: 14) {
                    LiquidGlassSegmentedPicker(
                        items: StatsTimeFrame.allCases,
                        selection: $timeFrame,
                        label: { (appState.l($0.rawValue), "") }
                    )

                    let stats = history.stats(for: timeFrame)

                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                        StatCard(title: appState.l("Words Spoken"), value: formatNumber(stats.wordCount), icon: "text.quote", color: .blue)
                        StatCard(title: appState.l("Characters"), value: formatNumber(stats.charCount), icon: "textformat", color: .purple)
                        StatCard(title: appState.l("Time Dictated"), value: formatDuration(stats.duration), icon: "timer", color: .orange)
                        StatCard(title: appState.l("Sessions"), value: formatNumber(stats.sessionCount), icon: "mic.fill", color: .green)
                    }
                }
                .padding(14)
            }
        }
    }

    private func formatNumber(_ num: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: num)) ?? "\(num)"
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let totalSecs = Int(duration)
        let hours = totalSecs / 3600
        let mins = (totalSecs % 3600) / 60
        let secs = totalSecs % 60
        if hours > 0 { return "\(hours)h \(mins)m" }
        else if mins > 0 { return "\(mins)m \(secs)s" }
        else { return "\(secs)s" }
    }
}
"""

# Replace the old StatisticsSectionView
start_idx = text.find("struct StatisticsSectionView: View {")
end_idx = text.find("struct StatCard: View {")
if start_idx != -1 and end_idx != -1:
    text = text[:start_idx] + gamification_ui + text[end_idx:]

with open("Scribe/UI/SettingsView.swift", "w") as f:
    f.write(text)

print("Second batch applied!")
