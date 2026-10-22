import Foundation
import AppKit
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
        "досимпл": "doSimple",
        "до симпл": "doSimple",
        "до-симпл": "doSimple",
        "дусимпл": "doSimple",
        "ду симпл": "doSimple",
        "dosimple": "doSimple",
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
        "джемини": "Gemini",
        "бесзел": "Beszel",
        "безел": "Beszel",
        "беззел": "Beszel",
        "бесзэл": "Beszel",
        "клаудфлейр": "Cloudflare",
        "клаудфлер": "Cloudflare",
        "графана": "Grafana",
        "портейнер": "Portainer",
        "кулифай": "Coolify",
        "докплой": "Dokploy",
        "висперкит": "WhisperKit",
        "виспер кит": "WhisperKit",
        "фастапи": "FastAPI",
        "фаст апи": "FastAPI"
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
            // Guardrail: Never transliterate Latin words into Cyrillic
            if !isCyrillic(phonetic) && isCyrillic(canonical) {
                continue
            }

            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: phonetic))\\b"
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                result = regex.stringByReplacingMatches(
                    in: result,
                    options: [],
                    range: NSRange(location: 0, length: result.utf16.count),
                    withTemplate: NSRegularExpression.escapedTemplate(for: canonical)
                )
            }
        }

        // 2. Exact Case-Insensitive Vocabulary Alignment
        let cleanVocabulary = vocabulary
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).normalizedPlainVocabularyWord() }
            .filter { $0.count >= 2 }
            .sorted { $0.count > $1.count } // Match multi-word phrases and longer terms before shorter sub-terms

        for term in cleanVocabulary {
            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: term))\\b"
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                result = regex.stringByReplacingMatches(
                    in: result,
                    options: [],
                    range: NSRange(location: 0, length: result.utf16.count),
                    withTemplate: NSRegularExpression.escapedTemplate(for: term)
                )
            }
        }

        // 3. Levenshtein Fuzzy Alignment for Longer Single-Word Custom & Built-in Vocabulary (>5 chars)
        let singleWordCleanVocab = cleanVocabulary.filter { $0.count >= 5 && !$0.contains(" ") }
        let combinedTargets = (builtInDictionaryTargets + singleWordCleanVocab).filter { !$0.contains(" ") }
        if !combinedTargets.isEmpty {
            result = applyLevenshteinAlignment(text: result, targets: combinedTargets)
        }

        // 4. Cross-Script Phonetic Skeleton Alignment for Active Screen & Custom Latin Identifiers
        let latinTargets = singleWordCleanVocab.filter { !isCyrillic($0) && $0.count >= 5 }
        if !latinTargets.isEmpty && isCyrillic(result) {
            result = applyCrossScriptPhoneticAlignment(text: result, latinTargets: latinTargets)
        }

        return result
    }

    // MARK: - Dynamic Cross-Script Phonetic Skeleton Alignment

    private func applyCrossScriptPhoneticAlignment(text: String, latinTargets: [String]) -> String {
        let precomputedTargets: [(target: String, skeleton: String)] = latinTargets.compactMap { t in
            let skel = Self.latinPhoneticSkeleton(t)
            guard skel.count >= 4 else { return nil }
            return (t, skel)
        }
        guard !precomputedTargets.isEmpty else { return text }

        let punctuationSet = CharacterSet.punctuationCharacters
        let words = text.components(separatedBy: " ")
        var adjusted: [String] = []
        var i = 0

        while i < words.count {
            let word = words[i]
            let cleanWord = word.trimmingCharacters(in: punctuationSet)

            // Check single unrecognized Cyrillic word against Latin targets
            if cleanWord.count >= 5 && isCyrillic(cleanWord) && !Self.protectedWords.contains(cleanWord.lowercased()) && !isValidDictionaryWord(cleanWord) {
                let cyrSkel = Self.cyrillicPhoneticSkeleton(cleanWord)
                if cyrSkel.count >= 4 {
                    var bestTarget: String? = nil
                    for item in precomputedTargets {
                        guard cyrSkel.first == item.skeleton.first else { continue }
                        let dist = levenshteinDistance(cyrSkel, item.skeleton)
                        let maxDist = item.skeleton.count >= 7 ? 2 : 1
                        if dist <= maxDist {
                            bestTarget = item.target
                            break
                        }
                    }
                    if let matched = bestTarget {
                        let prefixScalars = word.unicodeScalars.prefix(while: { punctuationSet.contains($0) })
                        let suffixScalars = word.unicodeScalars.reversed().prefix(while: { punctuationSet.contains($0) }).reversed()
                        let prefix = String(String.UnicodeScalarView(prefixScalars))
                        let suffix = String(String.UnicodeScalarView(suffixScalars))
                        adjusted.append("\(prefix)\(matched)\(suffix)")
                        i += 1
                        continue
                    }
                }
            }

            adjusted.append(word)
            i += 1
        }

        return adjusted.joined(separator: " ")
    }

    private static func cyrillicPhoneticSkeleton(_ word: String) -> String {
        let map: [Character: String] = [
            "а": "a", "б": "b", "в": "v", "г": "g", "д": "d", "е": "e", "ё": "o",
            "ж": "j", "з": "z", "и": "i", "й": "i", "к": "k", "л": "l", "м": "m",
            "н": "n", "о": "o", "п": "p", "р": "r", "с": "s", "т": "t", "у": "u",
            "ф": "f", "х": "h", "ц": "s", "ч": "c", "ш": "s", "щ": "s", "ъ": "",
            "ы": "i", "ь": "", "э": "e", "ю": "u", "я": "a"
        ]
        var raw = ""
        for ch in word.lowercased() {
            if let mapped = map[ch] {
                raw += mapped
            } else if ch.isLetter || ch.isNumber {
                raw.append(ch)
            }
        }
        return collapseDuplicates(raw)
    }

    private static func latinPhoneticSkeleton(_ word: String) -> String {
        var s = word.lowercased()
        let replacements: [(String, String)] = [
            ("ph", "f"), ("ck", "k"), ("qu", "kv"), ("sh", "s"), ("ch", "c"),
            ("th", "t"), ("sz", "z"), ("oo", "u"), ("ee", "i"), ("ea", "i"),
            ("ai", "ei"), ("ay", "ei"), ("ce", "se"), ("ci", "si"), ("cy", "si"),
            ("x", "ks"), ("w", "v"), ("c", "k"), ("y", "i"), ("j", "j")
        ]
        for (k, v) in replacements {
            s = s.replacingOccurrences(of: k, with: v)
        }
        // Drop silent trailing 'e' on longer words (e.g. Simple -> simpl, Supabase -> supabas)
        if s.count >= 5 && s.hasSuffix("e") {
            s.removeLast()
        }
        s = s.filter { $0.isLetter || $0.isNumber }
        return collapseDuplicates(s)
    }

    private static func collapseDuplicates(_ s: String) -> String {
        var out = ""
        var prev: Character? = nil
        for ch in s {
            if ch != prev {
                out.append(ch)
                prev = ch
            }
        }
        return out
    }

    // MARK: - Levenshtein Distance Matching

    /// Protected high-frequency grammatical words, pronouns, and conjunctions that must never be altered by fuzzy Levenshtein alignment
    private static let protectedWords: Set<String> = [
        "такое", "также", "тоже", "такой", "такая", "такие", "таким", "таком", "таких", "такому", "такую",
        "только", "всегда", "когда", "зачем", "почему", "потом", "затем", "здесь", "везде",
        "много", "мало", "очень", "точно", "прямо", "скоро", "долго", "часто", "редко",
        "about", "their", "there", "these", "those", "which", "where", "would", "could", "should"
    ]

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

            let lowerClean = cleanWord.lowercased()
            if Self.protectedWords.contains(lowerClean) {
                adjustedWords.append(word)
                continue
            }

            // A real dictionary word was most likely spoken as-is: never bend it toward a vocabulary term
            // ("Describe" must not become "Scribe", "planet" must not become "plane").
            if isValidDictionaryWord(cleanWord) {
                adjustedWords.append(word)
                continue
            }

            let isCapitalized = cleanWord.first?.isUppercase == true

            var matchedTarget: String? = nil
            for target in targets {
                // SCRIPT GUARD: Never cross scripts between Latin and Cyrillic
                if isCyrillic(cleanWord) != isCyrillic(target) {
                    continue
                }

                // If the word has Cyrillic characters, verify it is not a valid grammatical case inflection
                if isCyrillic(cleanWord) && isCyrillic(target) {
                    if isRussianCaseInflection(word: cleanWord, target: target) {
                        // Never overwrite inflected Russian case forms with dictionary nominatives
                        continue
                    }
                }

                let dist = levenshteinDistance(cleanWord.lowercased(), target.lowercased())
                let maxAllowedDist = cleanWord.count >= 8 ? 2 : 1
                let sameFirstLetter = cleanWord.lowercased().first == target.lowercased().first

                if dist > 0 && dist <= maxAllowedDist && (dist == 1 || sameFirstLetter) {
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

    /// True when the system spellchecker accepts the word in its script's language (ru for Cyrillic, en otherwise).
    private func isValidDictionaryWord(_ word: String) -> Bool {
        let lang = isCyrillic(word) ? "ru" : "en"
        var wordCount = 0
        let range = NSSpellChecker.shared.checkSpelling(
            of: word,
            startingAt: 0,
            language: lang,
            wrap: false,
            inSpellDocumentWithTag: 0,
            wordCount: &wordCount
        )
        return range.location == NSNotFound || range.length == 0
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
