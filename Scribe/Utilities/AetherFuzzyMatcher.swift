import Foundation
import os.log

private let logger = Logger(subsystem: "com.aleksei.scribe", category: "AetherFuzzyMatcher")

/// Aether Fuzzy Matcher (Stage C):
/// Re-aligns phonetically misrecognized or lowercase words with canonical vocabulary terms.
public final class AetherFuzzyMatcher: @unchecked Sendable {

    public static let shared = AetherFuzzyMatcher()

    private init() {}

    /// Known phonetic transliteration mappings (Cyrillic -> Latin Canonical)
    private let commonTransliterationMap: [String: String] = [
        "тайлвинд": "TailwindCSS",
        "тейлвинд": "TailwindCSS",
        "тайлвиндксс": "TailwindCSS",
        "постгрес": "PostgreSQL",
        "постгре": "PostgreSQL",
        "постгрескл": "PostgreSQL",
        "антигравити": "Antigravity",
        "анти-гравити": "Antigravity",
        "супабейс": "Supabase",
        "супабейз": "Supabase",
        "кубернетес": "Kubernetes",
        "кубер": "Kubernetes",
        "докер": "Docker",
        "тайпскрипт": "TypeScript",
        "тайп скрипт": "TypeScript",
        "джаваскрипт": "JavaScript",
        "свифт": "Swift",
        "свифтдата": "SwiftData",
        "версель": "Vercel",
        "версел": "Vercel",
        "некст": "Next.js",
        "некстджс": "Next.js",
        "пайторч": "PyTorch",
        "питч": "PyTorch",
        "оллама": "Ollama",
        "випер": "viperr",
        "вайпер": "viperr",
        "кай энджел": "Kai Angel",
        "девять майс": "9mice",
        "перплексити": "Perplexity",
        "миджорни": "Midjourney",
        "хаггинг фейс": "HuggingFace",
        "хаггингфейс": "HuggingFace",
        "чатгпт": "ChatGPT",
        "джипити": "GPT",
        "гемнай": "Gemini",
        "джеминай": "Gemini"
    ]

    /// Matches and realigns words against target vocabulary
    public func realign(text: String, vocabulary: [String]) -> String {
        guard !text.isEmpty else { return text }

        var result = text

        // 1. Direct Phonetic Transliteration Lookup
        for (phonetic, canonical) in commonTransliterationMap {
            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: phonetic))\\b"
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                result = regex.stringByReplacingMatches(
                    in: result,
                    options: [],
                    range: NSRange(location: 0, length: result.utf16.count),
                    withTemplate: canonical
                )
            }
        }

        // 2. Exact Case-Insensitive Vocabulary Alignment
        for term in vocabulary {
            let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.count >= 2 else { continue }

            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: trimmed))\\b"
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                result = regex.stringByReplacingMatches(
                    in: result,
                    options: [],
                    range: NSRange(location: 0, length: result.utf16.count),
                    withTemplate: trimmed
                )
            }
        }

        // 3. Levenshtein Fuzzy Alignment for Longer Custom Vocabulary (>5 chars)
        let longVocab = vocabulary.filter { $0.count >= 5 }
        if !longVocab.isEmpty {
            result = applyLevenshteinAlignment(text: result, targets: longVocab)
        }

        return result
    }

    // MARK: - Levenshtein Distance Matching

    private func applyLevenshteinAlignment(text: String, targets: [String]) -> String {
        let words = text.components(separatedBy: " ")
        var adjustedWords: [String] = []

        for word in words {
            // Strip punctuation for matching
            let punctuationSet = CharacterSet.punctuationCharacters
            let cleanWord = word.trimmingCharacters(in: punctuationSet)
            guard cleanWord.count >= 5 else {
                adjustedWords.append(word)
                continue
            }

            var matchedTarget: String? = nil
            for target in targets {
                let dist = levenshteinDistance(cleanWord.lowercased(), target.lowercased())
                let maxAllowedDist = cleanWord.count >= 8 ? 2 : 1

                if dist > 0 && dist <= maxAllowedDist {
                    matchedTarget = target
                    break
                }
            }

            if let target = matchedTarget {
                // Reconstruct word with original surrounding punctuation
                let prefixScalars = word.unicodeScalars.prefix(while: { punctuationSet.contains($0) })
                let suffixScalars = word.unicodeScalars.reversed().prefix(while: { punctuationSet.contains($0) }).reversed()
                let prefix = String(String.UnicodeScalarView(prefixScalars))
                let suffix = String(String.UnicodeScalarView(suffixScalars))
                adjustedWords.append("\(prefix)\(target)\(suffix)")
            } else {
                adjustedWords.append(word)
            }
        }

        return adjustedWords.joined(separator: " ")
    }

    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
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
                        dist[i - 1][j] + 1,       // deletion
                        dist[i][j - 1] + 1,       // insertion
                        dist[i - 1][j - 1] + 1    // substitution
                    )
                }
            }
        }

        return dist[a.count][b.count]
    }
}
