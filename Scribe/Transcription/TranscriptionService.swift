import Foundation
import AppKit
import WhisperKit
import os.log
import Speech
import AVFoundation

private let logger = Logger(subsystem: "com.aleksei.scribe", category: "Transcription")

// MARK: - Supporting Types

enum TranscriptionState: Equatable {
    case idle
    case loadingModel
    case transcribing
    case done(String)
    case error(String)
}

enum TranscriptionError: LocalizedError {
    case modelNotLoaded
    case noResult

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded: "WhisperKit model is not loaded"
        case .noResult:       "No transcription result returned"
        }
    }
}

// MARK: - Service

/// Manages the WhisperKit pipeline: lazy model loading + audio-file transcription.
///
/// The class is `@unchecked Sendable` because its mutable state (`whisperKit`)
/// is only ever written/read from `@MainActor`-isolated call sites (AppState).
final class TranscriptionService: ObservableObject, @unchecked Sendable {

    @MainActor @Published var state: TranscriptionState = .idle

    private var whisperKit: WhisperKit?
    private var loadedModelName: String?

    // Apple Speech State
    private var speechRecognizer: SFSpeechRecognizer?
    private var speechRequest: SFSpeechAudioBufferRecognitionRequest?
    private var speechTask: SFSpeechRecognitionTask?
    private var currentStreamingText: String = ""

    /// Initial prompt that conditions Whisper to produce punctuation and recognise common brand names.
    /// Whisper uses this as "previous context" so it learns the expected output style.
    private let initialPrompt: [String: String] = [
        "en": "Use proper punctuation, capitalization, commas, and natural sentence structures. Terms: Bybit, Binance, MetaMask, Solana, TikTok, Instagram, YouTube, Snapchat, Telegram, Viber, ChatGPT, Gemini, Claude, Kimi, Perplexity, Midjourney, OpenAI, paperclip-ai, Claude Code, Ollama, PyTorch, Supabase, SwiftData, Docker, Kubernetes, Next.js, Rust, WhisperKit, HuggingFace, Vercel, TailwindCSS, PostgreSQL, GraphQL, TypeScript, LLM, Llama, LangChain, Google, Antigravity, IDE, Scribe.",
        "ru": "Распознавай русскую речь связно и грамотно, сохраняя правильные падежи, окончания слов, предлоги и пунктуацию (запятые, точки, тире). Мы пишем код, общаемся в чатах, обсуждаем задачи и делимся мыслями. Термины: Bybit, Binance, MetaMask, Solana, Telegram, Viber, ChatGPT, Gemini, Claude, Perplexity, Midjourney, OpenAI, Claude Code, Ollama, PyTorch, Supabase, SwiftData, Docker, Kubernetes, Next.js, Rust, WhisperKit, Vercel, TailwindCSS, PostgreSQL, GraphQL, TypeScript, LLM, Llama, Google, Antigravity, IDE, Scribe, транскрибатор, Хабр.",
        "es": "Términos: Bybit, Binance, MetaMask, Solana, TikTok, Instagram, YouTube, Snapchat, Telegram, Viber, ChatGPT, Gemini, Claude, Kimi, Perplexity, Midjourney, OpenAI, paperclip-ai, Claude Code, Ollama, PyTorch, Supabase, SwiftData, Docker, Kubernetes, Next.js, Rust, WhisperKit, HuggingFace, Vercel, TailwindCSS, PostgreSQL, GraphQL, TypeScript, LLM, Llama, LangChain, Google, Antigravity, IDE, Scribe.",
        "de": "Begriffe: Bybit, Binance, MetaMask, Solana, TikTok, Instagram, YouTube, Snapchat, Telegram, Viber, ChatGPT, Gemini, Claude, Kimi, Perplexity, Midjourney, OpenAI, paperclip-ai, Claude Code, Ollama, PyTorch, Supabase, SwiftData, Docker, Kubernetes, Next.js, Rust, WhisperKit, HuggingFace, Vercel, TailwindCSS, PostgreSQL, GraphQL, TypeScript, LLM, Llama, LangChain, Google, Antigravity, IDE, Scribe.",
        "fr": "Termes: Bybit, Binance, MetaMask, Solana, TikTok, Instagram, YouTube, Snapchat, Telegram, Viber, ChatGPT, Gemini, Claude, Kimi, Perplexity, Midjourney, OpenAI, paperclip-ai, Claude Code, Ollama, PyTorch, Supabase, SwiftData, Docker, Kubernetes, Next.js, Rust, WhisperKit, HuggingFace, Vercel, TailwindCSS, PostgreSQL, GraphQL, TypeScript, LLM, Llama, LangChain, Google, Antigravity, IDE, Scribe.",
        "it": "Termini: Bybit, Binance, MetaMask, Solana, TikTok, Instagram, YouTube, Snapchat, Telegram, Viber, ChatGPT, Gemini, Claude, Kimi, Perplexity, Midjourney, OpenAI, paperclip-ai, Claude Code, Ollama, PyTorch, Supabase, SwiftData, Docker, Kubernetes, Next.js, Rust, WhisperKit, HuggingFace, Vercel, TailwindCSS, PostgreSQL, GraphQL, TypeScript, LLM, Llama, LangChain, Google, Antigravity, IDE, Scribe.",
        "zh": "术语：Bybit, Binance, MetaMask, Solana, TikTok, Instagram, YouTube, Snapchat, Telegram, Viber, ChatGPT, Gemini, Claude, Kimi, Perplexity, Midjourney, OpenAI, paperclip-ai, Claude Code, Ollama, PyTorch, Supabase, SwiftData, Docker, Kubernetes, Next.js, Rust, WhisperKit, HuggingFace, Vercel, TailwindCSS, PostgreSQL, GraphQL, TypeScript, LLM, Llama, LangChain, Google, Antigravity, IDE, Scribe.",
        "ja": "用語：Bybit, Binance, MetaMask, Solana, TikTok, Instagram, YouTube, Snapchat, Telegram, Viber, ChatGPT, Gemini, Claude, Kimi, Perplexity, Midjourney, OpenAI, paperclip-ai, Claude Code, Ollama, PyTorch, Supabase, SwiftData, Docker, Kubernetes, Next.js, Rust, WhisperKit, HuggingFace, Vercel, TailwindCSS, PostgreSQL, GraphQL, TypeScript, LLM, Llama, LangChain, Google, Antigravity, IDE, Scribe.",
        "pt": "Termos: Bybit, Binance, MetaMask, Solana, TikTok, Instagram, YouTube, Snapchat, Telegram, Viber, ChatGPT, Gemini, Claude, Kimi, Perplexity, Midjourney, OpenAI, paperclip-ai, Claude Code, Ollama, PyTorch, Supabase, SwiftData, Docker, Kubernetes, Next.js, Rust, WhisperKit, HuggingFace, Vercel, TailwindCSS, PostgreSQL, GraphQL, TypeScript, LLM, Llama, LangChain, Google, Antigravity, IDE, Scribe.",
        "tr": "Terimler: Bybit, Binance, MetaMask, Solana, TikTok, Instagram, YouTube, Snapchat, Telegram, Viber, ChatGPT, Gemini, Claude, Kimi, Perplexity, Midjourney, OpenAI, paperclip-ai, Claude Code, Ollama, PyTorch, Supabase, SwiftData, Docker, Kubernetes, Next.js, Rust, WhisperKit, HuggingFace, Vercel, TailwindCSS, PostgreSQL, GraphQL, TypeScript, LLM, Llama, LangChain, Google, Antigravity, IDE, Scribe.",
        "uk": "Терміни: Bybit, Binance, MetaMask, Solana, TikTok, Instagram, YouTube, Snapchat, Telegram, Viber, ChatGPT, Gemini, Claude, Kimi, Perplexity, Midjourney, OpenAI, paperclip-ai, Claude Code, Ollama, PyTorch, Supabase, SwiftData, Docker, Kubernetes, Next.js, Rust, WhisperKit, HuggingFace, Vercel, TailwindCSS, PostgreSQL, GraphQL, TypeScript, LLM, Llama, LangChain, Google, Antigravity, IDE, Scribe.",
        "auto": "Естественная русская и английская речь с правильными падежами, окончаниями, предлогами и пунктуацией. We speak fluent Russian and English. Terms: Bybit, Telegram, ChatGPT, Gemini, Claude, OpenAI, Swift, Xcode, Docker, Kubernetes, TypeScript, Python, LLM, Google, Antigravity, Scribe."
    ]

