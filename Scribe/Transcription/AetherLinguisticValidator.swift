import Foundation
import AppKit

/// Intelligently validates transcribed words against native macOS lexicons and phonetic correction rules
/// to eliminate non-existent words and acoustic hallucinations from Whisper output.
public final class AetherLinguisticValidator: @unchecked Sendable {
    public static let shared = AetherLinguisticValidator()

    private let spellChecker = NSSpellChecker.shared

    /// Common Whisper acoustic confusion pairs where Whisper invents non-existent words or mishears common spoken commands.
    private let acousticCorrections: [String: String] = [
        "отобили": "убери",
        "ото били": "убери",
        "ото бери": "убери",
        "отобирите": "уберите",
        "пафикси": "пофикси",
        "по фикси": "пофикси",
        "по фикшено": "пофикшено",
        "по фикшен": "пофикшен",
        "зафикси": "зафиксируй",
        "пофиксить": "пофиксить",
        "промптить": "промптить",
        "промптинг": "промптинг",
        "рефакторинг": "рефакторинг",
        "рефакторить": "рефакторить",
        "от рефактори": "отрефактори",
        "закоммить": "закоммить",
        "за коммить": "закоммить",
        "запушить": "запушить",
        "за пушить": "запушить",
        "замержить": "замержить",
        "за мержить": "замержить",
        "задеплой": "задеплой",
        "за деплой": "задеплой",
        "чекаутни": "чекаутни",
        "заскрейпи": "заскрейпи"
    ]

    private init() {}

    /// Validates and corrects words in the transcription text.
    public func validateAndCorrect(
        text: String,
        language: String? = nil,
        customVocabulary: [String] = []
    ) -> String {
        guard !text.isEmpty else { return text }

        var result = text

        // 1. Direct phrase-level acoustic corrections
        for (incorrect, correct) in acousticCorrections {
            let pattern = "(?i)\\b" + NSRegularExpression.escapedPattern(for: incorrect) + "\\b"
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let range = NSRange(result.startIndex..<result.endIndex, in: result)
                result = regex.stringByReplacingMatches(
                    in: result,
                    options: [],
                    range: range,
                    withTemplate: correct
                )
            }
        }

        // 2. Token-level dictionary validation via NSSpellChecker
        let langCode = resolveSpellCheckerLanguage(language: language, text: text)
        let isRussian = langCode.hasPrefix("ru")
        let customSet = Set(customVocabulary.map { $0.lowercased() })

        // Extract words using regex
        let wordPattern = "\\b([\\p{L}\\p{M}'-]+)\\b"
        guard let wordRegex = try? NSRegularExpression(pattern: wordPattern) else { return result }

        let nsString = result as NSString
        let matches = wordRegex.matches(in: result, options: [], range: NSRange(location: 0, length: nsString.length))

        var replacements: [(range: NSRange, replacement: String)] = []

