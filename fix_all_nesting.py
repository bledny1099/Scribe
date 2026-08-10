import re

with open("Scribe/UI/SettingsView.swift") as f:
    text = f.read()

# We need to find all `if selectedTab == .xxx {` and properly close them at the end of their section!
# Actually, the easiest way is to just replace the entire content of the ScrollView!
# Let's write a script that completely rebuilds the body of SettingsView.swift!