    // MARK: - Model Lifecycle

    /// Downloads / loads the model if it hasn't been loaded yet or if model changed.
    @MainActor
    func ensureModelLoaded(modelName: String = "openai_whisper-small") async throws {
        if whisperKit != nil && loadedModelName == modelName {
            logger.debug("Model \(modelName) already loaded, skipping")
            return
        }

        state = .loadingModel
        logger.info("Loading WhisperKit model '\(modelName)'…")
        
        let config = WhisperKitConfig(model: modelName)
        let kit = try await WhisperKit(config)
        whisperKit = kit
        loadedModelName = modelName
        state = .idle
        logger.info("WhisperKit model '\(modelName)' loaded successfully")
    }

    // MARK: - Apple Speech (Streaming)

    @MainActor
    func startStreaming(language: String?, customVocabulary: String = "", targetApp: NSRunningApplication? = nil, onUpdate: @escaping (String) -> Void) throws {
        state = .transcribing
        currentStreamingText = ""
        
        let locale: Locale
        if let lang = language, lang != "auto" {
            locale = Locale(identifier: lang)
        } else {
            locale = Locale.current
        }
        
        guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else {
            throw TranscriptionError.modelNotLoaded
        }
        
        speechRecognizer = recognizer
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.taskHint = .dictation
        if #available(macOS 13, *) {
            request.addsPunctuation = true
        }
        
