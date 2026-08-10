import re

with open("diff_backup.txt", "r") as f:
    text = f.read()

# Extract ReplacementsSettingsView
repl_match = re.search(r"(\+struct ReplacementsSettingsView: View \{.*?\n\+\})", text, re.DOTALL)
if repl_match:
    repl_code = repl_match.group(1)
    # Remove leading + from every line
    repl_code = re.sub(r"^\+", "", repl_code, flags=re.MULTILINE)
    # Write to a temp file
    with open("Scribe/UI/SettingsView.swift", "a") as out:
        out.write("\n" + repl_code + "\n")

# Extract StatisticsSectionView
stat_match = re.search(r"(\+struct StatisticsSectionView: View \{.*?\n\+\})", text, re.DOTALL)
if stat_match:
    stat_code = stat_match.group(1)
    # Remove leading + from every line
    stat_code = re.sub(r"^\+", "", stat_code, flags=re.MULTILINE)
    with open("Scribe/UI/SettingsView.swift", "a") as out:
        out.write("\n" + stat_code + "\n")

print("Appended views successfully.")
