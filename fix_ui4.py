import re

with open('/Users/aleksei/Documents/Scribe/Scribe/UI/SettingsView.swift', 'r') as f:
    content = f.read()

# 8. Add closing brackets
bottom_regex = re.compile(r'(\.sheet\(isPresented: \$showingSupportModal\) \{\s*SupportDeveloperModal\(\)\s*\.environmentObject\(appState\)\s*\})\s*\}\s*\.padding\(\.horizontal, 24\)\s*\.padding\(\.top, 116\)\s*\.padding\(\.bottom, 24\)\s*\}(\s*\.mask\()', re.DOTALL)
content = bottom_regex.sub(r'\1\n                    } // End of system tab\n                }\n                .padding(.horizontal, 24)\n                .padding(.top, 116)\n                .padding(.bottom, 24)\n            } // End of ScrollView\n            } // End of HStack\n\2', content)

# But wait! Because I need to run this ON TOP of the FIRST half of fix_and_upgrade_ui.py...
# Let's just fix the python script!