        // Try to enable on-device recognition for privacy/speed, if available
        if #available(macOS 13.0, *) {
            if recognizer.supportsOnDeviceRecognition {
                request.requiresOnDeviceRecognition = true
            }
        }
        
        let strings = AetherContextEngine.shared.buildContextualStrings(
            customVocabulary: customVocabulary,
            targetApp: targetApp
        )
        request.contextualStrings = strings
        
        speechRequest = request
        
        speechTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }
            if let result = result {
                let text = result.bestTranscription.formattedString
                Task { @MainActor in
                    self.currentStreamingText = text
                    onUpdate(text)
                }
            }
            if let error = error {
                logger.error("Apple Speech error: \(error.localizedDescription)")
            }
        }
        
        logger.info("Apple Speech streaming started for locale \(locale.identifier)")
    }
    
    func append(_ buffer: AVAudioPCMBuffer) {
        speechRequest?.append(buffer)
    }
    
    @MainActor
    func stopStreaming() async -> String {
        speechRequest?.endAudio()
        
        // Wait a small bit to allow final results to trickle in if needed
        try? await Task.sleep(for: .milliseconds(300))
        
        let finalText = currentStreamingText
        speechTask?.cancel()
        speechTask = nil
        speechRequest = nil
        
        logger.info("Apple Speech streaming stopped. Final text: \(finalText)")
        state = .done(finalText)
        return finalText
    }

    // MARK: - WhisperKit (High Accuracy File Transcription)

    /// Transcribes the audio file at `audioURL` using the specified language (nil for auto-detect).
    @MainActor
    func transcribe(
        audioURL: URL,
        modelName: String = "openai_whisper-small",
        language: String? = nil,
        preferredLanguages: [String] = [],
        autoTranslate: Bool = false,
        customVocabulary: String = "",
        userLocation: String = "",
        targetApp: NSRunningApplication? = nil
    ) async throws -> String {
        logger.info("Aether Transcribing: \(audioURL.lastPathComponent), model: \(modelName), language: \(language ?? "auto-detect"), translate: \(autoTranslate)")

        // Check if model is loaded; load if missing
        if whisperKit == nil || loadedModelName != modelName {
            try await ensureModelLoaded(modelName: modelName)
        }

        guard let kit = whisperKit else {
            throw TranscriptionError.modelNotLoaded
        }

        state = .transcribing

        // 1. Stage B: Audio Conditioning (VAD, high-pass filter, loudness normalization)
        guard let conditionedURL = AetherAudioConditioner.shared.condition(audioURL: audioURL) else {
            logger.info("Audio contains no audible speech, skipping Whisper decoding to prevent hallucinations")
            state = .done("")
            return ""
        }
        let path = conditionedURL.path

        // 2. Configure DecodingOptions with high-performance decoding
        let baseLang = language != nil ? baseLanguageCode(for: language!) : "auto"
        var options = DecodingOptions(task: autoTranslate ? .translate : .transcribe)
        options.temperature = 0.0
        options.temperatureFallbackCount = 0
        options.withoutTimestamps = true
        options.skipSpecialTokens = true

        var resolvedLang = baseLang
        if baseLang != "auto" {
            // User explicitly chose single locked language
            options.language = baseLang
            options.detectLanguage = false
            logger.info("Single language mode: Locked to '\(baseLang)'")
        } else {
            // Multilingual / Dynamic auto mode:
            // Do NOT lock Whisper to one language; allow seamless switching between Russian, English, and other languages.
            options.language = nil
            options.detectLanguage = true
            logger.info("Multilingual dynamic mode: Real-time language detection active across preferred: \(preferredLanguages)")
        }

        // 3. Stage A: Context Biasing & Dynamic Vocabulary Injection
        let langKey = resolvedLang
        let basePrompt = initialPrompt[langKey] ?? initialPrompt["auto"]!
        let promptText = AetherContextEngine.shared.buildConditioningPrompt(
            basePrompt: basePrompt,
            customVocabulary: customVocabulary,
            userLocation: userLocation,
            targetApp: targetApp,
            language: resolvedLang != "auto" ? resolvedLang : language
        )

        if let tokenizer = kit.tokenizer {
            let tokens = tokenizer.encode(text: promptText)
            // WhisperKit prompt tokens: keep compact (max 100) for faster attention decoding
            options.promptTokens = Array(tokens.suffix(min(tokens.count, 100)))
            // Must disable prefill cache when using promptTokens (WhisperKit limitation)
            options.usePrefillCache = false
            logger.debug("Aether set initial prompt (\(options.promptTokens?.count ?? 0) tokens) for language '\(langKey)'")
        }
        
        logger.debug("Calling WhisperKit.transcribe(audioPath: \(path), language: \(options.language ?? "auto"))")

        let results: [TranscriptionResult] = try await Task.detached {
            try await kit.transcribe(audioPath: path, decodeOptions: options)
        }.value

        logger.info("WhisperKit returned \(results.count) result(s)")

        let rawText = results.map(\.text).joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Strip non-speech annotations that Whisper sometimes inserts,
        // e.g. [keyboard clicking], (music), *laughs*, [BLANK_AUDIO], rogue scripts
        var text = Self.cleanTranscription(rawText, preferredLanguages: preferredLanguages, targetLanguage: resolvedLang)

        // Stage C: Linguistic validation against native macOS dictionary and phonetic correction
        let customVocabList = customVocabulary.components(separatedBy: CharacterSet(charactersIn: ",\n;")).map { $0.trimmingCharacters(in: .whitespaces) }
        text = AetherLinguisticValidator.shared.validateAndCorrect(
            text: text,
            language: resolvedLang != "auto" ? resolvedLang : language,
            customVocabulary: customVocabList
        )

        logger.info("Transcribed text (\(text.count) chars): \(text.prefix(100))")

        state = .done(text)
        return text
    }

    // MARK: - Post-Processing

    /// Built-in Whisper boundary hallucination artifacts (common subtitle credits, YouTube noise & trailing repetition loops).
    public static let builtInWhisperHallucinationRoots: [String] = [
        "субтитры сделал",
        "субтитры создавал",
        "субтитры добавил",
        "редактор субтитров",
        "корректор",
        "продолжение следует",
        "спасибо за просмотр",
        "ставьте лайки",
        "ставьте лайк",
        "поставьте лайк",
        "подписывайтесь на канал",
        "подпишитесь на канал",
        "подпишитесь",
        "подписывайтесь",
        "благодарю за просмотр",
        "до новых встреч",
        "до встречи в следующем видео",
        "до встречи в новом видео",
        "ссылка в описании",
        "нажмите на колокольчик",
        "пишите в комментариях",
        "оставляйте комментарии",
        "всем пока",
        "пока-пока",
        "amara.org",
        "subtitles by",
        "thank you for watching",
        "thanks for watching",
        "thank you for listening",
        "thanks for listening",
        "translated by",
        "please subscribe",
        "subscribe to my channel",
        "subscribe to the channel",
        "like and subscribe",
        "like, share, and subscribe",
        "like, comment, and subscribe",
        "don't forget to subscribe",
        "don't forget to like and subscribe",
        "leave a like",
        "leave a comment",
        "let me know in the comments",
        "link in description",
        "link in the description",
        "see you next time",
        "see you in the next one",
        "see you in the next video",
        "watch next",
        "watch more",
        "top 10",
        "top ten",
        "top 5",
        "top five",
        "4nb",
        "genin",
        "jenin",
        "4 nb",
        "find, genin",
        "what is the best place to live in home city",
        "what is the best place to live",
        "what is the best place",
        "in home city",
        "sir"
    ]

    /// Removes non-speech annotations and boundary hallucinations from Whisper output.
    private static func cleanTranscription(_ text: String, preferredLanguages: [String] = [], targetLanguage: String? = nil) -> String {
        var cleaned = text

        // 1. Remove [bracketed annotations] — e.g. [keyboard clicking], [BLANK_AUDIO], [music]
        cleaned = cleaned.replacingOccurrences(
            of: "\\[([^\\]]*?)\\]",
            with: "",
            options: .regularExpression
        )

        // 2. Remove (parenthesized annotations) — e.g. (music), (background noise)
        cleaned = cleaned.replacingOccurrences(
            of: "\\(([^)]*?)\\)",
            with: "",
            options: .regularExpression
        )

        // 3. Remove *asterisk annotations* — e.g. *laughs*, *coughs*
        cleaned = cleaned.replacingOccurrences(
            of: "\\*([^*]*?)\\*",
            with: "",
            options: .regularExpression
        )

        // 4. Remove repetitive noise hallucinations like ǎr ǎr ǎr
        if cleaned.contains("ǎr") {
            cleaned = cleaned.replacingOccurrences(of: "ǎr", with: "")
        }

        // 5. Strip leading hallucinated speaker labels (e.g. "Brooklyn: ", "Speaker 1: ")
        cleaned = stripLeadingSpeakerLabels(cleaned)

        // 6. Strip trailing repetitive loops (e.g. "Top 10. Top 10.")
        cleaned = stripTrailingRepetitions(cleaned)

        // 7. Apply built-in boundary hallucination filter
        cleaned = stripBuiltInHallucinations(cleaned)

        // 8. Strip trailing repetitions again after root stripping
        cleaned = stripTrailingRepetitions(cleaned)

        // 9. If Arabic is not an enabled/selected language, strip Arabic characters and foreign hallucinations
        let activeLangs = Set(preferredLanguages.map { $0.lowercased() } + (targetLanguage != nil ? [targetLanguage!.lowercased()] : []))
        let allowsArabic = activeLangs.contains("ar") || activeLangs.contains("arabic")
        if !allowsArabic {
            cleaned = String(cleaned.unicodeScalars.filter { scalar in
                let val = scalar.value
                let isArabic = (val >= 0x0600 && val <= 0x06FF) || // Arabic
                               (val >= 0x0750 && val <= 0x077F) || // Arabic Supplement
                               (val >= 0x08A0 && val <= 0x08FF) || // Arabic Extended-A
                               (val >= 0xFB50 && val <= 0xFDFF) || // Arabic Presentation Forms-A
                               (val >= 0xFE70 && val <= 0xFEFF)    // Arabic Presentation Forms-B
                return !isArabic
            })
        }

        // Collapse multiple spaces into one and trim
        cleaned = cleaned.replacingOccurrences(
            of: "\\s{2,}",
            with: " ",
            options: .regularExpression
        )
        .trimmingCharacters(in: .whitespacesAndNewlines)

        // If after cleaning it only contains punctuation or spaces, discard
        let alphanumericCount = cleaned.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }.count
        if alphanumericCount == 0 {
            return ""
        }

        return cleaned
    }

    /// Removes hallucinated speaker labels at the beginning of transcriptions (e.g. "Speaker 1:", "Brooklyn:", "Narrator:").
    private static func stripLeadingSpeakerLabels(_ text: String) -> String {
        var cleaned = text
        let pattern = #"^(?:[A-Z][a-zA-Z0-9_\s]{1,15}|Speaker\s*\d*|Narrator|Host|Interviewer|Voice|Man|Woman|Boy|Girl):\s+"#
        cleaned = cleaned.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        return cleaned
    }

    /// Removes consecutive duplicate phrases/words at the end of speech caused by Whisper decoding loops.
    private static func stripTrailingRepetitions(_ text: String) -> String {
        var current = text
        let pattern = #"(?i)(?:\b([A-Za-zА-Яа-я0-9\s]{2,30}?)[.,!?;:\s]+)\1[.,!?;:\s]*$"#
        if let regex = try? NSRegularExpression(pattern: pattern) {
            for _ in 0..<3 {
                let range = NSRange(current.startIndex..<current.endIndex, in: current)
                guard let match = regex.firstMatch(in: current, options: [], range: range),
                      let fullMatchRange = Range(match.range, in: current),
                      let phraseRange = Range(match.range(at: 1), in: current) else { break }

                let phrase = String(current[phraseRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                let lower = phrase.lowercased()
                let isKnownHallucination = builtInWhisperHallucinationRoots.contains(where: { lower.contains($0) || $0.contains(lower) })

                if isKnownHallucination {
                    current.removeSubrange(fullMatchRange)
                } else {
                    current.replaceSubrange(fullMatchRange, with: " " + phrase + ".")
                }
                current = current.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return current
    }

    /// Strips built-in boundary hallucination artifacts.
    /// If the user's entire recording session was intentionally just that phrase alone, it is preserved.
    public static func stripBuiltInHallucinations(_ text: String) -> String {
        guard !text.isEmpty else { return text }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let stripped = trimmed.trimmingCharacters(in: CharacterSet.punctuationCharacters.union(.whitespacesAndNewlines))
        let lowerStripped = stripped.lowercased()

        // 1. If the ENTIRE transcript is intentionally just that single root phrase, preserve it!
        for root in builtInWhisperHallucinationRoots {
            if lowerStripped == root {
                return text
            }
        }

        var result = text
        for root in builtInWhisperHallucinationRoots {
            let escaped = NSRegularExpression.escapedPattern(for: root)
            // Match at the END of string with preceding punctuation/whitespace and optional trailing repetitions
            let endPattern = "(?:[,\\.\\!\\?\\s]+|^)(?:\(escaped)[,\\.\\!\\?\\s]*)+[^\\n]*?$"
            result = result.replacingOccurrences(of: endPattern, with: "", options: [.regularExpression, .caseInsensitive])

            // Match at the START of string with following punctuation/whitespace
            let startPattern = "^(?:\(escaped)[,\\.\\!\\?\\s]*)+[^\\n\\.\\!\\?]*?[,\\.\\!\\?\\s]+"
            result = result.replacingOccurrences(of: startPattern, with: "", options: [.regularExpression, .caseInsensitive])
        }

        // Clean up punctuation and whitespace
        result = result.replacingOccurrences(of: "\\s{2,}", with: " ", options: .regularExpression)
        result = result.replacingOccurrences(of: "\\s+([.,!?:;])", with: "$1", options: .regularExpression)
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)

        // If stripping left only orphan punctuation (e.g. "." or "..."), but there was actual text, restore or clean
        let alphaCheck = result.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }
        if alphaCheck.isEmpty && !trimmed.isEmpty {
            let origAlpha = trimmed.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }
            if !origAlpha.isEmpty {
                // If it was just one of the phrases with credits (e.g. "Субтитры сделал DimaTorzok"), and the user spoke just that, return it
                return trimmed
            }
            return ""
        }

        return result
    }

    /// Removes filler words (эээ, ну, типа, uh, um, etc.) and duplicate adjacent words.
    public static func removeFillerWordsAndDuplicates(_ text: String) -> String {
        guard !text.isEmpty else { return text }
        
        var result = text

        // 1. Remove interjection filler patterns (standalone or surrounded by punctuation/spaces)
        let fillerRegexes = [
            "\\b(?i)(эээ+|ээ+|э-э|гмм+|ммм+|э-мм+|uh+|um+|err+|ahh+)\\b",
            "(?<=^|\\s)(?i)(ну|типа|как бы|короче)(?=\\s|\\,|\\.|\\!|\\?|$)"
        ]

        for pattern in fillerRegexes {
            result = result.replacingOccurrences(
                of: pattern,
                with: "",
                options: .regularExpression
            )
        }

        // 2. Remove duplicate consecutive words (e.g. "мы мы пошли" -> "мы пошли", "I I think" -> "I think")
        let duplicateWordRegex = "\\b(\\w+)\\s+\\1\\b"
        result = result.replacingOccurrences(
            of: duplicateWordRegex,
            with: "$1",
            options: [.regularExpression, .caseInsensitive]
        )

        // 3. Clean up leading/trailing punctuation artifacts
        result = result.replacingOccurrences(of: "\\s+,", with: ",", options: .regularExpression)
        result = result.replacingOccurrences(of: "\\s+\\.", with: ".", options: .regularExpression)
        result = result.replacingOccurrences(of: ",,", with: ",")
        result = result.replacingOccurrences(of: "\\s{2,}", with: " ", options: .regularExpression)

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Checks if the transcribed text is a voice cancellation command.
    public static func isVoiceCancelCommand(_ text: String) -> Bool {
        let cleaned = text.trimmingCharacters(in: CharacterSet.alphanumerics.inverted).lowercased()
        let cancelKeywords = [
            "отмена", "отмени", "стереть", "сброс", "не надо", "удали", "забудь",
            "cancel", "nevermind", "erase", "scratch that", "abort", "reset"
        ]
        return cancelKeywords.contains(cleaned)
    }
}

// MARK: - Vocabulary Preset

public struct VocabularyPreset: Identifiable, Codable, Equatable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var description: String
    public var words: [String]
    public var shareCode: String
    public var createdAt: Date
    public var category: String // "vocabulary" or "blocked"
    
    public init(id: UUID = UUID(), name: String, description: String = "", words: [String], shareCode: String? = nil, createdAt: Date = Date(), category: String = "vocabulary") {
        self.id = id
        self.name = name
        self.description = description
        self.words = words
        self.shareCode = shareCode ?? Self.generateShareCode(category: category)
        self.createdAt = createdAt
        self.category = category
    }
    
    public static func generateShareCode(category: String = "vocabulary") -> String {
        let prefix: String
        switch category {
        case "blocked": prefix = "scr_blk_"
        case "location": prefix = "scr_loc_"
        default: prefix = "scr_"
        }
        let chars = "abcdefghijklmnopqrstuvwxyz0123456789"
        let randomChars = String((0..<16).compactMap { _ in chars.randomElement() })
        return "\(prefix)\(randomChars)"
    }
    
    /// Encodes preset to a full standalone share string that can be shared across any machine
    public func toExportCode() -> String {
        struct Payload: Codable {
            let n: String
            let d: String
            let w: [String]
            let c: String
            let cat: String?
        }
        let payload = Payload(n: name, d: description, w: words, c: shareCode, cat: category)
        if let data = try? JSONEncoder().encode(payload) {
            let base64 = data.base64EncodedString()
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_")
                .trimmingCharacters(in: CharacterSet(charactersIn: "="))
            let prefix: String
            switch category {
            case "blocked": prefix = "scr_blk_"
            case "location": prefix = "scr_loc_"
            default: prefix = "scr_"
            }
            return "\(prefix)\(base64)"
        }
        return shareCode
    }
    
    /// Decodes a share code (either short share code or base64 packed payload)
    public static func fromExportCode(_ rawCode: String) -> VocabularyPreset? {
        let trimmed = rawCode.trimmingCharacters(in: .whitespacesAndNewlines)
        let isBlocked = trimmed.hasPrefix("scr_blk_")
        let isLocation = trimmed.hasPrefix("scr_loc_")
        let prefixLength: Int
        if isBlocked || isLocation {
            prefixLength = 8
        } else {
            prefixLength = 4
        }
        guard trimmed.hasPrefix("scr_") || isBlocked || isLocation else { return nil }
        let payloadString = String(trimmed.dropFirst(prefixLength))
        
        // Try decoding as packed base64 payload
        var base64 = payloadString
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 {
            base64.append("=")
        }
        
        if let data = Data(base64Encoded: base64) {
            struct Payload: Codable {
                let n: String
                let d: String
                let w: [String]
                let c: String
                let cat: String?
            }
            if let decoded = try? JSONDecoder().decode(Payload.self, from: data) {
                let defaultCategory = isBlocked ? "blocked" : (isLocation ? "location" : "vocabulary")
                let detectedCategory = decoded.cat ?? defaultCategory
                return VocabularyPreset(name: decoded.n, description: decoded.d, words: decoded.w, shareCode: decoded.c, category: detectedCategory)
            }
        }
        
        return nil
    }
}

