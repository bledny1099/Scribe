import re

with open("Scribe/UI/SettingsView.swift", "r") as f:
    text = f.read()

# Locate the end of StatisticsSectionView's LazyVGrid
target = r"(                    }\n\n                \n            \}\n        \}\n    \})"

immersive_gamification = """                    }

                // Immersive Gamification Card
                ZStack {
                    // Ambient Glow
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [
                                    history.currentLevelColor.opacity(0.5),
                                    history.currentLevelColor.opacity(0.1),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .blur(radius: 15)
                        .padding(4)
                    
                    // Glass Material
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.regularMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(history.currentLevelColor.opacity(0.3), lineWidth: 1)
                        )
                    
                    // Content
                    HStack(spacing: 20) {
                        // Level Badge
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [history.currentLevelColor, history.currentLevelColor.opacity(0.6)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .shadow(color: history.currentLevelColor.opacity(0.5), radius: 8, x: 0, y: 0)
                            
                            VStack(spacing: 0) {
                                Text("LVL")
                                    .font(.system(size: 10, weight: .black, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.9))
                                Text("\\(history.currentLevel)")
                                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                                    .foregroundStyle(.white)
                                    .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                            }
                        }
                        .frame(width: 54, height: 54)
                        
                        // Stats & Progress
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .bottom) {
                                Text(history.currentLevelName)
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundStyle(history.currentLevelColor)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                                    .shadow(color: history.currentLevelColor.opacity(0.3), radius: 2, x: 0, y: 0)
                                
                                Spacer()
                                
                                VStack(alignment: .trailing, spacing: -2) {
                                    Text(appState.l("Time Saved"))
                                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.secondary)
                                    Text(formatDuration(history.timeSaved))
                                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                                        .foregroundStyle(.primary)
                                }
                            }
                            
                            // Progress Bar
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.primary.opacity(0.08))
                                    
                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                colors: [history.currentLevelColor, history.currentLevelColor.opacity(0.7)],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: max(0, geo.size.width * history.currentLevelProgress))
                                        .shadow(color: history.currentLevelColor.opacity(0.4), radius: 4, x: 0, y: 0)
                                }
                            }
                            .frame(height: 8)
                            .padding(.top, 2)
                            
                            if history.currentLevel < 50 {
                                Text("\\(history.wordsToNextLevel) words to next level")
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .foregroundColor(.secondary)
                            } else {
                                Text("Max Level Reached!")
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(16)
                }
                .padding(.top, 4)
            }
        }
    }"""

text = re.sub(target, immersive_gamification, text)

with open("Scribe/UI/SettingsView.swift", "w") as f:
    f.write(text)
