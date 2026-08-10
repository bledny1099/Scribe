with open("Scribe/UI/SettingsView.swift") as f:
    text = f.read()

start_idx = text.find("if selectedTab == .system {")
end_idx = text.find(".padding(.horizontal, 24)", start_idx)

print(text[end_idx - 100 : end_idx])
