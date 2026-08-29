import Foundation
import OSLog

private let logger = Logger(subsystem: "com.aleksei.scribe", category: "ScribeMode")

/// Scribe Dictation & Intelligence Modes.
/// Enables specialized on-device speech-to-text processing for developers, writers, and casual chat.
public enum ScribeMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case clean = "clean"       // Default: filler removal, clean punctuation, brand casing
    case raw = "raw"           // Exact verbatim transcription, zero removal
    case code = "code"         // Dev & code: transforms camelCase, snake_case, CLI flags (--flag, -f), file extensions, backticks
    case chat = "chat"         // Concise, chat-friendly, conversational punctuation, spoken emoji recognition
    case formal = "formal"     // Polished, business/email tone, full sentences

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .clean: return "Clean"
        case .raw: return "Raw (Verbatim)"
        case .code: return "Code & Dev"
        case .chat: return "Chat & Messaging"
        case .formal: return "Email & Formal"
        }
    }

    public var localizedName: String {
        switch self {
        case .clean: return String(localized: "mode.clean", defaultValue: "Clean")
        case .raw: return String(localized: "mode.raw", defaultValue: "Raw")
        case .code: return String(localized: "mode.code", defaultValue: "Code")
        case .chat: return String(localized: "mode.chat", defaultValue: "Chat")
        case .formal: return String(localized: "mode.formal", defaultValue: "Formal")
        }
    }

    public var icon: String {
        switch self {
        case .clean: return "sparkles"
        case .raw: return "waveform"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .chat: return "bubble.left.and.bubble.right.fill"
        case .formal: return "envelope.fill"
        }
    }

    public var shortDescription: String {
        switch self {
        case .clean: return "Smart filler removal & clean punctuation."
        case .raw: return "Verbatim speech without any filtering."
        case .code: return "camelCase, snake_case, CLI flags & code syntax."
        case .chat: return "Concise punctuation for Telegram & Slack."
        case .formal: return "Polished grammar for emails & documents."
        }
    }

    public var fullDescription: String {
        switch self {
        case .clean:
            return "Automatically removes verbal clutter (uh, um, эээ, ну типа, короче), fixes capitalization, and standardizes tech terminology."
        case .raw:
            return "Preserves every spoken word exactly as uttered by the model without conversational truncation or filler stripping."
        case .code:
            return "Transforms spoken programming constructs (e.g. 'camel case userId' → userId, 'flag force' → --force, 'dot ts' → .ts, 'const data' → const data)."
        case .chat:
            return "Optimized for messengers: trims heavy sentence-ending periods in single-line replies and converts spoken emojis (👍, 🔥, 🚀)."
        case .formal:
            return "Polishes colloquial speech into articulate, formal business prose with full punctuation and professional phrasing."
        }
    }

    public var description: String {
        fullDescription
    }
}

/// On-device intelligent text processor for Scribe Modes
public final class ScribeModeProcessor: @unchecked Sendable {
    public static let shared = ScribeModeProcessor()

    private init() {}

    /// Russian & English filler words and hesitations for .clean and .formal modes
    private let fillerPatterns: [String] = [
        // Russian hesitations
        "(?i)\\b(?:э+м+|э+э+|м+м+|м+г+м+|а+а+|у+у+|ы+ы+)\\b[,\\s]*",
        "(?i)\\b(?:ну\\s+типа|ну\\s+как\\s+бы|как\\s+бы|так\\s+сказать|знаешь\\s+ли|короче\\s+говоря|в\\s+общем-то\\s+говоря|собственно\\s+говоря)\\b[,\\s]*",
        "(?i)^\\s*(?:ну|слушай|короче|смотри|так)\\s*,\\s*",
        // English hesitations
        "(?i)\\b(?:uh+|um+|er+|ah+|hm+|huh+)\\b[,\\s]*",
        "(?i)\\b(?:you\\s+know|like\\s*,\\s*you\\s+know|sort\\s+of|kind\\s+of|basically|I\\s+mean)\\b[,\\s]*",
        "(?i)^\\s*(?:like|well|so)\\s*,\\s*"
    ]