// MARK: - Text Replacer

struct Replacement: Identifiable, Codable, Equatable {
    var id: UUID
    var phrase: String
    var replacement: String
    
    init(id: UUID = UUID(), phrase: String, replacement: String) {
        self.id = id
        self.phrase = phrase
        self.replacement = replacement
    }
}

final class TextReplacer {
    /// Built-in vocabulary terms auto-cased & recognized natively
    public static let builtInVocabulary: [String] = [
        "swag", "топчик", "анскилл", "skill", "MCP", "viperr", "Kai Angel", "9mice",
        "Claude Code", "Antigravity", "Ollama", "PyTorch", "Supabase", "SwiftData",
        "Docker", "Kubernetes", "Next.js", "Rust", "WhisperKit",
        "HuggingFace", "Vercel", "TailwindCSS", "PostgreSQL", "GraphQL",
        "TypeScript", "LLM", "Llama", "LangChain", "OpenAI"
    ]

    static let defaultPhoneticReplacements: [Replacement] = [
        Replacement(phrase: "аджанскребатор", replacement: "транскрибатор"),
        Replacement(phrase: "транскребатор", replacement: "транскрибатор"),
        Replacement(phrase: "транскребация", replacement: "транскрибация"),
        Replacement(phrase: "скребация", replacement: "транскрибация"),
        Replacement(phrase: "трескребация", replacement: "транскрибация"),
        Replacement(phrase: "раскребация", replacement: "транскрибация"),
        Replacement(phrase: "трескребаться", replacement: "транскрибировать"),
        Replacement(phrase: "тридцать кибаксов", replacement: "транскрибатор"),
        Replacement(phrase: "ликвит глаз", replacement: "Liquid Glass"),
        Replacement(phrase: "ликвид глаз", replacement: "Liquid Glass"),
        Replacement(phrase: "лайф привью", replacement: "Live Preview"),
        Replacement(phrase: "лайфпривью", replacement: "Live Preview"),
        Replacement(phrase: "антиградик", replacement: "Antigravity"),
        Replacement(phrase: "анти гравити", replacement: "Antigravity"),
        Replacement(phrase: "антигравити", replacement: "Antigravity"),
        Replacement(phrase: "anti gravity", replacement: "Antigravity"),
        Replacement(phrase: "antigravity", replacement: "Antigravity"),
        Replacement(phrase: "google antigravity", replacement: "Google Antigravity"),
        Replacement(phrase: "google anti-gravity", replacement: "Google Antigravity"),
        Replacement(phrase: "пейпер клип", replacement: "Paperclip"),
        Replacement(phrase: "пейперклип", replacement: "Paperclip"),
        Replacement(phrase: "уфлотинг пил", replacement: "Floating Pill"),
        Replacement(phrase: "флотинг пил", replacement: "Floating Pill"),
        
        // Slang & Music & Community terms
        Replacement(phrase: "top chick", replacement: "топчик"),
        Replacement(phrase: "top chic", replacement: "топчик"),
        Replacement(phrase: "топ чик", replacement: "топчик"),
        Replacement(phrase: "topchik", replacement: "топчик"),
        Replacement(phrase: "топчик", replacement: "топчик"),
        Replacement(phrase: "свэг", replacement: "swag"),
        Replacement(phrase: "свэгг", replacement: "swag"),
        Replacement(phrase: "swagg", replacement: "swag"),
        Replacement(phrase: "ан скилл", replacement: "анскилл"),
        Replacement(phrase: "ан скил", replacement: "анскилл"),
        Replacement(phrase: "анскил", replacement: "анскилл"),
        Replacement(phrase: "unskill", replacement: "анскилл"),
        Replacement(phrase: "эм си пи", replacement: "MCP"),
        Replacement(phrase: "эмсипи", replacement: "MCP"),
        Replacement(phrase: "вайпер", replacement: "viperr"),
        Replacement(phrase: "вайперр", replacement: "viperr"),
        Replacement(phrase: "viper", replacement: "viperr"),
        Replacement(phrase: "Viperr", replacement: "viperr"),
        Replacement(phrase: "кай энджел", replacement: "Kai Angel"),
        Replacement(phrase: "кай ангел", replacement: "Kai Angel"),
        Replacement(phrase: "кайэнджел", replacement: "Kai Angel"),
        Replacement(phrase: "kai angel", replacement: "Kai Angel"),
        Replacement(phrase: "девять майс", replacement: "9mice"),
        Replacement(phrase: "9 майс", replacement: "9mice"),
        Replacement(phrase: "nine mice", replacement: "9mice"),
        Replacement(phrase: "9mice", replacement: "9mice")
    ]

