import re

with open("Scribe/UI/SettingsView.swift", "r") as f:
    text = f.read()

# We want to add the Level and XP section right after the 2x2 Grid of Stat Cards in StatisticsSectionView
# The Grid ends at line 566 (which is `                }` just before `            }` of VStack)

stats_ui = """                // Level and XP
                VStack(spacing: 8) {
                    HStack {
                        Text("\\(history.currentLevelName) - Level \\(history.currentLevel)")
                            .font(.system(size: 16, weight: .bold))
                            .shadow(color: history.currentLevelColor.opacity(0.8), radius: 8, x: 0, y: 0)
                        Spacer()
                        Text("\\(history.totalWords) / \\(history.totalWords + history.wordsToNextLevel) Words")
                            .font(.system(size: 13, weight: .medium))
                            .shadow(color: history.currentLevelColor.opacity(0.8), radius: 8, x: 0, y: 0)
                    }
                    
                    // Smooth glow progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.primary.opacity(0.1))
                            
                            RoundedRectangle(cornerRadius: 8)
                                .fill(
                                    LinearGradient(colors: [history.currentLevelColor, history.currentLevelColor.opacity(0.5)], startPoint: .leading, endPoint: .trailing)
                                )
                                .frame(width: max(0, geo.size.width * CGFloat(history.currentLevelProgress)))
                                .shadow(color: history.currentLevelColor.opacity(0.6), radius: 6, x: 0, y: 0)
                        }
                    }
                    .frame(height: 12)
                }
                .padding()
                .background(Color.primary.opacity(0.05))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(history.currentLevelColor.opacity(0.3), lineWidth: 1)
                        .shadow(color: history.currentLevelColor.opacity(0.3), radius: 10, x: 0, y: 0)
                )"""

# Find the end of the LazyVGrid inside StatisticsSectionView
target = r"(                    StatCard\(\n                        title: appState\.l\(\"Sessions\"\),\n                        value: formatNumber\(stats\.sessionCount\),\n                        icon: \"mic\.fill\",\n                        color: \.green\n                    \)\n                \})"
replacement = r"\1\n\n" + stats_ui

text = re.sub(target, replacement, text)

with open("Scribe/UI/SettingsView.swift", "w") as f:
    f.write(text)

print("Patched stats successfully.")
