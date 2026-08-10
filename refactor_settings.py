import re

with open("Scribe/UI/SettingsView.swift", "r") as f:
    text = f.read()

# 1. Extract General
general_pattern = r"(GlassSection\(title: appState\.l\(\"Recording\"\), icon: \"keyboard\"\) \{.*?\}\n                    \})"
m1 = re.search(general_pattern, text, re.DOTALL)
general_code = m1.group(1) if m1 else ""

# 2. Extract Appearance
appearance_pattern = r"(GlassSection\(title: appState\.l\(\"Appearance\"\), icon: \"paintpalette\"\) \{.*?\}\n                    \})"
m2 = re.search(appearance_pattern, text, re.DOTALL)
appearance_code = m2.group(1) if m2 else ""

# 3. Extract Recognition
recognition_pattern = r"(GlassSection\(title: appState\.l\(\"Recognition\"\), icon: \"waveform\.and\.mic\"\) \{.*?\}\n                    \})"
m3 = re.search(recognition_pattern, text, re.DOTALL)
recognition_code = m3.group(1) if m3 else ""

# 4. Extract System
system_pattern = r"(GlassSection\(title: appState\.l\(\"System\"\), icon: \"lock\.shield\"\) \{.*?\}\n                    \})"
m4 = re.search(system_pattern, text, re.DOTALL)
system_code = m4.group(1) if m4 else ""

# 5. Extract Support Developer Button (it's inside System section in UI but outside GlassSection)
support_pattern = r"(// Support Developer Button.*?\}\n                    \}\n                    \.buttonStyle\(\.plain\)\n                    \.padding\(\.top, 8\)\n                    \.sheet\(isPresented: \$showingSupportModal\) \{.*?\n                    \})"
m5 = re.search(support_pattern, text, re.DOTALL)
support_code = m5.group(1) if m5 else ""

print("General:", bool(general_code))
print("Appearance:", bool(appearance_code))
print("Recognition:", bool(recognition_code))
print("System:", bool(system_code))
print("Support:", bool(support_code))

if all([general_code, appearance_code, recognition_code, system_code, support_code]):
    print("All sections extracted!")
