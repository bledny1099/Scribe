with open("Scribe/UI/SettingsView.swift") as f:
    lines = f.readlines()
count = 0
for i, line in enumerate(lines):
    count += line.count("{")
    count -= line.count("}")
    if i == 532:
        print(f"Line 533 count: {count}")
    if i == 542:
        print(f"Line 543 count: {count}")
    if i == 795:
        print(f"Line 796 count: {count}")
print(f"Final count: {count}")