    /// Spoken emojis for .chat mode
    private let emojiMap: [(pattern: String, emoji: String)] = [
        ("(?i)\\b(?:смайлик\\s+огонь|эмодзи\\s+огонь|fire\\s+emoji)\\b", "🔥"),
        ("(?i)\\b(?:смайлик\\s+палец\\s+вверх|палец\\s+вверх|лайк|thumbs\\s+up)\\b", "👍"),
        ("(?i)\\b(?:смайлик\\s+палец\\s+вниз|дизлайк|thumbs\\s+down)\\b", "👎"),
        ("(?i)\\b(?:смайлик\\s+ракета|эмодзи\\s+ракета|rocket\\s+emoji)\\b", "🚀"),
        ("(?i)\\b(?:смайлик\\s+сердце|красное\\s+сердце|heart\\s+emoji)\\b", "❤️"),
        ("(?i)\\b(?:смайлик\\s+смех|ржу|смеющийся\\s+смайлик|joy\\s+emoji|laughing\\s+emoji)\\b", "😂"),
        ("(?i)\\b(?:смайлик\\s+череп|skull\\s+emoji)\\b", "💀"),
        ("(?i)\\b(?:смайлик\\s+хлопки|аплодисменты|clapping\\s+emoji)\\b", "👏"),
        ("(?i)\\b(?:смайлик\\s+глаза|eyes\\s+emoji)\\b", "👀"),
        ("(?i)\\b(?:смайлик\\s+галочка|зеленая\\s+галочка|check\\s+mark)\\b", "✅"),
        ("(?i)\\b(?:смайлик\\s+крестик|красный\\s+крестик|cross\\s+mark)\\b", "❌")
    ]

    /// Spoken code conventions for .code mode
    private let codeRules: [(pattern: String, template: String)] = [
        // Spoken file extensions
        ("(?i)\\b(?:точка|dot)\\s+([a-z0-9_]+)\\b", ".$1"),
        ("(?i)\\b(?:слеш|slash)\\s+([a-z0-9_.-]+)", "/$1"),
        // CLI flags
        ("(?i)\\b(?:минус\\s+минус|минус-минус|флаг|дабл\\s+дэш|double\\s+dash|dash\\s+dash)\\s+([a-z0-9_-]+)\\b", "--$1"),
        ("(?i)\\b(?:минус|дэш|dash)\\s+([a-zA-Z0-9])\\b", "-$1"),
        // Operators
        ("(?i)\\b(?:стрелочная\\s+функция|стрелочная\\s+стрелка|arrow\\s+function)\\b", "=>"),
        ("(?i)\\b(?:равно\\s+равно\\s+равно|три\\s+равно|тройное\\s+равно|triple\\s+equals?)\\b", "==="),
        ("(?i)\\b(?:равно\\s+равно|два\\s+равно|double\\s+equals?)\\b", "=="),
        ("(?i)\\b(?:не\\s+равно|восклицательный\\s+знак\\s+равно|not\\s+equal)\\b", "!=="),
        ("(?i)\\b(?:больше\\s+или\\s+равно|greater\\s+than\\s+or\\s+equal)\\b", ">="),
        ("(?i)\\b(?:меньше\\s+или\\s+равно|less\\s+than\\s+or\\s+equal)\\b", "<="),
        ("(?i)\\b(?:двойной\\s+амперсанд|логическое\\s+и|double\\s+ampersand)\\b", "&&"),
        ("(?i)\\b(?:двойной\\s+пайп|логическое\\s+или|double\\s+pipe)\\b", "||"),
        // Keywords
        ("(?i)\\b(?:конст|const)\\s+([a-zA-Z0-9_]+)", "const $1"),
        ("(?i)\\b(?:лет|let)\\s+([a-zA-Z0-9_]+)", "let $1"),
        ("(?i)\\b(?:асинк|async)\\s+(?:функция|func|function|деф|def)\\b", "async function"),
        ("(?i)\\b(?:эвейт|await)\\s+([a-zA-Z0-9_.]+)", "await $1"),
        ("(?i)\\b(?:ретурн|return)\\s+([a-zA-Z0-9_.]+)", "return $1")
    ]

