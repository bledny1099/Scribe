with open("Scribe/UI/SettingsView.swift") as f:
    text = f.read()

# 1. Add 3 closing braces before .system
text = text.replace(
    "                    if selectedTab == .system {",
    """                                } // End VStack
                            } // End GlassSection
                        } // End if .recognition

                        if selectedTab == .system {"""
)

# 2. Add 2 closing braces after the SupportDeveloperModal and then add the new tabs!
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
            } // End of the VStack(spacing: 20) inside ScrollView!
            .padding(.horizontal, 24)"""
)

# WAIT! If I add `} // End of the VStack` before `.padding(.horizontal, 24)`, I must ALSO remove the extra `}` at line 456 that previously closed the ScrollView (which I now moved up? No, 456 was the ScrollView closing brace??)