    /// Common Whisper hallucination artifacts and subtitle credits that should never appear in transcriptions
    public static let defaultWhisperHallucinations: [String] = [
        "Субтитры сделал",
        "Субтитры создавал",
        "Субтитры добавил",
        "Редактор субтитров",
        "Корректор",
        "Продолжение следует",
        "Спасибо за просмотр",
        "Ставьте лайки",
        "Подписывайтесь на канал",
        "Amara.org",
        "Subtitles by",
        "Thank you for watching",
        "Translated by"
    ]

    /// Applies default phonetic replacements, custom replacements, vocabulary auto-casing, and blocked words filtering.
    static func apply(replacements: [Replacement], vocabulary: String = "", blockedWords: String = "", blockedAction: String = "remove", to text: String) -> String {
        let allReplacements = defaultPhoneticReplacements + replacements
        var result = text

        // 1. Phonetic & Custom replacements
        for r in allReplacements {
            guard !r.phrase.isEmpty else { continue }
            result = result.replacingOccurrences(of: r.phrase, with: r.replacement, options: .caseInsensitive)
        }

        // 2. Vocabulary Auto-Casing & Aether Fuzzy Alignment (Stage C)
        let userVocabItems = vocabulary.components(separatedBy: CharacterSet(charactersIn: ",\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let allVocabItems = builtInVocabulary + userVocabItems
        result = AetherFuzzyMatcher.shared.realign(text: result, vocabulary: allVocabItems)

        // 3. Blocked / Excluded Words filtering
        let blockedItems = blockedWords.components(separatedBy: CharacterSet(charactersIn: ",\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        for blocked in blockedItems {
            let escaped = NSRegularExpression.escapedPattern(for: blocked)
            let regexPattern = "(?i)\\b\(escaped)\\b"
            if blockedAction == "mask" {
                let maskString = String(repeating: "*", count: max(3, blocked.count))
                result = result.replacingOccurrences(of: regexPattern, with: maskString, options: .regularExpression)
            } else {
                result = result.replacingOccurrences(of: regexPattern, with: "", options: .regularExpression)
            }
        }

        // Clean up any double spaces or orphan punctuation resulting from removals
        if blockedAction == "remove" && !blockedItems.isEmpty {
            result = result.replacingOccurrences(of: "\\s{2,}", with: " ", options: .regularExpression)
            result = result.replacingOccurrences(of: "\\s+([.,!?:;])", with: "$1", options: .regularExpression)
            result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return result
    }
}

// MARK: - Cloud AI Service & Types

public enum CloudAIProvider: String, CaseIterable, Identifiable, Sendable {
    case groq = "groq"
    case openAI = "openai"
    case scribeCloud = "scribe_cloud"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .groq:        return "Groq AI (Ultra Fast)"
        case .openAI:      return "OpenAI (Whisper & GPT-4o)"
        case .scribeCloud: return "Scribe Pro Cloud"
        }
    }
}

public enum AIRefinementMode: String, CaseIterable, Identifiable, Sendable {
    case raw = "raw"
    case summary = "summary"
    case executive = "executive"
    case actionItems = "action_items"
    case translation = "translation"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .raw:         return "Raw Text"
        case .summary:     return "Key Summary"
        case .executive:   return "Executive Tone"
        case .actionItems: return "Action Items"
        case .translation: return "English Translation"
        }
    }

