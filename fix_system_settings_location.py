import re

with open("Scribe/UI/SettingsView.swift", "r") as f:
    text = f.read()

# Remove the systemSettings that is placed outside
system_start = "    private var systemSettings: some View {"
# It starts at `    private var systemSettings: some View {` and ends right before `struct StatisticsSectionView: View {`
if system_start in text:
    idx_start = text.find(system_start)
    idx_end = text.find("struct StatisticsSectionView: View {", idx_start)
    if idx_start != -1 and idx_end != -1:
        system_block = text[idx_start:idx_end]
        text = text[:idx_start] + text[idx_end:]
        
        # Now insert it INSIDE SettingsView, which ends right before the place we extracted it from
        # Find the last closing brace before idx_start
        last_brace = text.rfind("}", 0, idx_start)
        
        text = text[:last_brace] + system_block + text[last_brace:]

with open("Scribe/UI/SettingsView.swift", "w") as f:
    f.write(text)

print("Fixed system settings location.")
