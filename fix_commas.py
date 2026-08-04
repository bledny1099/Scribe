import re

filepath = "/Users/aleksei/Documents/Scribe/Scribe/Utilities/Localization.swift"

with open(filepath, "r") as f:
    lines = f.readlines()

new_lines = []
for i, line in enumerate(lines):
    if i < len(lines) - 1:
        # If the current line is a valid key-value string mapping without a comma
        # and the next line is also a key-value string mapping
        if re.search(r'"\s*$', line.strip()) and re.match(r'^\s*"[^"]+":\s*"[^"]+"', lines[i+1]):
            # It's a string ending with quote, and next line is a new key
            line = line.rstrip() + ",\n"
    new_lines.append(line)

with open(filepath, "w") as f:
    f.writelines(new_lines)
