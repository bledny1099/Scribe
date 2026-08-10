import re

# 1. Update AppState.swift
with open("Scribe/AppState.swift", "r") as f:
    app_state = f.read()

# Add recognitionEngine AppStorage
if 'var recognitionEngine' not in app_state:
    app_state = app_state.replace('@AppStorage("vocabulary") public var vocabulary: String = ""',
                                  '@AppStorage("vocabulary") public var vocabulary: String = ""\n    @AppStorage("recognitionEngine") public var recognitionEngine: String = "Both"')

# In startRecording
start_rec_old = """            // Start Live Preview (Apple Speech) if enabled
            do {
                try transcriptionService.startStreaming(language: self.selectedLanguage, customVocabulary: self.vocabulary) { partialText in
                    self.livePreviewText = partialText
                }
            } catch {
                logger.error("Failed to start Apple Speech streaming: \\(error.localizedDescription)")
            }

            livePreviewText = ""
            startDurationTimer()
            if livePreviewEnabled { startLivePreviewTimer() }"""

start_rec_new = """            // Start Live Preview (Apple Speech) if enabled
            if self.recognitionEngine != "Whisper" {
                do {
                    try transcriptionService.startStreaming(language: self.selectedLanguage, customVocabulary: self.vocabulary) { partialText in
                        self.livePreviewText = partialText
                    }
                } catch {
                    logger.error("Failed to start Apple Speech streaming: \\(error.localizedDescription)")
                }
            }

            livePreviewText = ""
            startDurationTimer()
            if livePreviewEnabled && self.recognitionEngine != "Whisper" { startLivePreviewTimer() }"""

app_state = app_state.replace(start_rec_old, start_rec_new)


# In stopRecording
stop_rec_old = """        Task {
            do {
                logger.info("Starting transcription with model=\\(self.selectedModel), lang=\\(self.selectedLanguage)…")
                let langParam = self.selectedLanguage == "auto" ? nil : self.selectedLanguage
                let text = try await transcriptionService.transcribe(
                    audioURL: audioURL,
                    modelName: self.selectedModel,
                    language: langParam,
                    preferredLanguages: preferredLanguagesArray,
                    autoTranslate: self.autoTranslate,
                    customVocabulary: vocabulary
                )"""

stop_rec_new = """        Task {
            do {
                var text = ""
                if self.recognitionEngine == "Apple Speech" {
                    logger.info("Skipping WhisperKit, using Apple Speech final text.")
                    text = await transcriptionService.stopStreaming()
                } else {
                    if self.recognitionEngine == "Both" {
                        _ = await transcriptionService.stopStreaming() // gracefully stop Apple Speech
                    }
                    logger.info("Starting transcription with model=\\(self.selectedModel), lang=\\(self.selectedLanguage)…")
                    let langParam = self.selectedLanguage == "auto" ? nil : self.selectedLanguage
                    text = try await transcriptionService.transcribe(
                        audioURL: audioURL,
                        modelName: self.selectedModel,
                        language: langParam,
                        preferredLanguages: preferredLanguagesArray,
                        autoTranslate: self.autoTranslate,
                        customVocabulary: vocabulary
                    )
                }"""

app_state = app_state.replace(stop_rec_old, stop_rec_new)

# In handleAudioDropped
dropped_old = """            let text = try await transcriptionService.transcribe(
                audioURL: url,
                modelName: selectedModel,
                language: selectedLanguage,
                preferredLanguages: preferredLanguagesArray,
                autoTranslate: autoTranslate,
                customVocabulary: vocabulary
            )"""

dropped_new = """            var text = ""
            if self.recognitionEngine == "Apple Speech" {
                // For file drop, we don't support Apple Speech currently, so fallback to Whisper
                logger.info("Fallback to WhisperKit for file drop.")
                text = try await transcriptionService.transcribe(
                    audioURL: url,
                    modelName: selectedModel,
                    language: selectedLanguage,
                    preferredLanguages: preferredLanguagesArray,
                    autoTranslate: autoTranslate,
                    customVocabulary: vocabulary
                )
            } else {
                text = try await transcriptionService.transcribe(
                    audioURL: url,
                    modelName: selectedModel,
                    language: selectedLanguage,
                    preferredLanguages: preferredLanguagesArray,
                    autoTranslate: autoTranslate,
                    customVocabulary: vocabulary
                )
            }"""

app_state = app_state.replace(dropped_old, dropped_new)

with open("Scribe/AppState.swift", "w") as f:
    f.write(app_state)


# 2. Update SettingsView.swift
with open("Scribe/UI/SettingsView.swift", "r") as f:
    settings = f.read()

rec_settings_old = """                            HStack {
                                Text(appState.l("Dictation Language"))"""
rec_settings_new = """                            HStack {
                                Text(appState.l("Recognition Engine"))
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundStyle(.primary)
                                Spacer()
                                LiquidGlassMenu(
                                    items: ["Apple Speech", "Whisper", "Both"],
                                    selection: $appState.recognitionEngine,
                                    title: { id in appState.l(id) }
                                )
                            }
                            
                            HStack {
                                Text(appState.l("Dictation Language"))"""

settings = settings.replace(rec_settings_old, rec_settings_new)

with open("Scribe/UI/SettingsView.swift", "w") as f:
    f.write(settings)

print("Recognition Engine logic added!")
