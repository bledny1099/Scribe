import re

with open("Scribe/UI/SettingsView.swift", "r") as f:
    settings = f.read()

# 1. Fix StatisticsSectionView
stats_old = """        VStack(spacing: 20) {
            // Gamification Header with Blue Gradient
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\\(history.currentLevelName) - Level \\(history.currentLevel)")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .shadow(color: history.currentLevelColor.opacity(0.5), radius: 10, x: 0, y: 5)
                        
                        Text("\\(history.totalWords) / \\(history.totalWords + history.wordsToNextLevel) Words to next level")
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

            // Regular Stats Grid
            GlassSection(title: appState.l("Statistics"), icon: "chart.bar.fill") {"""

stats_new = """        VStack(spacing: 20) {
            GlassSection(title: appState.l("Statistics"), icon: "chart.bar.fill") {"""

settings = settings.replace(stats_old, stats_new)

grid_end = """                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                        StatCard(title: appState.l("Words Spoken"), value: formatNumber(stats.wordCount), icon: "text.quote", color: .blue)
                        StatCard(title: appState.l("Characters"), value: formatNumber(stats.charCount), icon: "textformat", color: .purple)
                        StatCard(title: appState.l("Time Dictated"), value: formatDuration(stats.duration), icon: "timer", color: .orange)
                        StatCard(title: appState.l("Sessions"), value: formatNumber(stats.sessionCount), icon: "mic.fill", color: .green)
                    }
                }
                .padding(14)
            }"""

grid_end_new = """                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                        StatCard(title: appState.l("Words Spoken"), value: formatNumber(stats.wordCount), icon: "text.quote", color: .blue)
                        StatCard(title: appState.l("Characters"), value: formatNumber(stats.charCount), icon: "textformat", color: .purple)
                        StatCard(title: appState.l("Time Dictated"), value: formatDuration(stats.duration), icon: "timer", color: .orange)
                        StatCard(title: appState.l("Sessions"), value: formatNumber(stats.sessionCount), icon: "mic.fill", color: .green)
                    }
                    
                    // Level and XP
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
                    )
                }
                .padding(14)
            }"""

settings = settings.replace(grid_end, grid_end_new)


# 2. Fix Vocabulary Binding
vocab_old = """                TextEditor(text: Binding(
                    get: { appState.vocabulary },
                    set: { appState.vocabulary = $0 }
                ))"""
vocab_new = """                TextEditor(text: $appState.vocabulary)"""
settings = settings.replace(vocab_old, vocab_new)


# 3. Remove recording divider in GeneralSettingsView
rec_divider_old = """                            }
                            
                            Divider()

                            HStack {"""
rec_divider_new = """                            }
                            
                            HStack {"""
settings = settings.replace(rec_divider_old, rec_divider_new)


# 4. Move Sound feedback under colors in AppearanceSettingsView
# First remove Sound feedback from SystemSettingsView
sound_fb_sys_old = """                            }

                            // Sound feedback
                            HStack {
                                Text(appState.l("Sound Feedback"))
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundStyle(.primary)
                                Spacer()
                                Toggle("", isOn: $appState.soundFeedbackEnabled)
                                    .toggleStyle(.switch)
                                    .labelsHidden()
                            }

                            PermissionsCard()"""
sound_fb_sys_new = """                            }

                            PermissionsCard()"""
settings = settings.replace(sound_fb_sys_old, sound_fb_sys_new)

# Then add it to AppearanceSettingsView under color picker
appearance_colors = """                                    ThemeColorPicker(selectedTheme: $appState.selectedTheme)
                                }
                            }"""
appearance_colors_with_sound = """                                    ThemeColorPicker(selectedTheme: $appState.selectedTheme)
                                }
                            }
                            
                            // Sound feedback
                            HStack {
                                Text(appState.l("Sound Feedback"))
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundStyle(.primary)
                                Spacer()
                                Toggle("", isOn: $appState.soundFeedbackEnabled)
                                    .toggleStyle(.switch)
                                    .labelsHidden()
                            }"""
settings = settings.replace(appearance_colors, appearance_colors_with_sound)

with open("Scribe/UI/SettingsView.swift", "w") as f:
    f.write(settings)
print("Updated SettingsView.swift")
