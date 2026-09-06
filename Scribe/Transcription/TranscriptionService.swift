import Foundation
import AppKit
import WhisperKit
import os.log
@preconcurrency import Speech
@preconcurrency import AVFoundation

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
    private var modelLoadingTask: Task<Void, Error>?

    // Apple Speech State (Primary + Secondary for Multilingual Streaming)
    private var speechRecognizer: SFSpeechRecognizer?
    private var speechRequest: SFSpeechAudioBufferRecognitionRequest?
    private var speechTask: SFSpeechRecognitionTask?

    private var secondarySpeechRecognizer: SFSpeechRecognizer?
    private var secondarySpeechRequest: SFSpeechAudioBufferRecognitionRequest?
    private var secondarySpeechTask: SFSpeechRecognitionTask?

    private var currentStreamingText: String = ""
    private var primaryStreamingText: String = ""
    private var secondaryStreamingText: String = ""
    private var isSecondaryEnglish: Bool = false

    // Throttled streaming delivery timer
    private var streamingUpdateTimer: Timer?
    private var pendingStreamingText: String = ""
    private var lastStreamUpdateTime: Date = .distantPast

    // Resampler for streaming audio to standard 16kHz mono Float32 PCM
    private let streaming16kFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false)!
    private var audioConverter: AVAudioConverter?
    private var converterSourceFormat: AVAudioFormat?
    private let resamplerQueue = DispatchQueue(label: "com.aleksei.scribe.resampler")

    /// Maps a language code or identifier to a standard Apple Speech locale identifier.
    public static func localeIdentifier(for lang: String) -> String {
        let clean = lang.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        switch clean {
        case "ru", "ru-ru", "rus": return "ru-RU"
        case "en", "en-us", "eng": return "en-US"
        case "es", "es-es": return "es-ES"
        case "de", "de-de": return "de-DE"
        case "fr", "fr-fr": return "fr-FR"
        case "it", "it-it": return "it-IT"
        case "zh", "zh-cn": return "zh-CN"
        case "ja", "ja-jp": return "ja-JP"
        case "uk", "uk-ua": return "uk-UA"
        case "tr", "tr-tr": return "tr-TR"
        case "pt", "pt-pt", "pt-br": return "pt-BR"
        default: return clean.contains("-") ? clean : "\(clean)-\(clean.uppercased())"
        }
    }

    /// Initial prompt that conditions Whisper to produce punctuation and recognise common brand names.
    /// Whisper uses this as "previous context" so it learns the expected output style.
    private let initialPrompt: [String: String] = [
        "en": "Use proper punctuation, capitalization, commas, and natural sentence structures. Terms: Bybit, Binance, MetaMask, Solana, TikTok, Instagram, YouTube, Snapchat, Telegram, Viber, ChatGPT, Gemini, Claude, Kimi, Perplexity, Midjourney, OpenAI, paperclip-ai, Claude Code, Ollama, PyTorch, Supabase, SwiftData, Docker, Kubernetes, Next.js, Rust, WhisperKit, HuggingFace, Vercel, TailwindCSS, PostgreSQL, GraphQL, TypeScript, LLM, Llama, LangChain, Google, Antigravity, IDE, Scribe.",
        "ru": "Распознавай русскую речь связно и грамотно, сохраняя правильные падежи, окончания слов, предлоги и пунктуацию (запятые, точки, тире). Смешанная русско-английская речь разработчиков и пользователей: коммит, пулл реквест, PR, мердж, пуш, деплой, бэкенд, фронтенд, багфикс, релиз, прод, стейджинг, API, токен, промпт, контекст, репозиторий. Bybit, Binance, Telegram, ChatGPT, Gemini, Claude, OpenAI, Swift, SwiftUI, Xcode, Docker, Kubernetes, Next.js, Rust, WhisperKit, PostgreSQL, TypeScript, Python, LLM, Google, Antigravity, IDE, Scribe, транскрибатор, Хабр.",
        "es": "Términos: Bybit, Binance, MetaMask, Solana, TikTok, Instagram, YouTube, Snapchat, Telegram, Viber, ChatGPT, Gemini, Claude, Kimi, Perplexity, Midjourney, OpenAI, paperclip-ai, Claude Code, Ollama, PyTorch, Supabase, SwiftData, Docker, Kubernetes, Next.js, Rust, WhisperKit, HuggingFace, Vercel, TailwindCSS, PostgreSQL, GraphQL, TypeScript, LLM, Llama, LangChain, Google, Antigravity, IDE, Scribe.",
        "de": "Begriffe: Bybit, Binance, MetaMask, Solana, TikTok, Instagram, YouTube, Snapchat, Telegram, Viber, ChatGPT, Gemini, Claude, Kimi, Perplexity, Midjourney, OpenAI, paperclip-ai, Claude Code, Ollama, PyTorch, Supabase, SwiftData, Docker, Kubernetes, Next.js, Rust, WhisperKit, HuggingFace, Vercel, TailwindCSS, PostgreSQL, GraphQL, TypeScript, LLM, Llama, LangChain, Google, Antigravity, IDE, Scribe.",
        "fr": "Termes: Bybit, Binance, MetaMask, Solana, TikTok, Instagram, YouTube, Snapchat, Telegram, Viber, ChatGPT, Gemini, Claude, Kimi, Perplexity, Midjourney, OpenAI, paperclip-ai, Claude Code, Ollama, PyTorch, Supabase, SwiftData, Docker, Kubernetes, Next.js, Rust, WhisperKit, HuggingFace, Vercel, TailwindCSS, PostgreSQL, GraphQL, TypeScript, LLM, Llama, LangChain, Google, Antigravity, IDE, Scribe.",
        "it": "Termini: Bybit, Binance, MetaMask, Solana, TikTok, Instagram, YouTube, Snapchat, Telegram, Viber, ChatGPT, Gemini, Claude, Kimi, Perplexity, Midjourney, OpenAI, paperclip-ai, Claude Code, Ollama, PyTorch, Supabase, SwiftData, Docker, Kubernetes, Next.js, Rust, WhisperKit, HuggingFace, Vercel, TailwindCSS, PostgreSQL, GraphQL, TypeScript, LLM, Llama, LangChain, Google, Antigravity, IDE, Scribe.",
        "zh": "术语：Bybit, Binance, MetaMask, Solana, TikTok, Instagram, YouTube, Snapchat, Telegram, Viber, ChatGPT, Gemini, Claude, Kimi, Perplexity, Midjourney, OpenAI, paperclip-ai, Claude Code, Ollama, PyTorch, Supabase, SwiftData, Docker, Kubernetes, Next.js, Rust, WhisperKit, HuggingFace, Vercel, TailwindCSS, PostgreSQL, GraphQL, TypeScript, LLM, Llama, LangChain, Google, Antigravity, IDE, Scribe.",
        "ja": "用語：Bybit, Binance, MetaMask, Solana, TikTok, Instagram, YouTube, Snapchat, Telegram, Viber, ChatGPT, Gemini, Claude, Kimi, Perplexity, Midjourney, OpenAI, paperclip-ai, Claude Code, Ollama, PyTorch, Supabase, SwiftData, Docker, Kubernetes, Next.js, Rust, WhisperKit, HuggingFace, Vercel, TailwindCSS, PostgreSQL, GraphQL, TypeScript, LLM, Llama, LangChain, Google, Antigravity, IDE, Scribe.",
        "pt": "Termos: Bybit, Binance, MetaMask, Solana, TikTok, Instagram, YouTube, Snapchat, Telegram, Viber, ChatGPT, Gemini, Claude, Kimi, Perplexity, Midjourney, OpenAI, paperclip-ai, Claude Code, Ollama, PyTorch, Supabase, SwiftData, Docker, Kubernetes, Next.js, Rust, WhisperKit, HuggingFace, Vercel, TailwindCSS, PostgreSQL, GraphQL, TypeScript, LLM, Llama, LangChain, Google, Antigravity, IDE, Scribe.",
        "tr": "Terimler: Bybit, Binance, MetaMask, Solana, TikTok, Instagram, YouTube, Snapchat, Telegram, Viber, ChatGPT, Gemini, Claude, Kimi, Perplexity, Midjourney, OpenAI, paperclip-ai, Claude Code, Ollama, PyTorch, Supabase, SwiftData, Docker, Kubernetes, Next.js, Rust, WhisperKit, HuggingFace, Vercel, TailwindCSS, PostgreSQL, GraphQL, TypeScript, LLM, Llama, LangChain, Google, Antigravity, IDE, Scribe.",
        "uk": "Терміни: Bybit, Binance, MetaMask, Solana, TikTok, Instagram, YouTube, Snapchat, Telegram, Viber, ChatGPT, Gemini, Claude, Kimi, Perplexity, Midjourney, OpenAI, paperclip-ai, Claude Code, Ollama, PyTorch, Supabase, SwiftData, Docker, Kubernetes, Next.js, Rust, WhisperKit, HuggingFace, Vercel, TailwindCSS, PostgreSQL, GraphQL, TypeScript, LLM, Llama, LangChain, Google, Antigravity, IDE, Scribe.",
        "auto": "Естественная русская и английская речь с правильными падежами, окончаниями, предлогами и пунктуацией. Fluent Russian and English code-switching. Terms: Bybit, Telegram, ChatGPT, Gemini, Claude, OpenAI, Swift, SwiftUI, Xcode, Docker, Kubernetes, TypeScript, Python, LLM, commit, pull request, merge, push, deploy, bugfix, backend, frontend, Google, Antigravity, Scribe."
    ]

    /// Resolves on-disk path for pre-downloaded WhisperKit CoreML model folders
    public static func localModelFolder(for modelName: String) -> String? {
        let fileManager = FileManager.default
        let searchRoots = [
            fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?.appendingPathComponent("huggingface/models/argmaxinc/whisperkit-coreml"),
            fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first?.appendingPathComponent("huggingface/models/argmaxinc/whisperkit-coreml")
        ].compactMap { $0 }

        for root in searchRoots {
            let candidate = root.appendingPathComponent(modelName)
            if fileManager.fileExists(atPath: candidate.path) {
                return candidate.path
            }
        }
        return nil
    }

    /// Resolves on-disk path for pre-downloaded HuggingFace Whisper tokenizer folders
    public static func localTokenizerFolder(for modelName: String) -> String? {
        let fileManager = FileManager.default
        let tokenizerBaseName: String
        if modelName.contains("large") {
            tokenizerBaseName = "whisper-large-v3"
        } else if modelName.contains("small") {
            tokenizerBaseName = "whisper-small"
        } else if modelName.contains("base") {
            tokenizerBaseName = "whisper-base"
        } else {
            tokenizerBaseName = "whisper-large-v3"
        }

        let searchRoots = [
            fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?.appendingPathComponent("huggingface/models/openai").appendingPathComponent(tokenizerBaseName),
            fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first?.appendingPathComponent("huggingface/models/openai").appendingPathComponent(tokenizerBaseName)
        ].compactMap { $0 }

        for root in searchRoots {
            if fileManager.fileExists(atPath: root.path) {
                return root.path
            }
        }
        return nil
    }

    // MARK: - Model Lifecycle

    /// Downloads / loads the model if it hasn't been loaded yet or if model changed.
    @MainActor
    func ensureModelLoaded(modelName: String = "openai_whisper-small") async throws {
        if whisperKit != nil && loadedModelName == modelName {
            logger.debug("Model \(modelName) already loaded, skipping")
            return
        }

        if let inFlight = modelLoadingTask, loadedModelName == modelName {
            logger.debug("Awaiting in-flight model loading task for \(modelName)…")
            try await inFlight.value
            return
        }

        state = .loadingModel
        logger.info("Loading WhisperKit model '\(modelName)'…")
        
        let task = Task.detached(priority: .userInitiated) {
            let config = WhisperKitConfig(model: modelName)
            if let folder = Self.localModelFolder(for: modelName) {
                config.modelFolder = folder
                logger.info("Using local WhisperKit model folder: \(folder)")
            }
            if let tokenizerFolder = Self.localTokenizerFolder(for: modelName) {
                config.tokenizerFolder = URL(fileURLWithPath: tokenizerFolder)
                logger.info("Using local WhisperKit tokenizer folder: \(tokenizerFolder)")
            }
            let kit = try await WhisperKit(config)
            await MainActor.run {
                self.whisperKit = kit
                self.loadedModelName = modelName
                self.state = .idle
                logger.info("WhisperKit model '\(modelName)' loaded successfully")
            }
        }
        modelLoadingTask = task
        loadedModelName = modelName

        do {
            try await task.value
            self.modelLoadingTask = nil
        } catch {
            self.modelLoadingTask = nil
            self.loadedModelName = nil
            await MainActor.run { self.state = .idle }
            logger.error("Failed to load WhisperKit model: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Apple Speech (Streaming for Live Preview)

    /// Convenience start streaming method supporting a single language or auto.
    @MainActor
    func startStreaming(language: String?, customVocabulary: String = "", userLocation: String = "", targetApp: NSRunningApplication? = nil, onUpdate: @escaping (String) -> Void) throws {
        let langs = language.map { [$0] } ?? ["ru", "en"]
        try startStreaming(languages: langs, customVocabulary: customVocabulary, userLocation: userLocation, targetApp: targetApp, onUpdate: onUpdate)
    }

    /// Starts streaming speech recognition with support for concurrent multilingual recognition (Russian + English).
    @MainActor
    func startStreaming(
        languages: [String],
        customVocabulary: String = "",
        userLocation: String = "",
        targetApp: NSRunningApplication? = nil,
        onUpdate: @escaping (String) -> Void
    ) throws {
        state = .transcribing
        currentStreamingText = ""
        primaryStreamingText = ""
        secondaryStreamingText = ""

        let contextualStrings = AetherContextEngine.shared.buildContextualStrings(
            customVocabulary: customVocabulary,
            userLocation: userLocation,
            targetApp: targetApp
        )

        let cleanedLangs = languages
            .map { $0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0 != "auto" }

        let primaryLang: String
        let secondaryLang: String?

        if cleanedLangs.isEmpty {
            primaryLang = "ru"
            secondaryLang = "en"
        } else if cleanedLangs.count == 1 {
            primaryLang = cleanedLangs[0]
            secondaryLang = nil
        } else {
            // Prioritize Russian as primary recognizer whenever present in multilingual selection
            if cleanedLangs.contains(where: { $0.starts(with: "ru") }) {
                primaryLang = "ru"
                secondaryLang = cleanedLangs.first(where: { !$0.starts(with: "ru") }) ?? "en"
            } else {
                primaryLang = cleanedLangs[0]
                secondaryLang = cleanedLangs.count > 1 ? cleanedLangs[1] : nil
            }
        }

        let primaryLocale = Locale(identifier: Self.localeIdentifier(for: primaryLang))
        guard let primaryRec = SFSpeechRecognizer(locale: primaryLocale) ?? SFSpeechRecognizer(locale: Locale(identifier: "ru-RU")) ?? SFSpeechRecognizer(locale: Locale.current), primaryRec.isAvailable else {
            throw TranscriptionError.modelNotLoaded
        }

        self.speechRecognizer = primaryRec
        let primaryReq = SFSpeechAudioBufferRecognitionRequest()
        primaryReq.shouldReportPartialResults = true
        primaryReq.taskHint = .dictation
        if #available(macOS 13, *) {
            primaryReq.addsPunctuation = true
        }
        if !contextualStrings.isEmpty {
            primaryReq.contextualStrings = contextualStrings
        }
        self.speechRequest = primaryReq

        self.speechTask = primaryRec.recognitionTask(with: primaryReq) { [weak self] result, error in
            guard let self = self else { return }
            if let result = result {
                let text = result.bestTranscription.formattedString
                Task { @MainActor in
                    self.primaryStreamingText = text
                    self.evaluateStreamingText(onUpdate: onUpdate)
                }
            }
            if let error = error {
                logger.debug("Apple Speech primary stream task: \(error.localizedDescription)")
            }
        }

        logger.info("Apple Speech primary stream started for locale \(primaryLocale.identifier)")

        // Configure secondary recognizer if dual language requested
        if let secLang = secondaryLang {
            let secLocale = Locale(identifier: Self.localeIdentifier(for: secLang))
            if let secRec = SFSpeechRecognizer(locale: secLocale), secRec.isAvailable {
                self.secondarySpeechRecognizer = secRec
                self.isSecondaryEnglish = secLang.starts(with: "en")
                let secReq = SFSpeechAudioBufferRecognitionRequest()
                secReq.shouldReportPartialResults = true
                secReq.taskHint = .dictation
                if #available(macOS 13, *) {
                    secReq.addsPunctuation = true
                }
                if !contextualStrings.isEmpty {
                    secReq.contextualStrings = contextualStrings
                }
                self.secondarySpeechRequest = secReq

                self.secondarySpeechTask = secRec.recognitionTask(with: secReq) { [weak self] result, error in
                    guard let self = self else { return }
                    if let result = result {
                        let text = result.bestTranscription.formattedString
                        Task { @MainActor in
                            self.secondaryStreamingText = text
                            self.evaluateStreamingText(onUpdate: onUpdate)
                        }
                    }
                    if let error = error {
                        logger.debug("Apple Speech secondary stream task: \(error.localizedDescription)")
                    }
                }
                logger.info("Apple Speech secondary stream started for locale \(secLocale.identifier)")
            }
        }
    }

    @MainActor
    private func evaluateStreamingText(onUpdate: @escaping (String) -> Void) {
        let prim = primaryStreamingText.trimmingCharacters(in: .whitespacesAndNewlines)
        let sec = secondaryStreamingText.trimmingCharacters(in: .whitespacesAndNewlines)

        let selected: String
        if sec.isEmpty {
            selected = prim
        } else if prim.isEmpty {
            selected = sec
        } else {
            let primHasCyrillic = prim.range(of: "\\p{Cyrillic}", options: .regularExpression) != nil
            let secHasCyrillic = sec.range(of: "\\p{Cyrillic}", options: .regularExpression) != nil

            if primHasCyrillic && !secHasCyrillic {
                // Russian speech detected by primary recognizer
                selected = prim
            } else if !primHasCyrillic && !secHasCyrillic && isSecondaryEnglish {
                // English speech: secondary English recognizer provides accurate Latin spelling
                selected = sec
            } else {
                // Default to whichever recognized more complete text
                selected = prim.count >= sec.count ? prim : sec
            }
        }

        guard !selected.isEmpty, selected != currentStreamingText else { return }
        pendingStreamingText = selected

        // Throttle updates to at most once per 220ms so live preview stays calm, readable, and doesn't flicker
        let now = Date()
        let elapsed = now.timeIntervalSince(lastStreamUpdateTime)
        if elapsed >= 0.22 {
            lastStreamUpdateTime = now
            currentStreamingText = selected
            onUpdate(selected)
        } else if streamingUpdateTimer == nil {
            let remaining = max(0.04, 0.22 - elapsed)
            streamingUpdateTimer = Timer.scheduledTimer(withTimeInterval: remaining, repeats: false) { [weak self] _ in
                guard let self = self else { return }
                self.streamingUpdateTimer = nil
                self.lastStreamUpdateTime = Date()
                let update = self.pendingStreamingText
                if update != self.currentStreamingText && !update.isEmpty {
                    self.currentStreamingText = update
                    onUpdate(update)
                }
            }
        }
    }

    private final class BufferHolder: @unchecked Sendable {
        let buffer: AVAudioPCMBuffer
        var isConsumed = false
        init(_ buffer: AVAudioPCMBuffer) {
            self.buffer = buffer
        }
    }

    /// Appends audio buffer, automatically resampling to 16,000 Hz mono PCM if needed.
    func append(_ buffer: AVAudioPCMBuffer) {
        guard speechRequest != nil || secondarySpeechRequest != nil else { return }

        let targetBuffer: AVAudioPCMBuffer = resamplerQueue.sync {
            if buffer.format == streaming16kFormat {
                return buffer
            }
            if audioConverter == nil || converterSourceFormat != buffer.format {
                audioConverter = AVAudioConverter(from: buffer.format, to: streaming16kFormat)
                converterSourceFormat = buffer.format
            }
            guard let converter = audioConverter else {
                return buffer
            }

            let ratio = 16000.0 / buffer.format.sampleRate
            let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio + 64)
            guard let converted = AVAudioPCMBuffer(pcmFormat: streaming16kFormat, frameCapacity: capacity) else {
                return buffer
            }

            let holder = BufferHolder(buffer)
            var convError: NSError?
            let status = converter.convert(to: converted, error: &convError) { _, outStatus in
                if !holder.isConsumed {
                    holder.isConsumed = true
                    outStatus.pointee = .haveData
                    return holder.buffer
                } else {
                    outStatus.pointee = .noDataNow
                    return nil
                }
            }

            if status != .error && converted.frameLength > 0 {
                return converted
            } else {
                return buffer
            }
        }

        speechRequest?.append(targetBuffer)
        secondarySpeechRequest?.append(targetBuffer)
    }
    
    @MainActor
    func stopStreaming() async -> String {
        streamingUpdateTimer?.invalidate()
        streamingUpdateTimer = nil

        speechRequest?.endAudio()
        secondarySpeechRequest?.endAudio()

        // Give a short 50ms window to drain pending results
        try? await Task.sleep(for: .milliseconds(50))

        let finalText = currentStreamingText
        speechTask?.cancel()
        speechTask = nil
        speechRequest = nil
        speechRecognizer = nil

        secondarySpeechTask?.cancel()
        secondarySpeechTask = nil
        secondarySpeechRequest = nil
        secondarySpeechRecognizer = nil

        resamplerQueue.sync {
            audioConverter = nil
            converterSourceFormat = nil
        }

        logger.info("Apple Speech streaming stopped. Final text: \(finalText)")
        return finalText
    }

    // MARK: - Interim Live Snapshot Transcription (Whisper / Neural Engine during speech)

    /// Fast greedy transcription of an in-flight audio snapshot for live preview updates while user is speaking.
    /// Runs on background cooperative pool without secondary passes or heavy post-processing.
    func transcribeSnapshot(
        audioURL: URL,
        modelName: String,
        language: String?
    ) async -> String? {
        guard let kit = whisperKit else { return nil }

        // Short-circuit if audio snapshot is silence to avoid unnecessary background neural inference
        guard let conditionedURL = AetherAudioConditioner.shared.condition(audioURL: audioURL) else {
            return nil
        }
        defer {
            if conditionedURL != audioURL {
                try? FileManager.default.removeItem(at: conditionedURL)
            }
        }

        var options = DecodingOptions(task: .transcribe)
        options.temperature = 0.0
        options.temperatureFallbackCount = 0
        options.withoutTimestamps = false
        options.skipSpecialTokens = true
        options.sampleLength = 224
        options.noSpeechThreshold = 0.6
        options.logProbThreshold = -1.0
        options.compressionRatioThreshold = 2.4
        if let lang = language, lang != "auto" {
            options.language = baseLanguageCode(for: lang)
            options.detectLanguage = false
        } else {
            options.language = nil
            options.detectLanguage = true
        }

        do {
            let results = try await kit.transcribe(audioPath: conditionedURL.path, decodeOptions: options)
            let text = results.map(\.text).joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? nil : text
        } catch {
            return nil
        }
    }

    // MARK: - Apple Speech (Offline / File Transcription - English Only)

    @MainActor
    func transcribeWithAppleSpeech(audioURL: URL, contextualStrings: [String] = []) async throws -> String {
        let englishLocale = Locale(identifier: "en-US")
        guard let recognizer = SFSpeechRecognizer(locale: englishLocale) ?? SFSpeechRecognizer(locale: Locale.current), recognizer.isAvailable else {
            throw TranscriptionError.modelNotLoaded
        }

        return try await withCheckedThrowingContinuation { continuation in
            var hasResponded = false
            var lastText = ""

            let request = SFSpeechURLRecognitionRequest(url: audioURL)
            request.shouldReportPartialResults = true
            request.taskHint = .dictation
            if #available(macOS 13, *) {
                request.addsPunctuation = true
            }
            if recognizer.supportsOnDeviceRecognition {
                request.requiresOnDeviceRecognition = true
            }
            if !contextualStrings.isEmpty {
                request.contextualStrings = contextualStrings
            }

            var task: SFSpeechRecognitionTask?
            task = recognizer.recognitionTask(with: request) { result, error in
                if hasResponded { return }

                if let result = result {
                    lastText = result.bestTranscription.formattedString
                    if result.isFinal {
                        hasResponded = true
                        continuation.resume(returning: lastText)
                        return
                    }
                }

                if let error = error {
                    hasResponded = true
                    if !lastText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        continuation.resume(returning: lastText)
                    } else {
                        continuation.resume(throwing: error)
                    }
                }
            }

            // Safety timeout: 15 seconds
            Task {
                try? await Task.sleep(for: .seconds(15))
                if !hasResponded {
                    hasResponded = true
                    task?.cancel()
                    continuation.resume(returning: lastText)
                }
            }
        }
    }

    // MARK: - WhisperKit (High Accuracy File Transcription)

    /// Transcribes the audio file at `audioURL` using the specified language (nil for auto-detect).
    /// Executes on background cooperative pool so MainActor/UI remains 100% fluid at 60 FPS.
    func transcribe(
        audioURL: URL,
        modelName: String = "openai_whisper-small",
        language: String? = nil,
        preferredLanguages: [String] = [],
        autoTranslate: Bool = false,
        customVocabulary: String = "",
        userLocation: String = "",
        targetApp: NSRunningApplication? = nil,
        recognitionEngine: String = "Aether Neural (Recommended)"
    ) async throws -> String {
        logger.info("Aether Transcribing: \(audioURL.lastPathComponent), model: \(modelName), engine: \(recognitionEngine), language: \(language ?? "auto-detect"), translate: \(autoTranslate)")

        await MainActor.run { state = .transcribing }

        // 1. Stage B: Audio Conditioning (VAD, high-pass filter, loudness normalization)
        guard let conditionedURL = AetherAudioConditioner.shared.condition(audioURL: audioURL) else {
            logger.info("Audio contains no audible speech, skipping decoding to prevent hallucinations")
            await MainActor.run { state = .done("") }
            return ""
        }
        defer {
            if conditionedURL != audioURL {
                try? FileManager.default.removeItem(at: conditionedURL)
            }
        }
        let path = conditionedURL.path
        let baseLang = language != nil ? baseLanguageCode(for: language!) : "auto"

        // 2. Fast Path: Aether Instant Engine (Native Apple Speech - English only)
        if recognitionEngine.contains("Instant") {
            do {
                logger.info("Routing to Aether Instant (Native Apple Speech en-US)...")
                let rawText = try await transcribeWithAppleSpeech(
                    audioURL: conditionedURL,
                    contextualStrings: AetherContextEngine.shared.buildContextualStrings(
                        customVocabulary: customVocabulary,
                        userLocation: userLocation,
                        targetApp: targetApp
                    )
                )

                if !rawText.isEmpty {
                    var text = Self.cleanTranscription(rawText, preferredLanguages: ["en"], targetLanguage: "en")
                    let customVocabList = customVocabulary.components(separatedBy: CharacterSet(charactersIn: ",\n;")).map { $0.trimmingCharacters(in: .whitespaces) }
                    text = AetherLinguisticValidator.shared.validateAndCorrect(
                        text: text,
                        language: "en",
                        customVocabulary: customVocabList
                    )
                    UserFrequencyDictionary.shared.record(text: text)
                    logger.info("Aether Instant transcription completed: '\(text)'")
                    await MainActor.run { state = .done(text) }
                    return text
                } else {
                    await MainActor.run { state = .done("") }
                    return ""
                }
            } catch {
                logger.error("Aether Instant Apple Speech failed: \(error.localizedDescription)")
                throw error
            }
        }

        // 2. Optional Fast Path: Parakeet TDT 0.6B v3 Engine (NVIDIA FastConformer on Apple Neural Engine)
        // Only route to Parakeet if explicitly selected in settings (e.g. "Parakeet").
        // For Russian and multilingual, WhisperKit is the primary neural engine providing rich
        // autoregressive transformer language modeling, full grammatical declensions, and coherent sentence structure.
        if recognitionEngine.contains("Parakeet") && !autoTranslate && ParakeetEngine.canHandle(language: language, preferredLanguages: preferredLanguages) {
            do {
                logger.info("Routing to Parakeet TDT v3 Engine on Apple Neural Engine...")
                let rawParakeetText = try await ParakeetEngine.shared.transcribe(
                    audioURL: conditionedURL,
                    language: baseLang != "auto" ? baseLang : nil
                )

                if !rawParakeetText.isEmpty {
                    var text = Self.cleanTranscription(rawParakeetText, preferredLanguages: preferredLanguages, targetLanguage: baseLang)
                    let customVocabList = customVocabulary.components(separatedBy: CharacterSet(charactersIn: ",\n;")).map { $0.trimmingCharacters(in: .whitespaces) }
                    text = AetherLinguisticValidator.shared.validateAndCorrect(
                        text: text,
                        language: baseLang != "auto" ? baseLang : language,
                        customVocabulary: customVocabList
                    )
                    UserFrequencyDictionary.shared.record(text: text)
                    logger.info("Parakeet TDT v3 transcription completed: '\(text)'")
                    await MainActor.run { state = .done(text) }
                    return text
                }
            } catch {
                logger.warning("Parakeet TDT v3 encountered an error: \(error.localizedDescription). Falling back to WhisperKit...")
            }
        }

        // Check if model is loaded; load if missing
        if whisperKit == nil || loadedModelName != modelName {
            try await ensureModelLoaded(modelName: modelName)
        }

        guard let kit = whisperKit else {
            throw TranscriptionError.modelNotLoaded
        }

        // 3. Configure DecodingOptions with high-performance decoding
        var options = DecodingOptions(task: autoTranslate ? .translate : .transcribe)
        options.temperature = 0.0
        options.temperatureFallbackCount = 0
        options.withoutTimestamps = false
        options.skipSpecialTokens = true
        options.sampleLength = 224
        options.noSpeechThreshold = 0.6
        options.logProbThreshold = -1.0
        options.compressionRatioThreshold = 2.4

        var resolvedLang = baseLang
        if baseLang != "auto" {
            // User explicitly chose single locked language
            options.language = baseLang
            options.detectLanguage = false
            logger.info("Single language mode: Locked to '\(baseLang)'")
        } else if !preferredLanguages.isEmpty {
            // Multilingual mode with user preferred languages:
            // Fast language pre-detection constrained to allowed languages (e.g. Russian vs English)
            let allowedBases = preferredLanguages.map { baseLanguageCode(for: $0).lowercased() }
            if let kit = whisperKit {
                do {
                    let detectStart = Date()
                    let (_, langProbs) = try await kit.detectLanguage(audioPath: path)

                    var bestLang: String? = nil
                    var bestProb: Float = -Float.infinity
                    for code in allowedBases {
                        if let prob = langProbs[code], prob > bestProb {
                            bestProb = prob
                            bestLang = code
                        }
                    }

                    // Slavic variants heuristic: Ukrainian, Belarusian, Bulgarian detection strongly indicates Russian speech
                    if allowedBases.contains("ru") {
                        let slavicCodes = ["uk", "be", "bg", "mk", "sr"]
                        for code in slavicCodes {
                            if let prob = langProbs[code], prob > bestProb {
                                bestProb = prob
                                bestLang = "ru"
                            }
                        }
                    }

                    if let selected = bestLang {
                        resolvedLang = selected
                        options.language = selected
                        options.detectLanguage = false
                        logger.info("Aether fast language detection: locked to '\(selected)' from allowed \(allowedBases) (confidence: \(bestProb), duration: \(String(format: "%.3f", Date().timeIntervalSince(detectStart)))s)")
                    } else {
                        options.language = nil
                        options.detectLanguage = true
                    }
                } catch {
                    logger.warning("WhisperKit.detectLanguage failed: \(error.localizedDescription); falling back to dynamic detection")
                    options.language = nil
                    options.detectLanguage = true
                }
            } else {
                options.language = nil
                options.detectLanguage = true
            }
        } else {
            // Multilingual / Dynamic auto mode:
            // Do NOT lock Whisper to one language; allow seamless switching between Russian, English, and other languages.
            options.language = nil
            options.detectLanguage = true
            logger.info("Multilingual dynamic mode: Real-time language detection active across preferred: \(preferredLanguages)")
        }

        // 3. Stage A: Context Biasing & Dynamic Vocabulary Injection
        let langKey = resolvedLang
        let basePrompt: String
        if resolvedLang != "auto" {
            basePrompt = initialPrompt[resolvedLang] ?? initialPrompt["auto"]!
        } else if !preferredLanguages.isEmpty {
            // Only combine prompts from languages explicitly enabled by the user
            var combined: [String] = []
            for code in preferredLanguages {
                if let p = initialPrompt[code] {
                    combined.append(p)
                }
            }
            basePrompt = combined.isEmpty ? initialPrompt["auto"]! : combined.joined(separator: " ")
        } else {
            basePrompt = initialPrompt["auto"]!
        }

        let promptText = AetherContextEngine.shared.buildConditioningPrompt(
            basePrompt: basePrompt,
            customVocabulary: customVocabulary,
            userLocation: userLocation,
            targetApp: targetApp,
            language: resolvedLang != "auto" ? resolvedLang : language
        )

        if resolvedLang != "auto", let tokenizer = kit.tokenizer {
            let tokens = tokenizer.encode(text: promptText)
            // WhisperKit prompt tokens: take foundational prefix (up to 32 tokens) for fast, responsive decoding
            options.promptTokens = Array(tokens.prefix(min(tokens.count, 32)))
            options.usePrefillCache = false
            logger.debug("Aether set initial prompt (\(options.promptTokens?.count ?? 0) tokens) for locked language '\(langKey)'")
        }
        
        logger.debug("Calling WhisperKit.transcribe(audioPath: \(path), language: \(options.language ?? "auto"))")

        // Execute WhisperKit neural network inference off the MainActor on background cooperative pool
        var results: [TranscriptionResult] = try await kit.transcribe(audioPath: path, decodeOptions: options)

        let detectedLang = results.first?.language.lowercased()
        logger.info("WhisperKit returned \(results.count) result(s), detected language: '\(detectedLang ?? "unknown")'")

        // Language Lock Enforcement for Multilingual Mode:
        // Use base language codes (e.g. en-US -> en) so dialect identifiers match WhisperKit 2-letter codes.
        let allowedLanguages = preferredLanguages.map { baseLanguageCode(for: $0).lowercased() }
        let detectedBase = detectedLang != nil ? baseLanguageCode(for: detectedLang!).lowercased() : nil
        let preliminaryText = results.map(\.text).joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        let wordCount = preliminaryText.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count

        // Do not trigger costly second-pass on minor dialect variants (e.g. uk/be when ru is allowed)
        let isSlavicVariantOfRussian = allowedLanguages.contains("ru") && (detectedBase == "uk" || detectedBase == "be")

        // Only re-decode if audio has substantive speech (>= 3 words) in an unselected language
        if !allowedLanguages.isEmpty, let detected = detectedBase, !allowedLanguages.contains(detected), !isSlavicVariantOfRussian, wordCount >= 3 {
            let slavicUnselected: Set<String> = ["uk", "be", "bg", "mk", "sr", "pl", "cs", "sk", "hr", "sl"]
            let latinCount = preliminaryText.unicodeScalars.filter { ($0.value >= 0x0041 && $0.value <= 0x005A) || ($0.value >= 0x0061 && $0.value <= 0x007A) }.count
            let cyrillicCount = preliminaryText.unicodeScalars.filter { $0.value >= 0x0400 && $0.value <= 0x04FF }.count

            let targetFallback: String
            if allowedLanguages.contains("ru") && slavicUnselected.contains(detected) {
                targetFallback = "ru"
            } else if allowedLanguages.contains("ru") && cyrillicCount >= latinCount {
                targetFallback = "ru"
            } else if allowedLanguages.contains("en") && latinCount > cyrillicCount {
                targetFallback = "en"
            } else if allowedLanguages.contains("ru") {
                targetFallback = "ru"
            } else if allowedLanguages.contains("en") {
                targetFallback = "en"
            } else {
                targetFallback = allowedLanguages.first ?? "ru"
            }

            logger.warning("Whisper detected unselected language '\(detected)'. User enabled only: \(preferredLanguages). Re-decoding locked to '\(targetFallback)'…")
            var redecodeOptions = options
            redecodeOptions.language = targetFallback
            redecodeOptions.detectLanguage = false

            // Update base prompt for the target fallback
            let fallbackBasePrompt = initialPrompt[targetFallback] ?? (initialPrompt["ru"] ?? initialPrompt["auto"]!)
            let fallbackPromptText = AetherContextEngine.shared.buildConditioningPrompt(
                basePrompt: fallbackBasePrompt,
                customVocabulary: customVocabulary,
                userLocation: userLocation,
                targetApp: targetApp,
                language: targetFallback
            )
            if let tokenizer = kit.tokenizer {
                let tokens = tokenizer.encode(text: fallbackPromptText)
                redecodeOptions.promptTokens = Array(tokens.prefix(min(tokens.count, 32)))
                redecodeOptions.usePrefillCache = false
            }

            if let retryResults = try? await kit.transcribe(audioPath: path, decodeOptions: redecodeOptions), !retryResults.isEmpty {
                results = retryResults
                resolvedLang = targetFallback
                logger.info("Successfully re-decoded audio in locked target language '\(targetFallback)'")
            }
        }

        let rawText = results.map(\.text).joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let effectiveOutputLang = resolvedLang != "auto" ? resolvedLang : (detectedBase ?? language)

        // Strip non-speech annotations that Whisper sometimes inserts,
        // e.g. [keyboard clicking], (music), *laughs*, [BLANK_AUDIO], rogue scripts
        var text = Self.cleanTranscription(rawText, preferredLanguages: preferredLanguages, targetLanguage: effectiveOutputLang)

        // Stage C: Linguistic validation against native macOS dictionary and phonetic correction
        let customVocabList = customVocabulary.components(separatedBy: CharacterSet(charactersIn: ",\n;")).map { $0.trimmingCharacters(in: .whitespaces) }
        text = AetherLinguisticValidator.shared.validateAndCorrect(
            text: text,
            language: effectiveOutputLang,
            customVocabulary: customVocabList
        )

        // Track user spoken word frequencies for dynamic Top 100 lexicon adaptation
        UserFrequencyDictionary.shared.record(text: text)

        logger.info("Transcribed text (\(text.count) chars): \(text.prefix(100))")

        await MainActor.run { state = .done(text) }
        return text
    }

    // MARK: - Post-Processing

    /// Built-in Whisper boundary hallucination artifacts (common subtitle credits & YouTube noise loops).
    public static let builtInWhisperHallucinationRoots: [String] = [
        "субтитры сделал",
        "субтитры создавал",
        "субтитры добавил",
        "редактор субтитров",
        "а. семки",
        "а. семкин",
        "а. егорова",
        "семки а. егорова",
        "продолжение следует",
        "спасибо за просмотр",
        "благодарю за просмотр",
        "подписывайтесь на канал",
        "подпишитесь на канал",
        "до встречи в следующем видео",
        "до встречи в новом видео",
        "ссылка в описании под видео",
        "нажмите на колокольчик",
        "amara.org",
        "subtitles by",
        "thank you for watching",
        "thanks for watching",
        "thank you for listening",
        "thanks for listening",
        "translated by",
        "please subscribe to my channel",
        "subscribe to my channel",
        "subscribe to the channel",
        "like and subscribe",
        "like, share, and subscribe",
        "like, comment, and subscribe",
        "don't forget to subscribe",
        "don't forget to like and subscribe",
        "let me know in the comments below",
        "link in the description below",
        "see you in the next video",
        "what is the best place to live in home city"
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

        // 9. Strict language script filtering: if a script is not part of enabled languages, eliminate foreign glyphs & hallucinations
        let activeLangs = Set(preferredLanguages.map { $0.lowercased() } + (targetLanguage != nil ? [targetLanguage!.lowercased()] : []))
        let allowsArabic = activeLangs.contains("ar") || activeLangs.contains("arabic")
        let allowsChinese = activeLangs.contains("zh") || activeLangs.contains("chinese")
        let allowsJapanese = activeLangs.contains("ja") || activeLangs.contains("japanese")
        let allowsKorean = activeLangs.contains("ko") || activeLangs.contains("korean")
        let allowsThai = activeLangs.contains("th") || activeLangs.contains("thai")
        let allowsHebrew = activeLangs.contains("he") || activeLangs.contains("hebrew")
        let allowsDevanagari = activeLangs.contains("hi") || activeLangs.contains("hindi")
        let allowsCyrillic = activeLangs.contains("ru") || activeLangs.contains("uk") || activeLangs.contains("be") || activeLangs.contains("bg") || activeLangs.contains("sr") || activeLangs.contains("mk") || activeLangs.contains("kk") || activeLangs.isEmpty

        cleaned = String(cleaned.unicodeScalars.filter { scalar in
            let val = scalar.value
            if !allowsArabic {
                let isArabic = (val >= 0x0600 && val <= 0x06FF) || (val >= 0x0750 && val <= 0x077F) || (val >= 0x08A0 && val <= 0x08FF) || (val >= 0xFB50 && val <= 0xFDFF) || (val >= 0xFE70 && val <= 0xFEFF)
                if isArabic { return false }
            }
            if !allowsChinese && !allowsJapanese {
                let isCJK = (val >= 0x4E00 && val <= 0x9FFF) || (val >= 0x3400 && val <= 0x4DBF)
                if isCJK { return false }
            }
            if !allowsJapanese {
                let isKana = (val >= 0x3040 && val <= 0x30FF)
                if isKana { return false }
            }
            if !allowsKorean {
                let isHangul = (val >= 0xAC00 && val <= 0xD7AF) || (val >= 0x1100 && val <= 0x11FF)
                if isHangul { return false }
            }
            if !allowsThai {
                let isThai = (val >= 0x0E00 && val <= 0x0E7F)
                if isThai { return false }
            }
            if !allowsHebrew {
                let isHebrew = (val >= 0x0590 && val <= 0x05FF)
                if isHebrew { return false }
            }
            if !allowsDevanagari {
                let isDevanagari = (val >= 0x0900 && val <= 0x097F)
                if isDevanagari { return false }
            }
            if !allowsCyrillic {
                let isCyrillic = (val >= 0x0400 && val <= 0x04FF) || (val >= 0x0500 && val <= 0x052F)
                if isCyrillic { return false }
            }
            return true
        })

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
        let pattern = #"(?i)(?:\b([A-Za-zА-Яа-я0-9\s]{3,30}?)[.,!?;:\s]+)\1[.,!?;:\s]*$"#
        if let regex = try? NSRegularExpression(pattern: pattern) {
            for _ in 0..<2 {
                let range = NSRange(current.startIndex..<current.endIndex, in: current)
                guard let match = regex.firstMatch(in: current, options: [], range: range),
                      let fullMatchRange = Range(match.range, in: current),
                      let phraseRange = Range(match.range(at: 1), in: current) else { break }

                let phrase = String(current[phraseRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                let lower = phrase.lowercased()
                let isKnownHallucination = builtInWhisperHallucinationRoots.contains(where: { root in
                    root.count >= 6 && lower.contains(root)
                })

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

    /// Strips built-in boundary hallucination artifacts (subtitles, credits, YouTube noise loops).
    public static func stripBuiltInHallucinations(_ text: String) -> String {
        guard !text.isEmpty else { return text }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let stripped = trimmed.trimmingCharacters(in: CharacterSet.punctuationCharacters.union(.whitespacesAndNewlines))
        let lowerStripped = stripped.lowercased()

        // 1. If the text is solely composed of or matches a hallucination root, discard it completely
        for root in builtInWhisperHallucinationRoots {
            if lowerStripped == root {
                return ""
            }
            if lowerStripped.contains(root) {
                let withoutRoot = lowerStripped.replacingOccurrences(of: root, with: "").trimmingCharacters(in: CharacterSet.punctuationCharacters.union(.whitespacesAndNewlines))
                if withoutRoot.isEmpty || withoutRoot.count < 3 {
                    return ""
                }
            }
        }

        var result = text
        for root in builtInWhisperHallucinationRoots {
            let escaped = NSRegularExpression.escapedPattern(for: root)
            // Match STRICTLY at the END of string with preceding punctuation/whitespace and whole-word boundary
            let endPattern = "(?i)(?:[,\\.\\!\\?\\s]+|^)\\b\(escaped)\\b[,\\.\\!\\?\\s]*$"
            result = result.replacingOccurrences(of: endPattern, with: "", options: [.regularExpression])

            // Match STRICTLY at the START of string with trailing punctuation/whitespace and whole-word boundary
            let startPattern = "(?i)^[,\\.\\!\\?\\s]*\\b\(escaped)\\b(?:[,\\.\\!\\?\\s]+|$)"
            result = result.replacingOccurrences(of: startPattern, with: "", options: [.regularExpression])
        }

        // Clean up punctuation and whitespace
        result = result.replacingOccurrences(of: "\\s{2,}", with: " ", options: .regularExpression)
        result = result.replacingOccurrences(of: "\\s+([.,!?:;])", with: "$1", options: .regularExpression)
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)

        // If stripping left only orphan punctuation (e.g. "." or "..."), discard
        let alphaCheck = result.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }
        if alphaCheck.isEmpty {
            return ""
        }

        return result
    }

    /// Removes filler words (эээ, ну, типа, uh, um, etc.) and duplicate adjacent words or stuttering loops.
    public static func removeFillerWordsAndDuplicates(_ text: String) -> String {
        guard !text.isEmpty else { return text }
        
        var result = text

        // 1. Collapse repeating word loops with any punctuation (e.g. "Как... Как... Как... Как..." -> "Как...")
        let repeatingWordLoopPattern = #"(?i)(?:\b([\p{L}\p{N}]+)[.,…!?:;\s]*)(?:\s*\1[.,…!?:;\s]*){2,}"#
        if let loopRegex = try? NSRegularExpression(pattern: repeatingWordLoopPattern) {
            let range = NSRange(result.startIndex..<result.endIndex, in: result)
            result = loopRegex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "$1")
        }

        // 2. Collapse repeating multi-word phrase loops (e.g. "всё из мелочей всё из мелочей" -> "всё из мелочей")
        let repeatingPhraseLoopPattern = #"(?i)(?:\b([\p{L}\p{N}]+\s+[\p{L}\p{N}]+)[.,…!?:;\s]*)(?:\s*\1[.,…!?:;\s]*){1,}"#
        if let phraseRegex = try? NSRegularExpression(pattern: repeatingPhraseLoopPattern) {
            let range = NSRange(result.startIndex..<result.endIndex, in: result)
            result = phraseRegex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "$1")
        }

        // 3. Remove interjection filler patterns (standalone or surrounded by punctuation/spaces)
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

        // 4. Remove duplicate consecutive words (e.g. "мы мы пошли" -> "мы пошли", "I I think" -> "I think")
        let duplicateWordRegex = "\\b(\\w+)\\s+\\1\\b"
        result = result.replacingOccurrences(
            of: duplicateWordRegex,
            with: "$1",
            options: [.regularExpression, .caseInsensitive]
        )

        // 5. Clean up leading/trailing punctuation artifacts
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
        "вайб-кодинг", "вайбкодинг", "vibe coding",
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
        
        // Vibe coding acoustic corrections & variants
        Replacement(phrase: "вайб кодина", replacement: "вайб-кодинг"),
        Replacement(phrase: "вайб кодину", replacement: "вайб-кодингу"),
        Replacement(phrase: "вайб кодинга", replacement: "вайб-кодинга"),
        Replacement(phrase: "вайб кодингом", replacement: "вайб-кодингом"),
        Replacement(phrase: "вайб кодинге", replacement: "вайб-кодинге"),
        Replacement(phrase: "вайб кодинг", replacement: "вайб-кодинг"),
        Replacement(phrase: "вайп кодинг", replacement: "вайб-кодинг"),
        Replacement(phrase: "вайп-кодинг", replacement: "вайб-кодинг"),
        Replacement(phrase: "вайпкодинг", replacement: "вайб-кодинг"),
        Replacement(phrase: "вайбкодина", replacement: "вайб-кодинг"),
        Replacement(phrase: "вайп кодина", replacement: "вайб-кодинг"),
        Replacement(phrase: "вайп кодину", replacement: "вайб-кодингу"),
        Replacement(phrase: "вайп кодинга", replacement: "вайб-кодинга"),
        Replacement(phrase: "вайп кодингом", replacement: "вайб-кодингом"),
        Replacement(phrase: "вайп кодинге", replacement: "вайб-кодинге"),
        Replacement(phrase: "vibe code", replacement: "vibe coding"),
        Replacement(phrase: "vibecoding", replacement: "vibe coding"),
        Replacement(phrase: "вайб кодить", replacement: "вайбкодить"),
        Replacement(phrase: "вайп кодить", replacement: "вайбкодить"),

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
        "А. Семкин",
        "А. Семки",
        "А. Егорова",
        "Семки А. Егорова",
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

    // MARK: - Game Score Formatting (e.g. "3:0", "2:1", "0:0", "со счетом 3:0")

    private static let verbalNumberMap: [String: Int] = [
        "ноль": 0, "нуль": 0, "нулю": 0, "нуля": 0, "нолю": 0, "нулем": 0, "нулём": 0,
        "один": 1, "одна": 1, "одно": 1, "одного": 1, "одному": 1, "одним": 1,
        "два": 2, "две": 2, "двух": 2, "двум": 2, "двумя": 2,
        "три": 3, "трех": 3, "трёх": 3, "трем": 3, "трём": 3, "тремя": 3,
        "четыре": 4, "четырех": 4, "четырёх": 4, "четырем": 4, "четырём": 4, "четырьмя": 4,
        "пять": 5, "пяти": 5, "пятью": 5,
        "шесть": 6, "шести": 6, "шестью": 6,
        "семь": 7, "семи": 7, "семью": 7,
        "восемь": 8, "восьми": 8, "восьмью": 8,
        "девять": 9, "девяти": 9, "девятью": 9,
        "десять": 10, "десяти": 10, "десятью": 10,
        "одиннадцать": 11, "одиннадцати": 11,
        "двенадцать": 12, "двенадцати": 12,
        "тринадцать": 13, "тринадцати": 13,
        "четырнадцать": 14, "четырнадцати": 14,
        "пятнадцать": 15, "пятнадцати": 15,
        "шестнадцать": 16, "шестнадцати": 16,
        "семнадцать": 17, "семнадцати": 17,
        "восемнадцать": 18, "восемнадцати": 18,
        "девятнадцать": 19, "девятнадцати": 19,
        "двадцать": 20, "двадцати": 20,
        // English
        "zero": 0, "nil": 0, "love": 0,
        "one": 1, "two": 2, "three": 3, "four": 4, "five": 5,
        "six": 6, "seven": 7, "eight": 8, "nine": 9, "ten": 10
    ]

    private static func parseScoreNumber(_ token: String) -> Int? {
        let clean = token.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if let direct = Int(clean) { return direct }
        return verbalNumberMap[clean]
    }

    /// Formats game scores dictated verbally or with hyphens/spaces into digit:digit format (e.g. "3:0", "со счетом 2:1").
    public static func formatGameScores(in text: String) -> String {
        var result = text

        // 1. Explicit score context trigger: "со счетом X Y", "счет X Y", "score X Y", "сыграли X Y", "вели X Y", "раунд X Y", etc.
        let triggerPattern = "(?i)\\b(со\\s+счетом|со\\s+счётом|счет|счёт|счетом|счётом|score|выиграли|выиграл|проиграли|проиграл|сыграли|сыграл|победили|победил|вели|ведет|ведёт|ведут|раунд|матч)\\s+(?:в\\s+)?([a-zA-Zа-яА-ЯёЁ0-9]+)\\s*(?:-|–|—|:|[\\s]+|к|to)\\s*([a-zA-Zа-яА-ЯёЁ0-9]+)\\b"
        if let regex = try? NSRegularExpression(pattern: triggerPattern) {
            let nsStr = result as NSString
            let matches = regex.matches(in: result, options: [], range: NSRange(location: 0, length: nsStr.length))
            for match in matches.reversed() {
                if match.numberOfRanges >= 4,
                   let prefixRange = Range(match.range(at: 1), in: result),
                   let token1Range = Range(match.range(at: 2), in: result),
                   let token2Range = Range(match.range(at: 3), in: result),
                   let fullRange = Range(match.range, in: result) {
                    let prefix = String(result[prefixRange])
                    let t1 = String(result[token1Range])
                    let t2 = String(result[token2Range])
                    if let n1 = parseScoreNumber(t1), let n2 = parseScoreNumber(t2) {
                        let scoreStr = "\(prefix) \(n1):\(n2)"
                        result.replaceSubrange(fullRange, with: scoreStr)
                    }
                }
            }
        }

        // 2. Standalone score expressions with "ноль" / "нуль" / "zero" / "nil":
        // e.g. "три ноль" -> "3:0", "ноль ноль" -> "0:0", "3 ноль" -> "3:0", "5 ноль" -> "5:0", "10 ноль" -> "10:0"
        let zeroPattern1 = "(?i)\\b([a-zA-Zа-яА-ЯёЁ0-9]+)\\s*(?:-|–|—|\\s+)\\s*(ноль|нуль|нулю|нуля|zero|nil)\\b"
        if let regex = try? NSRegularExpression(pattern: zeroPattern1) {
            let nsStr = result as NSString
            let matches = regex.matches(in: result, options: [], range: NSRange(location: 0, length: nsStr.length))
            for match in matches.reversed() {
                if match.numberOfRanges >= 3,
                   let token1Range = Range(match.range(at: 1), in: result),
                   let fullRange = Range(match.range, in: result) {
                    let t1 = String(result[token1Range])
                    if let n1 = parseScoreNumber(t1) {
                        result.replaceSubrange(fullRange, with: "\(n1):0")
                    }
                }
            }
        }

        // e.g. "ноль один" -> "0:1", "ноль два" -> "0:2", "ноль три" -> "0:3"
        let zeroPattern2 = "(?i)\\b(ноль|нуль|zero)\\s*(?:-|–|—|\\s+)\\s*([a-zA-Zа-яА-ЯёЁ0-9]+)\\b"
        if let regex = try? NSRegularExpression(pattern: zeroPattern2) {
            let nsStr = result as NSString
            let matches = regex.matches(in: result, options: [], range: NSRange(location: 0, length: nsStr.length))
            for match in matches.reversed() {
                if match.numberOfRanges >= 3,
                   let token2Range = Range(match.range(at: 2), in: result),
                   let fullRange = Range(match.range, in: result) {
                    let t2 = String(result[token2Range])
                    if let n2 = parseScoreNumber(t2) {
                        result.replaceSubrange(fullRange, with: "0:\(n2)")
                    }
                }
            }
        }

        // 3. Standalone pairs connected by "к" / "to":
        // e.g. "три к одному" -> "3:1", "3 к 1" -> "3:1", "два к одному" -> "2:1", "3 to 1" -> "3:1"
        let toPattern = "(?i)\\b([a-zA-Zа-яА-ЯёЁ0-9]+)\\s+(?:к|to)\\s+([a-zA-Zа-яА-ЯёЁ0-9]+)\\b"
        if let regex = try? NSRegularExpression(pattern: toPattern) {
            let nsStr = result as NSString
            let matches = regex.matches(in: result, options: [], range: NSRange(location: 0, length: nsStr.length))
            for match in matches.reversed() {
                if match.numberOfRanges >= 3,
                   let token1Range = Range(match.range(at: 1), in: result),
                   let token2Range = Range(match.range(at: 2), in: result),
                   let fullRange = Range(match.range, in: result) {
                    let t1 = String(result[token1Range])
                    let t2 = String(result[token2Range])
                    if let n1 = parseScoreNumber(t1), let n2 = parseScoreNumber(t2) {
                        result.replaceSubrange(fullRange, with: "\(n1):\(n2)")
                    }
                }
            }
        }

        // 4. Standalone digits separated by hyphen/dash when 0 is involved: e.g. "3-0" -> "3:0", "0-3" -> "0:3", "3 - 0" -> "3:0"
        result = result.replacingOccurrences(of: "(?i)\\b(\\d{1,2})\\s*[-–—]\\s*(0)\\b", with: "$1:0", options: .regularExpression)
        result = result.replacingOccurrences(of: "(?i)\\b(0)\\s*[-–—]\\s*(\\d{1,2})\\b", with: "0:$2", options: .regularExpression)

        // 5. Clean up colon formatting if surrounded by spaces: e.g. "3 : 0" -> "3:0"
        result = result.replacingOccurrences(of: "(?<=\\d)\\s*:\\s*(?=\\d)", with: ":", options: .regularExpression)

        return result
    }

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

        // 4. Game Score Auto-Formatting (e.g. "3:0", "со счетом 2:1", "три ноль")
        result = formatGameScores(in: result)

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
    public var provider: String?

    public init(
        id: String,
        email: String,
        name: String,
        avatarURL: String?,
        subscriptionTier: SubscriptionTier,
        subscriptionExpiresAt: Date?,
        provider: String? = nil
    ) {
        self.id = id
        self.email = email
        self.name = name
        self.avatarURL = avatarURL
        self.subscriptionTier = subscriptionTier
        self.subscriptionExpiresAt = subscriptionExpiresAt
        self.provider = provider
    }

    public var providerDisplayName: String {
        if let p = provider, !p.isEmpty {
            return p
        }
        if id.starts(with: "google_") || email.hasSuffix("@gmail.com") || (avatarURL?.contains("google") == true) {
            return "Google"
        }
        if id.starts(with: "github_") || email.contains("github.com") {
            return "GitHub"
        }
        if id.starts(with: "apple_") || email.contains("privaterelay.appleid.com") || email.contains("apple.com") {
            return "Apple"
        }
        if !email.isEmpty {
            return "Email"
        }
        return "Account"
    }

    public var providerIcon: String {
        switch providerDisplayName {
        case "Google":
            return "g.circle.fill"
        case "GitHub":
            return "chevron.left.forwardslash.chevron.right"
        case "Apple":
            return "apple.logo"
        case "Email":
            return "envelope.fill"
        default:
            return "person.crop.circle"
        }
    }

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

