import re

# 1. Update AppState.swift to pass vocabulary
with open("Scribe/AppState.swift", "r") as f:
    app_state = f.read()

# At line 563 (approx)
transcribe_call_old_1 = """                let text = try await transcriptionService.transcribe(
                    audioURL: url,
                    modelName: selectedModel,
                    language: selectedLanguage,
                    preferredLanguages: preferredLanguagesArray,
                    autoTranslate: autoTranslate
                )"""
transcribe_call_new_1 = """                let text = try await transcriptionService.transcribe(
                    audioURL: url,
                    modelName: selectedModel,
                    language: selectedLanguage,
                    preferredLanguages: preferredLanguagesArray,
                    autoTranslate: autoTranslate,
                    customVocabulary: vocabulary
                )"""
app_state = app_state.replace(transcribe_call_old_1, transcribe_call_new_1)

# At line 1015 (approx)
transcribe_call_old_2 = """            let text = try await transcriptionService.transcribe(
                audioURL: url,
                modelName: selectedModel,
                language: selectedLanguage,
                preferredLanguages: preferredLanguagesArray,
                autoTranslate: autoTranslate
            )"""
transcribe_call_new_2 = """            let text = try await transcriptionService.transcribe(
                audioURL: url,
                modelName: selectedModel,
                language: selectedLanguage,
                preferredLanguages: preferredLanguagesArray,
                autoTranslate: autoTranslate,
                customVocabulary: vocabulary
            )"""
app_state = app_state.replace(transcribe_call_old_2, transcribe_call_new_2)

# Also update startStreaming
streaming_call_old = """            try transcriptionService.startStreaming(language: self.selectedLanguage) { partialText in"""
streaming_call_new = """            try transcriptionService.startStreaming(language: self.selectedLanguage, customVocabulary: self.vocabulary) { partialText in"""
app_state = app_state.replace(streaming_call_old, streaming_call_new)

with open("Scribe/AppState.swift", "w") as f:
    f.write(app_state)


# 2. Extract tabs in SettingsView.swift
with open("Scribe/UI/SettingsView.swift", "r") as f:
    settings = f.read()

# I will just write a very robust script to extract General, Appearance, Recognition, System
# Instead of doing complex regex, let's just find the cases and replace them.

def extract_section(case_name, struct_name, icon_name, view_code):
    pass

# Actually, an easier way is to just wrap the body content in smaller View components.
# Let's extract GeneralSettingsView
general_pattern = r"(case \.general:\n\s*// SECTION: Shortcut & Paste Mode\n\s*GlassSection.*?)(case \.appearance:)"
general_match = re.search(general_pattern, settings, flags=re.DOTALL)
if general_match:
    general_content = general_match.group(1)
    struct_general = f"""
// MARK: - General Settings View
struct GeneralSettingsView: View {{
    @EnvironmentObject var appState: AppState
    var body: some View {{
{general_content.replace('case .general:', '')}
    }}
}}
"""
    settings = settings.replace(general_content, "case .general:\n                            GeneralSettingsView()\n                        ")
    settings += struct_general

# Extract AppearanceSettingsView
appearance_pattern = r"(case \.appearance:\n\s*// SECTION: Appearance & UI\n\s*GlassSection.*?)(case \.recognition:)"
appearance_match = re.search(appearance_pattern, settings, flags=re.DOTALL)
if appearance_match:
    appearance_content = appearance_match.group(1)
    struct_appearance = f"""
// MARK: - Appearance Settings View
struct AppearanceSettingsView: View {{
    @EnvironmentObject var appState: AppState
    var body: some View {{
{appearance_content.replace('case .appearance:', '')}
    }}
}}
"""
    settings = settings.replace(appearance_content, "case .appearance:\n                            AppearanceSettingsView()\n                        ")
    settings += struct_appearance

# Extract RecognitionSettingsView
recognition_pattern = r"(case \.recognition:\n\s*// SECTION: AI Model\n\s*GlassSection.*?)(case \.statistics:)"
recognition_match = re.search(recognition_pattern, settings, flags=re.DOTALL)
if recognition_match:
    recognition_content = recognition_match.group(1)
    # The recognition section uses `models`. We need to define `models` inside it.
    models_def = """    private let models: [(id: String, name: String, desc: String)] = [
        ("openai_whisper-small", "Small (Recommended)", "Great balance of high accuracy and speed (~460MB)"),
        ("openai_whisper-large-v3_turbo", "Large V3 Turbo", "Highest quality for complex speech & terms (~950MB)"),
        ("openai_whisper-base", "Base (Fastest)", "Lightweight and ultra fast, ideal for simple phrases (~140MB)")
    ]"""
    struct_recognition = f"""
// MARK: - Recognition Settings View
struct RecognitionSettingsView: View {{
    @EnvironmentObject var appState: AppState
{models_def}
    var body: some View {{
{recognition_content.replace('case .recognition:', '')}
    }}
}}
"""
    settings = settings.replace(recognition_content, "case .recognition:\n                            RecognitionSettingsView()\n                        ")
    settings += struct_recognition

# Extract SystemSettingsView
system_pattern = r"(case \.system:\n\s*// SECTION: System\n\s*GlassSection.*?)(                            }\n                        }\n                    }\n                    \.padding\(\.horizontal, 24\))"
system_match = re.search(system_pattern, settings, flags=re.DOTALL)
if system_match:
    system_content = system_match.group(1)
    struct_system = f"""
// MARK: - System Settings View
struct SystemSettingsView: View {{
    @EnvironmentObject var appState: AppState
    var body: some View {{
{system_content.replace('case .system:', '')}
    }}
}}
"""
    settings = settings.replace(system_content, "case .system:\n                            SystemSettingsView()\n")
    settings += struct_system

with open("Scribe/UI/SettingsView.swift", "w") as f:
    f.write(settings)

print("Done extracting tabs!")