    public var icon: String {
        switch self {
        case .raw:         return "text.quote"
        case .summary:     return "sparkles"
        case .executive:   return "briefcase.fill"
        case .actionItems: return "checkmark.square.fill"
        case .translation: return "globe"
        }
    }

    public var promptInstruction: String? {
        let strictRule = " CRITICAL REQUIREMENT: Output ONLY the final result text directly. Never include preambles, intros (e.g. 'Here is...'), conversational filler, explanations, greetings, or multiple options. Output exactly ONE single final refined text."
        switch self {
        case .raw:
            return nil
        case .summary:
            return "Summarize the following speech into a clean, well-formatted bullet list of key takeaways. Retain important names, facts, and numbers." + strictRule
        case .executive:
            return "Rephrase the following speech into a single professional, polished executive business text. Fix grammatical errors and remove filler expressions." + strictRule
        case .actionItems:
            return "Extract clear, actionable tasks and TODOs from the following speech into a structured list of action items with checkboxes." + strictRule
        case .translation:
            return "Translate the following speech into fluent, accurate English while maintaining its original meaning and context." + strictRule
        }
    }
}

public final class CloudAIService: @unchecked Sendable {
    public static let shared = CloudAIService()
    private init() {}

    /// Performs Cloud Transcription using Groq API or OpenAI API
    public func transcribeAudio(
        audioURL: URL,
        provider: CloudAIProvider,
        apiKey: String,
        language: String? = nil
    ) async throws -> String {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            throw NSError(domain: "CloudAIService", code: 401, userInfo: [NSLocalizedDescriptionKey: "API key is missing"])
        }

