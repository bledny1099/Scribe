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
        "чат гпт": "ChatGPT",
        "чат-гпт": "ChatGPT",
        "чат gpt": "ChatGPT",
        "чат-gpt": "ChatGPT",
        "chat gpt": "ChatGPT",
        "chat-gpt": "ChatGPT",
        "chatgpt": "ChatGPT",
        "чат джипити": "ChatGPT",
        "чатджипити": "ChatGPT",
        "чат джи пи ти": "ChatGPT",
        "джипити": "GPT",
        "джи пи ти": "GPT",
        "гпт": "GPT",
        "опенаи": "OpenAI",
        "опен аи": "OpenAI",
        "опенэй": "OpenAI",
        "open ai": "OpenAI",
        "дипсик": "DeepSeek",
        "дип сик": "DeepSeek",
        "deep seek": "DeepSeek",
        "клод": "Claude",
        "клауд": "Claude",
        "клод код": "Claude Code",
        "клауд код": "Claude Code",
        "вайб кодинг": "вайб-кодинг",
        "вайп кодинг": "вайб-кодинг",
        "вайп-кодинг": "вайб-кодинг",
        "вайбкодина": "вайб-кодинг",
        "вайб кодина": "вайб-кодинг",
        "вайп кодина": "вайб-кодинг",
        "вайбкодинг": "вайбкодинг",
        "гемнай": "Gemini",
        "джеминай": "Gemini",
        "джемини": "Gemini"
    ]

    /// Morphological phonetic & acoustic correction patterns (e.g. speech mishearing of roots)
    private let commonPhoneticRules: [(pattern: String, template: String)] = [
        // Vibe coding acoustic corrections
        ("(?i)\\bвай[бп]\\s*кодина\\b", "вайб-кодинг"),
        ("(?i)\\bвай[бп]\\s*кодин([а-яё]*)", "вайб-кодин$1"),
        // Nautical / Geographic / Historical roots (e.g. моревлаватели -> мореплаватели)
        ("(?i)\\bморевлав([а-яё]*)", "мореплав$1"),
        ("(?i)\\bперво открывател([а-яё]*)", "первооткрывател$1"),
        ("(?i)\\bперваоткрывател([а-яё]*)", "первооткрывател$1"),
        ("(?i)\\bпутишеств([а-яё]*)", "путешеств$1"),
        ("(?i)\\bкораблекрашен([а-яё]*)", "кораблекрушен$1"),
        ("(?i)\\bкорабле крушен([а-яё]*)", "кораблекрушен$1"),
        ("(?i)\\bврядли\\b", "вряд ли"),
        ("(?i)\\bкакбудто\\b", "как будто"),
        ("(?i)\\bточь в точь\\b", "точь-в-точь"),
        ("(?i)\\bвсетаки\\b", "всё-таки"),
        ("(?i)\\bизпод\\b", "из-под"),
        ("(?i)\\bизза\\b", "из-за"),
        ("(?i)\\bповидимому\\b", "по-видимому"),
        ("(?i)\\bпопрежнему\\b", "по-прежнему")
    ]

    /// Built-in canonical terms for Levenshtein fuzzy alignment
    private let builtInDictionaryTargets: [String] = [
        "мореплаватели", "мореплаватель", "путешественники", "исследователи",
        "первооткрыватели", "первопроходцы", "мореплавание", "навигаторы",
        "первооткрыватель", "путешественник", "исследователь"
    ]

    /// Matches and realigns words against target vocabulary
    public func realign(text: String, vocabulary: [String]) -> String {
        guard !text.isEmpty else { return text }

        var result = text

        // 0. Phonetic & Root Acoustic Repairs (with capitalization preservation)
        for rule in commonPhoneticRules {
            if let regex = try? NSRegularExpression(pattern: rule.pattern, options: []) {
                let matches = regex.matches(in: result, options: [], range: NSRange(location: 0, length: result.utf16.count))
                for match in matches.reversed() {
                    if let range = Range(match.range, in: result) {
                        let matchedText = String(result[range])
                        let isCapitalized = matchedText.first?.isUppercase == true
                        var replaced = regex.stringByReplacingMatches(
                            in: matchedText,
                            options: [],
                            range: NSRange(location: 0, length: matchedText.utf16.count),
                            withTemplate: rule.template
                        )
                        if isCapitalized, let first = replaced.first {
                            replaced = String(first.uppercased()) + replaced.dropFirst()
                        }
                        result.replaceSubrange(range, with: replaced)
                    }
                }
            }
        }

        // 1. Direct Phonetic Transliteration Lookup (Built-in + Community synced)
        var fullTransliterationMap = commonTransliterationMap
        let communityMap = CommunityVocabularyService.shared.transliterationMap
        for (k, v) in communityMap {
            fullTransliterationMap[k] = v
        }

        for (phonetic, canonical) in fullTransliterationMap {
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

        // 3. Levenshtein Fuzzy Alignment for Longer Custom, User Top 100 & Built-in Vocabulary (>5 chars)
        let userTopTargets = UserFrequencyDictionary.shared.topWords(limit: 100).filter { $0.count >= 5 }
        let combinedTargets = builtInDictionaryTargets + vocabulary.filter { $0.count >= 5 } + userTopTargets
        if !combinedTargets.isEmpty {
            result = applyLevenshteinAlignment(text: result, targets: combinedTargets)
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

            let isCapitalized = cleanWord.first?.isUppercase == true

            var matchedTarget: String? = nil
            for target in targets {
                // If the word has Cyrillic characters, verify it is not a valid grammatical case inflection
                if isCyrillic(cleanWord) && isCyrillic(target) {
                    if isRussianCaseInflection(word: cleanWord, target: target) {
                        // Never overwrite inflected Russian case forms with dictionary nominatives
                        continue
                    }
                }

                let dist = levenshteinDistance(cleanWord.lowercased(), target.lowercased())
                let maxAllowedDist = cleanWord.count >= 8 ? 2 : 1

                if dist > 0 && dist <= maxAllowedDist {
                    matchedTarget = target
                    break
                }
            }

            if var target = matchedTarget {
                if isCapitalized, let first = target.first {
                    target = String(first.uppercased()) + target.dropFirst()
                }
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

    /// Checks if a string contains Cyrillic characters
    private func isCyrillic(_ s: String) -> Bool {
        s.unicodeScalars.contains { $0.value >= 0x0400 && $0.value <= 0x04FF }
    }

    /// Detects if word is an inflected grammatical form of target (cases: -а, -у, -е, -ом, -ем, -ами, -ях, etc.)
    private func isRussianCaseInflection(word: String, target: String) -> Bool {
        let w = word.lowercased()
        let t = target.lowercased()
        
        guard w != t else { return false }
        
        let minCommonPrefixLen = min(4, min(w.count, t.count) - 1)
        guard minCommonPrefixLen >= 3 else { return false }
        
        let prefixW = w.prefix(minCommonPrefixLen)
        let prefixT = t.prefix(minCommonPrefixLen)
        guard prefixW == prefixT else { return false }
        
        // Common Russian noun, adjective, and verb case/inflection endings
        let russianInflectionEndings: [String] = [
            "а", "я", "у", "ю", "е", "о", "ё", "ом", "ем", "ём", "ами", "ями", "ы", "и",
            "ей", "ов", "ев", "ях", "ах", "ам", "ям", "ого", "его", "ому", "ему", "ым", "им",
            "ую", "юю", "ой", "ей", "ою", "ею", "ых", "их", "ыми", "ими", "ости", "остей",
            "ский", "ского", "скому", "ским", "ском", "ская", "ской", "скую", "ское", "ские", "ских", "скими"
        ]
        
        let suffixW = String(w.dropFirst(minCommonPrefixLen))
        let suffixT = String(t.dropFirst(minCommonPrefixLen))
        
        return russianInflectionEndings.contains(suffixW) || russianInflectionEndings.contains(suffixT)
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
