import Foundation
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
        "en": "Terms: Bybit, Binance, MetaMask, Solana, TikTok, Instagram, YouTube, Snapchat, Telegram, Viber, ChatGPT, Gemini, Claude, Kimi, Perplexity, Midjourney, OpenAI, paperclip-ai.",
        "ru": "Термины: Bybit, Binance, MetaMask, Solana, TikTok, Instagram, YouTube, Snapchat, Telegram, Viber, ChatGPT, Gemini, Claude, Kimi, Perplexity, Midjourney, OpenAI, paperclip-ai. Я зашел в dashboard и там нету API-ключей.",
        "es": "Términos: Bybit, Binance, MetaMask, Solana, TikTok, Instagram, YouTube, Snapchat, Telegram, Viber, ChatGPT, Gemini, Claude, Kimi, Perplexity, Midjourney, OpenAI, paperclip-ai.",
        "de": "Begriffe: Bybit, Binance, MetaMask, Solana, TikTok, Instagram, YouTube, Snapchat, Telegram, Viber, ChatGPT, Gemini, Claude, Kimi, Perplexity, Midjourney, OpenAI, paperclip-ai.",
        "fr": "Termes: Bybit, Binance, MetaMask, Solana, TikTok, Instagram, YouTube, Snapchat, Telegram, Viber, ChatGPT, Gemini, Claude, Kimi, Perplexity, Midjourney, OpenAI, paperclip-ai.",
        "it": "Termini: Bybit, Binance, MetaMask, Solana, TikTok, Instagram, YouTube, Snapchat, Telegram, Viber, ChatGPT, Gemini, Claude, Kimi, Perplexity, Midjourney, OpenAI, paperclip-ai.",
        "zh": "术语：Bybit, Binance, MetaMask, Solana, TikTok, Instagram, YouTube, Snapchat, Telegram, Viber, ChatGPT, Gemini, Claude, Kimi, Perplexity, Midjourney, OpenAI, paperclip-ai.",
        "ja": "用語：Bybit, Binance, MetaMask, Solana, TikTok, Instagram, YouTube, Snapchat, Telegram, Viber, ChatGPT, Gemini, Claude, Kimi, Perplexity, Midjourney, OpenAI, paperclip-ai.",
        "pt": "Termos: Bybit, Binance, MetaMask, Solana, TikTok, Instagram, YouTube, Snapchat, Telegram, Viber, ChatGPT, Gemini, Claude, Kimi, Perplexity, Midjourney, OpenAI, paperclip-ai.",
        "tr": "Terimler: Bybit, Binance, MetaMask, Solana, TikTok, Instagram, YouTube, Snapchat, Telegram, Viber, ChatGPT, Gemini, Claude, Kimi, Perplexity, Midjourney, OpenAI, paperclip-ai.",
        "uk": "Терміни: Bybit, Binance, MetaMask, Solana, TikTok, Instagram, YouTube, Snapchat, Telegram, Viber, ChatGPT, Gemini, Claude, Kimi, Perplexity, Midjourney, OpenAI, paperclip-ai. Я зашел в dashboard и там нету API-ключей.",
        "auto": "Terms: Bybit, Binance, MetaMask, Solana, TikTok, Instagram, YouTube, Snapchat, Telegram, Viber, ChatGPT, Gemini, Claude, Kimi, Perplexity, Midjourney, OpenAI, paperclip-ai. Я зашел в dashboard и там нету API-ключей."
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
    func startStreaming(language: String?, customVocabulary: String = "", onUpdate: @escaping (String) -> Void) throws {
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
        // Try to enable on-device recognition for privacy/speed, if available
        if #available(macOS 13.0, *) {
            if recognizer.supportsOnDeviceRecognition {
                request.requiresOnDeviceRecognition = true
            }
        }
        var strings = [
            "ChatGPT", "Claude", "paperclip-ai", "dashboard", "API-ключей",
            "Bybit", "Binance", "MetaMask", "Solana", "TikTok", "Instagram",
            "YouTube", "Snapchat", "Telegram", "Viber", "Gemini", "Kimi",
            "Perplexity", "Midjourney", "OpenAI"
        ]
        
        let customVocabItems = customVocabulary.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        strings.append(contentsOf: customVocabItems)
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

    // MARK: - WhisperKit (File-based)

    /// Transcribes the audio file at `audioURL` using the specified language (nil for auto-detect).
    @MainActor
    func transcribe(
        audioURL: URL,
        modelName: String = "openai_whisper-small",
        language: String? = nil,
        preferredLanguages: [String] = [],
        autoTranslate: Bool = false,
        customVocabulary: String = ""
    ) async throws -> String {
        try await ensureModelLoaded(modelName: modelName)

        state = .transcribing
        logger.info("Transcribing: \(audioURL.lastPathComponent), model: \(modelName), language: \(language ?? "auto-detect"), translate: \(autoTranslate)")

        guard let kit = whisperKit else {
            let err = TranscriptionError.modelNotLoaded
            state = .error(err.localizedDescription)
            throw err
        }

        // Configure DecodingOptions for multi-language transcription or translation to English
        let baseLang = language != nil ? baseLanguageCode(for: language!) : "auto"
        let langKey = baseLang
        var options = DecodingOptions(task: autoTranslate ? .translate : .transcribe)
        if baseLang != "auto" {
            options.language = baseLang
            options.detectLanguage = false
        } else {
            options.language = nil
            options.detectLanguage = true
        }

        // Encode the initial prompt as tokens — this conditions Whisper to:
        // 1. Use proper punctuation (commas, periods, exclamation marks)
        // 2. Correctly spell known brand names (Bybit, Binance, etc.)
        var promptText = initialPrompt[langKey] ?? initialPrompt["auto"]!
        if !customVocabulary.isEmpty {
            promptText += " \(customVocabulary)."
        }
        if let tokenizer = kit.tokenizer {
            let tokens = tokenizer.encode(text: promptText)
            // WhisperKit prompt tokens must be less than 224 to avoid crashing
            options.promptTokens = Array(tokens.suffix(min(tokens.count, 200)))
            // Must disable prefill cache when using promptTokens (WhisperKit limitation)
            options.usePrefillCache = false
            logger.debug("Set initial prompt (\(tokens.count) tokens) for language '\(langKey)'")
        }

        // Capture the kit reference and path before crossing isolation boundary
        let path = audioURL.path
        
        // Custom Language Detection with Preferred Languages
        if options.detectLanguage, !preferredLanguages.isEmpty {
            do {
                let (detectedLang, langProbs) = try await kit.detectLanguage(audioPath: path)
                logger.info("Auto-detected language: \(detectedLang)")
                
                let basePreferred = preferredLanguages.map { baseLanguageCode(for: $0) }
                let bestLang = basePreferred.max { (langProbs[$0] ?? -Float.greatestFiniteMagnitude) < (langProbs[$1] ?? -Float.greatestFiniteMagnitude) }
                
                if let bestLang = bestLang, let bestProb = langProbs[bestLang] {
                    logger.info("Overriding auto-detect with preferred language: \(bestLang) (prob: \(bestProb))")
                    options.language = bestLang
                    options.detectLanguage = false
                }
            } catch {
                logger.warning("Custom language detection failed: \(error)")
            }
        }
        
        logger.debug("Calling WhisperKit.transcribe(audioPath: \(path), language: \(options.language ?? "auto"))")

        let results: [TranscriptionResult] = try await Task.detached {
            try await kit.transcribe(audioPath: path, decodeOptions: options)
        }.value

        logger.info("WhisperKit returned \(results.count) result(s)")

        let rawText = results.map(\.text).joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Strip non-speech annotations that Whisper sometimes inserts,
        // e.g. [keyboard clicking], (music), *laughs*, [BLANK_AUDIO]
        let text = Self.cleanTranscription(rawText)

        logger.info("Transcribed text (\(text.count) chars): \(text.prefix(100))")

        state = .done(text)
        return text
    }

    // MARK: - Post-Processing

    /// Removes non-speech annotations from Whisper output.
    /// Strips patterns like [text], (text), *text* that represent sound effects,
    /// background noise descriptions, or other non-verbal annotations.
    private static func cleanTranscription(_ text: String) -> String {
        var cleaned = text

        // Remove [bracketed annotations] — e.g. [keyboard clicking], [BLANK_AUDIO], [music]
        cleaned = cleaned.replacingOccurrences(
            of: "\\[([^\\]]*?)\\]",
            with: "",
            options: .regularExpression
        )

        // Remove (parenthesized annotations) — e.g. (music), (background noise)
        cleaned = cleaned.replacingOccurrences(
            of: "\\(([^)]*?)\\)",
            with: "",
            options: .regularExpression
        )

        // Remove *asterisk annotations* — e.g. *laughs*, *coughs*
        cleaned = cleaned.replacingOccurrences(
            of: "\\*([^*]*?)\\*",
            with: "",
            options: .regularExpression
        )

        // Collapse multiple spaces into one and trim
        cleaned = cleaned.replacingOccurrences(
            of: "\\s{2,}",
            with: " ",
            options: .regularExpression
        )
        .trimmingCharacters(in: .whitespacesAndNewlines)

        return cleaned
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
    /// Applies an array of replacements to a string.
    /// It performs case-insensitive word-boundary matching.
    static func apply(replacements: [Replacement], to text: String) -> String {
        var result = text
        for r in replacements {
            guard !r.phrase.isEmpty else { continue }
            
            // We use regex for word boundaries to avoid replacing parts of words.
            let escapedPhrase = NSRegularExpression.escapedPattern(for: r.phrase)
            
            // \b doesn't always work perfectly for all languages, but for simple snippet phrases it's usually fine.
            let pattern = "(?i)\\b\(escapedPhrase)\\b"
            
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: [])
                let range = NSRange(location: 0, length: result.utf16.count)
                
                result = regex.stringByReplacingMatches(
                    in: result,
                    options: [],
                    range: range,
                    withTemplate: NSRegularExpression.escapedTemplate(for: r.replacement)
                )
            } catch {
                // Fallback to simple replace if regex fails
                result = result.replacingOccurrences(of: r.phrase, with: r.replacement, options: .caseInsensitive)
            }
        }
        return result
    }
}