        let endpoint: URL
        switch provider {
        case .groq:
            endpoint = URL(string: "https://api.groq.com/openai/v1/audio/transcriptions")!
        case .openAI, .scribeCloud:
            endpoint = URL(string: "https://api.openai.com/v1/audio/transcriptions")!
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(trimmedKey)", forHTTPHeaderField: "Authorization")

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var data = Data()
        let audioData = try Data(contentsOf: audioURL)

        // File field
        data.append("--\(boundary)\r\n".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.m4a\"\r\n".data(using: .utf8)!)
        data.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        data.append(audioData)
        data.append("\r\n".data(using: .utf8)!)

        // Model field
        let modelName = provider == .groq ? "whisper-large-v3-turbo" : "whisper-1"
        data.append("--\(boundary)\r\n".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        data.append("\(modelName)\r\n".data(using: .utf8)!)

        if let lang = language, lang != "auto" {
            data.append("--\(boundary)\r\n".data(using: .utf8)!)
            data.append("Content-Disposition: form-data; name=\"language\"\r\n\r\n".data(using: .utf8)!)
            data.append("\(lang)\r\n".data(using: .utf8)!)
        }

        data.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = data

        let (responseData, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            let errorMsg = String(data: responseData, encoding: .utf8) ?? "HTTP Error"
            throw NSError(domain: "CloudAIService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Cloud API Error: \(errorMsg)"])
        }

        if let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
           let text = json["text"] as? String {
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        throw NSError(domain: "CloudAIService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to parse response"])
    }

