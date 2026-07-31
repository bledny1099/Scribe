import Foundation
import WhisperKit
import os.log

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

    /// Initial prompt that conditions Whisper to produce punctuation and recognise common brand names.
    /// Whisper uses this as "previous context" so it learns the expected output style.
    private let initialPrompt: [String: String] = [
        "en": "Hello, welcome! Terms: Bybit, Binance, Coinbase, MetaMask, Ethereum, Solana, Tether, FinTech, cringe, rofl, chill, based. Let's begin.",
        "ru": "Привет, добро пожаловать! Термины: Bybit, Binance, Coinbase, MetaMask, Ethereum, Solana, Tether, FinTech, кринж, рофл, чилл, база, вайб. Давайте начнём.",
        "es": "¡Hola, bienvenidos! Términos: Bybit, Binance, Coinbase, MetaMask, Ethereum, Solana, Tether, FinTech, cringe, rofl. Comencemos.",
        "de": "Hallo, willkommen! Begriffe: Bybit, Binance, Coinbase, MetaMask, Ethereum, Solana, Tether, FinTech, cringe, rofl. Fangen wir an.",
        "fr": "Bonjour, bienvenue ! Termes: Bybit, Binance, Coinbase, MetaMask, Ethereum, Solana, Tether, FinTech, cringe, rofl. Commençons.",
        "it": "Ciao, benvenuti! Termini: Bybit, Binance, Coinbase, MetaMask, Ethereum, Solana, Tether, FinTech, cringe, rofl. Cominciamo.",
        "zh": "你好，欢迎！术语：Bybit, Binance, Coinbase, MetaMask, Ethereum, Solana, Tether, FinTech, cringe, rofl。我们开始吧。",
        "ja": "こんにちは、ようこそ！用語：Bybit, Binance, Coinbase, MetaMask, Ethereum, Solana, Tether, FinTech, cringe, rofl。始めましょう。",
        "pt": "Olá, bem-vindos! Termos: Bybit, Binance, Coinbase, MetaMask, Ethereum, Solana, Tether, FinTech, cringe, rofl. Vamos começar.",
        "tr": "Merhaba, hoş geldiniz! Terimler: Bybit, Binance, Coinbase, MetaMask, Ethereum, Solana, Tether, FinTech, cringe, rofl. Başlayalım.",
        "uk": "Привіт, ласкаво просимо! Терміни: Bybit, Binance, Coinbase, MetaMask, Ethereum, Solana, Tether, FinTech, крінж, рофл, чіл, вайб. Почнімо.",
        "auto": "Hello, welcome! Terms: Bybit, Binance, Coinbase, MetaMask, Ethereum, Solana, Tether, FinTech, cringe, rofl, chill. Let's begin."
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

    // MARK: - Transcription

    /// Transcribes the audio file at `audioURL` using the specified language (nil for auto-detect).
    @MainActor
    func transcribe(
        audioURL: URL,
        modelName: String = "openai_whisper-small",
        language: String? = nil,
        autoTranslate: Bool = false
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
        let promptText = initialPrompt[langKey] ?? initialPrompt["auto"]!
        if let tokenizer = kit.tokenizer {
            let tokens = tokenizer.encode(text: promptText)
            options.promptTokens = tokens
            // Must disable prefill cache when using promptTokens (WhisperKit limitation)
            options.usePrefillCache = false
            logger.debug("Set initial prompt (\(tokens.count) tokens) for language '\(langKey)'")
        }

        // Capture the kit reference and path before crossing isolation boundary
        let path = audioURL.path
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

