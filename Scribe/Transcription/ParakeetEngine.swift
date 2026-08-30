import Foundation
import AVFoundation
import FluidAudio
import os.log

private let logger = Logger(subsystem: "com.aleksei.scribe", category: "Parakeet")

/// High-performance CoreML on-device speech-to-text engine using NVIDIA Parakeet TDT 0.6B v3.
/// Powered by FluidAudio on Apple Neural Engine (ANE).
public actor ParakeetEngine {
    public static let shared = ParakeetEngine()

    private var asrManager: AsrManager?
    private var isLoaded: Bool = false
    private var isLoading: Bool = false

    /// 25+ European languages supported natively by Parakeet TDT v3
    public static let supportedLanguages: Set<String> = [
        "en", "ru", "uk", "be", "bg", "sr",
        "de", "fr", "es", "it", "pt", "nl",
        "pl", "cs", "sk", "sl", "hr", "bs",
        "da", "sv", "fi", "et", "lv", "lt",
        "hu", "ro", "el", "mt"
    ]

    /// Checks if a language or set of preferred languages can be transcribed by Parakeet
    public static func canHandle(language: String?, preferredLanguages: [String] = []) -> Bool {
        if let lang = language, !lang.isEmpty, lang != "auto" {
            let base = lang.lowercased().prefix(2).description
            return supportedLanguages.contains(base)
        }

        if !preferredLanguages.isEmpty {
            for pref in preferredLanguages {
                let base = pref.lowercased().prefix(2).description
                if !supportedLanguages.contains(base) {
                    return false
                }
            }
            return true
        }

        // Default auto (RU + EN) is fully supported
        return true
    }

    public func isModelReady() -> Bool {
        return isLoaded && asrManager != nil
    }

    public func loadModel(version: AsrModelVersion = .v3) async throws {
        if isLoaded && asrManager != nil { return }
        if isLoading { return }
        isLoading = true
        defer { isLoading = false }

        logger.info("Loading Parakeet TDT v3 CoreML models...")
        let models = try await AsrModels.downloadAndLoad(version: version)
        let manager = AsrManager(config: .default, models: models)
        self.asrManager = manager
        self.isLoaded = true
        logger.info("Parakeet TDT v3 model loaded successfully on Apple Neural Engine")
    }

    public func transcribe(audioURL: URL, language: String? = nil) async throws -> String {
        if !isLoaded || asrManager == nil {
            try await loadModel(version: .v3)
        }
        guard let manager = asrManager else {
            throw NSError(domain: "ParakeetEngine", code: -1, userInfo: [NSLocalizedDescriptionKey: "Parakeet engine not initialized"])
        }

        var decoderState = try TdtDecoderState(decoderLayers: 2)

        var fluidLang: Language? = nil
        if let l = language, !l.isEmpty, l != "auto" {
            let base = l.lowercased().prefix(2).description
            fluidLang = Language(rawValue: base)
        }

        let result = try await manager.transcribe(audioURL, decoderState: &decoderState, language: fluidLang)
        return result.text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    }
}