    /// Performs LLM Voice Refinement (Auto-Summary, Executive Tone, Action Items)
    public func refineText(
        text: String,
        mode: AIRefinementMode,
        provider: CloudAIProvider,
        apiKey: String
    ) async throws -> String {
        guard let instruction = mode.promptInstruction else { return text }
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else { return text }

        let endpoint: URL
        let modelName: String

        switch provider {
        case .groq:
            endpoint = URL(string: "https://api.groq.com/openai/v1/chat/completions")!
            modelName = "llama-3.3-70b-versatile"
        case .openAI, .scribeCloud:
            endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!
            modelName = "gpt-4o-mini"
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(trimmedKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": modelName,
            "messages": [
                ["role": "system", "content": instruction],
                ["role": "user", "content": text]
            ],
            "temperature": 0.3
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (responseData, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            _ = String(data: responseData, encoding: .utf8) ?? "LLM Error"
            return text
        }

        if let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
           let choices = json["choices"] as? [[String: Any]],
           let firstChoice = choices.first,
           let message = firstChoice["message"] as? [String: Any],
           let content = message["content"] as? String {
            return content.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return text
    }
}

// MARK: - Auth & Subscription System

public enum SubscriptionTier: String, Codable, Sendable, CaseIterable {
    case base = "base"
    case pro = "pro"

    public var displayName: String {
        switch self {
        case .base: return "Scribe Base"
        case .pro:  return "Scribe Pro + Cloud AI ✨"
        }
    }

    public var description: String {
        switch self {
        case .base: return "Local Whisper dictation, text replacements, notes integrations, offline privacy."
        case .pro:  return "All Base features + Ultra-fast Cloud AI, LLM text refinement (summaries, executive tone, TODOs) & Cloud Sync."
        }
    }
}

public struct AuthUser: Codable, Identifiable, Sendable {
    public let id: String
    public let email: String
    public let name: String
    public let avatarURL: String?
    public var subscriptionTier: SubscriptionTier
    public var subscriptionExpiresAt: Date?

    public var initials: String {
        let components = name.components(separatedBy: " ")
        if components.count >= 2, let first = components.first?.first, let last = components.last?.first {
            return "\(first)\(last)".uppercased()
        } else if let first = name.first {
            return String(first).uppercased()
        }
        return "S"
    }
}

