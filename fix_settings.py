import re

with open("Scribe/UI/SettingsView.swift", "r") as f:
    text = f.read()

# 1. Close .recognition properly
# It ends at line 364 (which is before `if selectedTab == .system {`)
text = text.replace(
    "                    if selectedTab == .system {",
    """                                } // End VStack
                            } // End GlassSection
                        } // End if .recognition

                        if selectedTab == .system {"""
)

# 2. Close .system properly
# It ends right after `SupportDeveloperModal().environmentObject(appState) } }`
text = text.replace(
    """                            .environmentObject(appState)
                    }
                }
                .padding(.horizontal, 24)""",
    """                            .environmentObject(appState)
                    }
                } // End VStack
                } // End GlassSection
                } // End if .system
                
                if selectedTab == .statistics {
                    StatisticsSectionView()
                }
                if selectedTab == .replacements {
                    ReplacementsSettingsView()
                }
                if selectedTab == .integrations {
                    IntegrationsSettingsView()
                }

                .padding(.horizontal, 24)"""
)

with open("Scribe/UI/SettingsView.swift", "w") as f:
    f.write(text)
