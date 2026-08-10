import re

with open("Scribe/UI/SettingsView.swift", "r") as f:
    text = f.read()

# Extract Vocabulary into a separate view
vocab_ui_in_switch = """                        case .vocabulary:
                    GlassSection(title: appState.l("Vocabulary"), icon: "text.book.closed.fill") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(appState.l("Add custom words, names, or acronyms to help Scribe recognize them correctly. Separate words with commas."))
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                            
                            TextEditor(text: $appState.vocabulary)
                                .font(.system(size: 14))
                                .frame(height: 120)
                                .padding(8)
                                .background(Color.primary.opacity(0.04))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                                )
                        }
                        .padding(14)
                    }
"""

vocab_struct = """
// MARK: - Vocabulary Settings View
struct VocabularySettingsView: View {
    @EnvironmentObject var appState: AppState
    var body: some View {
        GlassSection(title: appState.l("Vocabulary"), icon: "text.book.closed.fill") {
            VStack(alignment: .leading, spacing: 12) {
                Text(appState.l("Add custom words, names, or acronyms to help Scribe recognize them correctly. Separate words with commas."))
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                
                TextEditor(text: Binding(
                    get: { appState.vocabulary },
                    set: { appState.vocabulary = $0 }
                ))
                    .font(.system(size: 14))
                    .frame(height: 120)
                    .padding(8)
                    .background(Color.primary.opacity(0.04))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                    )
            }
            .padding(14)
        }
    }
}
"""

if vocab_ui_in_switch in text:
    text = text.replace(vocab_ui_in_switch, "                        case .vocabulary:\n                            VocabularySettingsView()\n")
    text += vocab_struct
    
with open("Scribe/UI/SettingsView.swift", "w") as f:
    f.write(text)