    /// Applies the specified ScribeMode to the transcribed text
    public func process(text: String, mode: ScribeMode) -> String {
        guard !text.isEmpty else { return text }

        switch mode {
        case .raw:
            // Verbatim output: zero filtering
            return text

        case .clean:
            // Standard cleanup: remove fillers, normalize duplicate spaces, fix punctuation
            var result = removeFillerWords(text)
            result = normalizePunctuation(result)
            return result

        case .code:
            // Developer transformations
            var result = removeFillerWords(text)
            result = transformCaseIdentifiers(result)
            result = applyCodeRules(result)
            result = normalizePunctuation(result)
            return result

        case .chat:
            // Messenger transformations: remove heavy fillers, spoken emojis, trim formal period if short
            var result = removeFillerWords(text)
            result = applyEmojis(result)
            result = formatForChat(result)
            return result

        case .formal:
            // Polished prose
            var result = removeFillerWords(text)
            result = formalizeColloquialisms(result)
            result = normalizePunctuation(result)
            return result
        }
    }

    // MARK: - Internal Transformation Helpers

    private func removeFillerWords(_ text: String) -> String {
        var result = text
        for pattern in fillerPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let range = NSRange(result.startIndex..<result.endIndex, in: result)
                result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "")
            }
        }
        // Collapse multiple spaces
        if let multiSpace = try? NSRegularExpression(pattern: "[ \\t]{2,}") {
            let range = NSRange(result.startIndex..<result.endIndex, in: result)
            result = multiSpace.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: " ")
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func transformCaseIdentifiers(_ text: String) -> String {
        var result = text

        // 1. camelCase: "кэмел кейс user profile id" / "camel case user profile id" -> "userProfileId"
        let camelPattern = "(?i)\\b(?:кэмел[\\s-]*кейс|camel[\\s-]*case)\\s+([a-zA-Z0-9]+(?:\\s+[a-zA-Z0-9]+)*)"
        if let regex = try? NSRegularExpression(pattern: camelPattern) {
            let matches = regex.matches(in: result, options: [], range: NSRange(location: 0, length: (result as NSString).length))
            for match in matches.reversed() {
                if let fullRange = Range(match.range, in: result),
                   let wordsRange = Range(match.range(at: 1), in: result) {
                    let words = String(result[wordsRange]).components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                    if let first = words.first {
                        let camel = first.lowercased() + words.dropFirst().map { $0.capitalized }.joined()
                        result.replaceSubrange(fullRange, with: camel)
                    }
                }
            }
        }

        // 2. snake_case: "снейк кейс user profile id" / "snake case user profile id" -> "user_profile_id"
        let snakePattern = "(?i)\\b(?:снейк[\\s-]*кейс|snake[\\s-]*case)\\s+([a-zA-Z0-9]+(?:\\s+[a-zA-Z0-9]+)*)"
        if let regex = try? NSRegularExpression(pattern: snakePattern) {
            let matches = regex.matches(in: result, options: [], range: NSRange(location: 0, length: (result as NSString).length))
            for match in matches.reversed() {
                if let fullRange = Range(match.range, in: result),
                   let wordsRange = Range(match.range(at: 1), in: result) {
                    let words = String(result[wordsRange]).components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                    let snake = words.map { $0.lowercased() }.joined(separator: "_")
                    result.replaceSubrange(fullRange, with: snake)
                }
            }
        }

        // 3. kebab-case: "кебаб кейс my custom button" / "kebab case my custom button" -> "my-custom-button"
        let kebabPattern = "(?i)\\b(?:кебаб[\\s-]*кейс|kebab[\\s-]*case)\\s+([a-zA-Z0-9]+(?:\\s+[a-zA-Z0-9]+)*)"
        if let regex = try? NSRegularExpression(pattern: kebabPattern) {
            let matches = regex.matches(in: result, options: [], range: NSRange(location: 0, length: (result as NSString).length))
            for match in matches.reversed() {
                if let fullRange = Range(match.range, in: result),
                   let wordsRange = Range(match.range(at: 1), in: result) {
                    let words = String(result[wordsRange]).components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                    let kebab = words.map { $0.lowercased() }.joined(separator: "-")
                    result.replaceSubrange(fullRange, with: kebab)
                }
            }
        }

        // 4. PascalCase: "паскаль кейс user auth service" / "pascal case user auth service" -> "UserAuthService"
        let pascalPattern = "(?i)\\b(?:паскаль[\\s-]*кейс|pascal[\\s-]*case)\\s+([a-zA-Z0-9]+(?:\\s+[a-zA-Z0-9]+)*)"
        if let regex = try? NSRegularExpression(pattern: pascalPattern) {
            let matches = regex.matches(in: result, options: [], range: NSRange(location: 0, length: (result as NSString).length))
            for match in matches.reversed() {
                if let fullRange = Range(match.range, in: result),
                   let wordsRange = Range(match.range(at: 1), in: result) {
                    let words = String(result[wordsRange]).components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                    let pascal = words.map { $0.capitalized }.joined()
                    result.replaceSubrange(fullRange, with: pascal)
                }
            }
        }

        // 5. SCREAMING_SNAKE_CASE: "скрим кейс max buffer size" -> "MAX_BUFFER_SIZE"
        let screamPattern = "(?i)\\b(?:скрим[\\s-]*кейс|screaming[\\s-]*snake[\\s-]*case)\\s+([a-zA-Z0-9]+(?:\\s+[a-zA-Z0-9]+)*)"
        if let regex = try? NSRegularExpression(pattern: screamPattern) {
            let matches = regex.matches(in: result, options: [], range: NSRange(location: 0, length: (result as NSString).length))
            for match in matches.reversed() {
                if let fullRange = Range(match.range, in: result),
                   let wordsRange = Range(match.range(at: 1), in: result) {
                    let words = String(result[wordsRange]).components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                    let scream = words.map { $0.uppercased() }.joined(separator: "_")
                    result.replaceSubrange(fullRange, with: scream)
                }
            }
        }

        return result
    }

    private func applyCodeRules(_ text: String) -> String {
        var result = text
        for rule in codeRules {
            if let regex = try? NSRegularExpression(pattern: rule.pattern) {
                let range = NSRange(result.startIndex..<result.endIndex, in: result)
                result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: rule.template)
            }
        }
        return result
    }

    private func applyEmojis(_ text: String) -> String {
        var result = text
        for (pattern, emoji) in emojiMap {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let range = NSRange(result.startIndex..<result.endIndex, in: result)
                result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: emoji)
            }
        }
        return result
    }

    private func formatForChat(_ text: String) -> String {
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // If it's a short 1-line message and ends with a single period, remove the period for natural casual chat flow
        if !result.contains("\n") && result.count <= 60 && result.hasSuffix(".") && !result.hasSuffix("...") && !result.hasSuffix("…") {
            result = String(result.dropLast()).trimmingCharacters(in: .whitespaces)
        }
        return result
    }

    private func formalizeColloquialisms(_ text: String) -> String {
        var result = text
        let colloquialMap: [(pattern: String, replacement: String)] = [
            ("(?i)\\bщас\\b", "сейчас"),
            ("(?i)\\bща\\b", "сейчас"),
            ("(?i)\\bче\\b", "что"),
            ("(?i)\\bчо\\b", "что"),
            ("(?i)\\bнорм\\b", "хорошо"),
            ("(?i)\\bплиз\\b", "пожалуйста"),
            ("(?i)\\bспс\\b", "спасибо"),
            ("(?i)\\bинфа\\b", "информация"),
            ("(?i)\\bgonna\\b", "going to"),
            ("(?i)\\bwanna\\b", "want to"),
            ("(?i)\\bkinda\\b", "kind of")
        ]
        for (pat, rep) in colloquialMap {
            if let regex = try? NSRegularExpression(pattern: pat) {
                let range = NSRange(result.startIndex..<result.endIndex, in: result)
                result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: rep)
            }
        }
        return result
    }

    private func normalizePunctuation(_ text: String) -> String {
        var result = text
        // Fix space before punctuation (e.g. "word , next" -> "word, next")
        if let spaceBeforePunct = try? NSRegularExpression(pattern: "\\s+([,.:;!?])") {
            let range = NSRange(result.startIndex..<result.endIndex, in: result)
            result = spaceBeforePunct.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "$1")
        }
        // Ensure space after punctuation if followed by a word character
        if let spaceAfterPunct = try? NSRegularExpression(pattern: "([,.:;!?])([a-zA-Zа-яА-ЯёЁ])") {
            let range = NSRange(result.startIndex..<result.endIndex, in: result)
            result = spaceAfterPunct.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "$1 $2")
        }
        return result
    }
}