        for match in matches {
            let wordRange = match.range(at: 1)
            let word = nsString.substring(with: wordRange)
            let lowerWord = word.lowercased()

            // Skip single letters, custom vocabulary, numbers, or terms with symbols
            if word.count <= 2 || customSet.contains(lowerWord) {
                continue
            }

            // Check if known by community dictionary
            if CommunityVocabularyService.shared.getCachedTermsSetLower().contains(lowerWord) {
                continue
            }

            // Check spelling with NSSpellChecker
            var wordCount: Int = 0
            let misspellingRange = spellChecker.checkSpelling(
                of: word,
                startingAt: 0,
                language: langCode,
                wrap: false,
                inSpellDocumentWithTag: 0,
                wordCount: &wordCount
            )

            // If word is unrecognized by dictionary (length > 0)
            if misspellingRange.length > 0 {
                // Check if we have a direct acoustic fix
                if let directFix = acousticCorrections[lowerWord] {
                    let matchedCase = matchCapitalization(original: word, target: directFix)
                    replacements.append((range: wordRange, replacement: matchedCase))
                    continue
                }

                // In Russian, do NOT let spell checker overwrite case endings (e.g. -ом, -ам, -ях, -е)
                // with dictionary base forms unless it is clearly an acoustic mishearing.
                if isRussian {
                    let commonRussianInflections = ["ом", "ем", "ём", "ами", "ями", "ях", "ах", "ам", "ям", "ого", "его", "ому", "ему", "ым", "им", "ую", "юю", "ой", "ей", "ою", "ею", "ых", "их", "ыми", "ими"]
                    if commonRussianInflections.contains(where: { lowerWord.hasSuffix($0) }) {
                        continue
                    }
                }

                // Query Apple's spell checker for plausible guesses
                let guesses = spellChecker.guesses(
                    forWordRange: NSRange(location: 0, length: (word as NSString).length),
                    in: word,
                    language: langCode,
                    inSpellDocumentWithTag: 0
                ) ?? []

                if let bestGuess = guesses.first, !bestGuess.isEmpty {
                    // Only apply if the guess is very close in length and phonetic structure
                    if abs(bestGuess.count - word.count) <= 1 && isAcousticallySimilar(word, bestGuess) {
                        let matchedCase = matchCapitalization(original: word, target: bestGuess)
                        replacements.append((range: wordRange, replacement: matchedCase))
                    }
                }
            }
        }

        // Apply replacements from back to front to keep character offsets valid
        for rep in replacements.reversed() {
            if let strRange = Range(rep.range, in: result) {
                result.replaceSubrange(strRange, with: rep.replacement)
            }
        }

        return result
    }

    /// Resolves appropriate spell checker language tag
    private func resolveSpellCheckerLanguage(language: String?, text: String) -> String {
        if let lang = language?.lowercased() {
            if lang.hasPrefix("ru") { return "ru_RU" }
            if lang.hasPrefix("en") { return "en_US" }
            if lang.hasPrefix("es") { return "es_ES" }
            if lang.hasPrefix("de") { return "de_DE" }
            if lang.hasPrefix("fr") { return "fr_FR" }
        }

        // Detect Cyrillic presence for automatic Russian / English fallback
        let cyrillicScalars = text.unicodeScalars.filter { $0.value >= 0x0400 && $0.value <= 0x04FF }
        if cyrillicScalars.count > 0 {
            return "ru_RU"
        }
        return "en_US"
    }

    /// Preserves original word casing (Uppercase, Capitalized, or lowercase)
    private func matchCapitalization(original: String, target: String) -> String {
        if original == original.uppercased() && original.count > 1 {
            return target.uppercased()
        }
        if original.first?.isUppercase == true {
            return target.prefix(1).uppercased() + target.dropFirst()
        }
        return target.lowercased()
    }

    /// Determines if two words are phonetically and structurally close
    private func isAcousticallySimilar(_ w1: String, _ w2: String) -> Bool {
        let s1 = w1.lowercased()
        let s2 = w2.lowercased()
        if s1 == s2 { return true }
        
        // Levenshtein distance check
        let dist = levenshtein(s1, s2)
        let maxLen = max(s1.count, s2.count)
        return dist <= 2 && Double(dist) / Double(maxLen) <= 0.35
    }

    private func levenshtein(_ s1: String, _ s2: String) -> Int {
        let a = Array(s1)
        let b = Array(s2)
        var dist = [[Int]](repeating: [Int](repeating: 0, count: b.count + 1), count: a.count + 1)

        for i in 0...a.count { dist[i][0] = i }
        for j in 0...b.count { dist[0][j] = j }

        for i in 1...a.count {
            for j in 1...b.count {
                if a[i - 1] == b[j - 1] {
                    dist[i][j] = dist[i - 1][j - 1]
                } else {
                    dist[i][j] = min(
                        dist[i - 1][j] + 1,
                        dist[i][j - 1] + 1,
                        dist[i - 1][j - 1] + 1
                    )
                }
            }
        }
        return dist[a.count][b.count]
    }
}
