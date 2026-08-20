import AppKit
import Foundation
import OSLog

private let logger = Logger(subsystem: "com.aleksei.scribe", category: "AetherContextEngine")

/// Aether Context Biasing & Anti-Hallucination Engine (Stage A):
/// Captures active target application context, dynamically biases acoustic and language models,
/// and applies context-aware blocked word lists to eliminate out-of-domain hallucinations.
public final class AetherContextEngine: @unchecked Sendable {

    public static let shared = AetherContextEngine()

    private init() {}

    public enum AppDomain: String, CaseIterable, Identifiable, Sendable {
        case ideAndCoding = "ideAndCoding"
        case messengersAndChat = "messengersAndChat"
        case notesAndWriting = "notesAndWriting"
        case browsersAndResearch = "browsersAndResearch"
        case designAndCreative = "designAndCreative"
        case cryptoAndTrading = "cryptoAndTrading"
        case general = "general"

        public var id: String { rawValue }

        public var displayName: String {
            switch self {
            case .ideAndCoding: return "IDE & Vibe Coding"
            case .messengersAndChat: return "Messengers & Chat"
            case .notesAndWriting: return "Notes & Writing"
            case .browsersAndResearch: return "Browser & Research"
            case .designAndCreative: return "Design & Creative"
            case .cryptoAndTrading: return "Crypto & Web3"
            case .general: return "General System"
            }
        }

        public var icon: String {
            switch self {
            case .ideAndCoding: return "chevron.left.forwardslash.chevron.right"
            case .messengersAndChat: return "bubble.left.and.bubble.right.fill"
            case .notesAndWriting: return "note.text"
            case .browsersAndResearch: return "safari.fill"
            case .designAndCreative: return "paintpalette.fill"
            case .cryptoAndTrading: return "bitcoinsign.circle.fill"
            case .general: return "macwindow"
            }
        }
    }

    // MARK: - App Domain Detection

    /// Determines the domain of the target or frontmost application
    public func detectActiveAppDomain(targetApp: NSRunningApplication? = nil) -> (name: String, domain: AppDomain, bundleId: String) {
        let app = targetApp ?? NSWorkspace.shared.frontmostApplication
        let name = app?.localizedName ?? "General"
        let bundleId = (app?.bundleIdentifier ?? "").lowercased()
        let nameLower = name.lowercased()

        // 1. IDEs, Terminals & Code Editors
        if bundleId.contains("xcode") ||
           bundleId.contains("vscode") ||
           bundleId.contains("cursor") ||
           bundleId.contains("antigravity") ||
           bundleId.contains("windsurf") ||
           bundleId.contains("zed") ||
           bundleId.contains("terminal") ||
           bundleId.contains("iterm") ||
           bundleId.contains("warp") ||
           bundleId.contains("kitty") ||
           bundleId.contains("alacritty") ||
           bundleId.contains("ghostty") ||
           bundleId.contains("intellij") ||
           bundleId.contains("pycharm") ||
           bundleId.contains("webstorm") ||
           bundleId.contains("clion") ||
           bundleId.contains("sublime") ||
           bundleId.contains("android.studio") ||
           nameLower.contains("cursor") ||
           nameLower.contains("xcode") ||
           nameLower.contains("terminal") {
            return (name, .ideAndCoding, bundleId)
        }

        // 2. Messengers, Social & Team Chat
        if bundleId.contains("telegram") ||
           bundleId.contains("slack") ||
           bundleId.contains("discord") ||
           bundleId.contains("whatsapp") ||
           bundleId.contains("messages") ||
           bundleId.contains("viber") ||
           bundleId.contains("signal") ||
           bundleId.contains("mattermost") ||
           bundleId.contains("wechat") ||
           bundleId.contains("skype") ||
           nameLower.contains("telegram") ||
           nameLower.contains("slack") ||
           nameLower.contains("discord") {
            return (name, .messengersAndChat, bundleId)
        }

        // 3. Notes, Documents & Writing
        if bundleId.contains("notion") ||
           bundleId.contains("obsidian") ||
           bundleId.contains("notes") ||
           bundleId.contains("bear") ||
           bundleId.contains("craft") ||
           bundleId.contains("ulysses") ||
           bundleId.contains("pages") ||
           bundleId.contains("word") ||
           bundleId.contains("scrivener") ||
           bundleId.contains("textedit") ||
           nameLower.contains("notion") ||
           nameLower.contains("obsidian") ||
           nameLower.contains("notes") {
            return (name, .notesAndWriting, bundleId)
        }

        // 4. Browsers & Research
        if bundleId.contains("safari") ||
           bundleId.contains("chrome") ||
           bundleId.contains("arc") ||
           bundleId.contains("brave") ||
           bundleId.contains("firefox") ||
           bundleId.contains("edge") ||
           bundleId.contains("orion") ||
           bundleId.contains("opera") ||
           bundleId.contains("vivaldi") ||
           nameLower.contains("safari") ||
           nameLower.contains("chrome") ||
           nameLower.contains("arc") {
            return (name, .browsersAndResearch, bundleId)
        }

        // 5. Design & Creative Tools
        if bundleId.contains("figma") ||
           bundleId.contains("sketch") ||
           bundleId.contains("photoshop") ||
           bundleId.contains("illustrator") ||
           bundleId.contains("aftereffects") ||
           bundleId.contains("blender") ||
           bundleId.contains("finalcut") ||
           bundleId.contains("davinci") ||
           bundleId.contains("canva") ||
           nameLower.contains("figma") {
            return (name, .designAndCreative, bundleId)
        }

        // 6. Crypto & Web3 Trading
        if bundleId.contains("tradingview") ||
           bundleId.contains("binance") ||
           bundleId.contains("bybit") ||
           bundleId.contains("metamask") ||
           bundleId.contains("tonkeeper") ||
           bundleId.contains("phantom") ||
           nameLower.contains("tradingview") ||
           nameLower.contains("binance") {
            return (name, .cryptoAndTrading, bundleId)
        }

        return (name, .general, bundleId)
    }

    // MARK: - Domain-Specific Vocabulary Biasing

    /// Specialized vocabulary injected to prime Whisper and Apple Speech for the active domain
    public func domainSpecificVocabulary(for domain: AppDomain) -> [String] {
        switch domain {
        case .ideAndCoding:
            return [
                "vibe coding", "Claude Code", "Antigravity", "Antigravity 2.0", "Ollama", "PyTorch", "WhisperKit",
                "TypeScript", "SwiftUI", "SwiftData", "Rust", "Next.js", "TailwindCSS", "PostgreSQL", "GraphQL",
                "Docker", "Kubernetes", "Supabase", "Vercel", "GitHub", "GitLab", "Xcode", "VS Code", "Terminal",
                "API", "SDK", "JSON", "regex", "refactor", "pull request", "commit", "merge", "branch", "async",
                "await", "struct", "class", "enum", "endpoint", "backend", "frontend", "fullstack", "MCP",
                "коммит", "пул реквест", "ветка", "деплой", "баг", "пофиксить", "рефакторинг", "функция", "эндпоинт"
            ]
        case .messengersAndChat:
            return [
                "топчик", "swag", "анскилл", "вайб", "кринж", "хайп", "краш", "чилл", "флекс", "рофл", "пруф",
                "найс", "скилл", "созвон", "митинг", "апдейт", "чекни", "сейчас", "встретимся", "ок", "норм",
                "Telegram", "Discord", "Slack", "WhatsApp", "Messages", "Signal"
            ]
        case .notesAndWriting:
            return [
                "Markdown", "Summary", "Action items", "Roadmap", "Checklist", "Overview", "Apple Notes", "Obsidian",
                "Notion", "Заметки", "План", "Задачи", "Выводы", "Структура", "Раздел", "Черновик", "Итоги"
            ]
        case .browsersAndResearch:
            return [
                "Google", "GitHub", "Wikipedia", "Reddit", "YouTube", "Twitter", "X.com", "Stack Overflow",
                "Documentation", "Search", "URL", "Статья", "Поиск", "Документация", "Ссылка"
            ]
        case .designAndCreative:
            return [
                "Figma", "Auto Layout", "Frame", "Component", "Variant", "Typography", "Padding", "Margin",
                "Gradient", "Layer", "Vector", "Bezier", "Render", "Keyframe", "Фрейм", "Компонент", "Слои", "Макет"
            ]
        case .cryptoAndTrading:
            return [
                "Bitcoin", "Ethereum", "Solana", "TON", "USDT", "TRC20", "ERC20", "Swap", "Liquidity", "Gas fee",
                "Wallet", "Staking", "Short", "Long", "Futures", "Spot", "Tonkeeper", "MetaMask", "Bybit", "Binance"
            ]
        case .general:
            return []
        }
    }

    // MARK: - Domain-Specific Blocked Words (Anti-Hallucination Matrix)

    /// Words and phrases that should NEVER be used or hallucinated in the given domain
    public func domainSpecificBlockedWords(for domain: AppDomain) -> [String] {
        // Universal Whisper subtitle hallucination artifacts
        let universalHallucinations = [
            "Субтитры сделал", "Субтитры создавал", "Субтитры добавил", "Редактор субтитров",
            "Корректор", "Продолжение следует", "Спасибо за просмотр", "Ставьте лайки",
            "Подписывайтесь на канал", "Amara.org", "Subtitles by", "Thank you for watching",
            "Translated by", "Next episode", "Смотрите в следующей серии", "Озвучено специально для"
        ]

        switch domain {
        case .ideAndCoding:
            // In IDEs & coding, block generic YouTube/streaming outro noise and conversational spam
            return universalHallucinations + [
                "Поставьте лайк и колокольчик", "До новых встреч в эфире", "Всем пока-пока", "Приятного аппетита"
            ]
        case .messengersAndChat:
            // In Messengers, block accidental code boilerplate hallucinations
            return universalHallucinations + [
                "<!DOCTYPE html>", "public static void main", "SELECT * FROM", "return 0;", "console.log"
            ]
        case .notesAndWriting:
            // In Notes, block streaming & chat spam
            return universalHallucinations + [
                "Ставьте лайк", "Донаты на стриме", "Ссылка в описании под видео"
            ]
        case .browsersAndResearch, .designAndCreative, .cryptoAndTrading, .general:
            return universalHallucinations
        }
    }

    // MARK: - Dynamic Effective Mergers

    /// Merges user custom vocabulary with target application domain vocabulary
    public func activeEffectiveVocabulary(targetApp: NSRunningApplication? = nil, userVocabulary: String) -> String {
        let (_, domain, _) = detectActiveAppDomain(targetApp: targetApp)
        let domainWords = domainSpecificVocabulary(for: domain)
        
        let userWords = userVocabulary.components(separatedBy: CharacterSet(charactersIn: ",\n;"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var combined = userWords
        for w in domainWords {
            if !combined.contains(where: { $0.caseInsensitiveCompare(w) == .orderedSame }) {
                combined.append(w)
            }
        }
        return combined.joined(separator: ", ")
    }

    /// Merges user blocked words with domain-specific anti-hallucination lists
    public func activeEffectiveBlockedWords(targetApp: NSRunningApplication? = nil, userBlockedWords: String) -> String {
        let (_, domain, _) = detectActiveAppDomain(targetApp: targetApp)
        let domainBlocked = domainSpecificBlockedWords(for: domain)

        let userBlocked = userBlockedWords.components(separatedBy: CharacterSet(charactersIn: ",\n;"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var combined = userBlocked
        for b in domainBlocked {
            if !combined.contains(where: { $0.caseInsensitiveCompare(b) == .orderedSame }) {
                combined.append(b)
            }
        }
        return combined.joined(separator: ", ")
    }

    // MARK: - Acoustic Conditioning Prompts

    /// Constructs domain-specific contextual priming hints
    public func domainContextPrompt(for domain: AppDomain, language: String?) -> String {
        let lang = (language ?? "").lowercased()
        let isRussianOnly = lang.starts(with: "ru")
        let isEnglishOnly = lang.starts(with: "en")

        switch domain {
        case .ideAndCoding:
            if isRussianOnly {
                return "Контекст разработки кода, терминала, вайб кодинга и IDE: Git, Swift, TypeScript, Python, Docker, API, PR, commit, merge, branch, function, async, await, deploy, bugs, проект, ветка, коммит, пофиксить."
            } else if isEnglishOnly {
                return "Code development, terminal & vibe coding context: Git, Swift, TypeScript, Python, Docker, API, PR, commit, merge, branch, function, async, await, deploy, bugs, refactor."
            } else {
                return "Bilingual code development & vibe coding context (Russian & English): Git, Swift, Xcode, TypeScript, Python, Docker, API, PR, commit, merge, branch, function, async, await, deploy, bugs, проект, ветка, коммит, функция, правка."
            }
        case .messengersAndChat:
            if isRussianOnly {
                return "Разговорная переписка в мессенджере с естественной пунктуацией, запятыми, сленгом и эмодзи."
            } else if isEnglishOnly {
                return "Casual chat and messaging context with natural punctuation, commas, and modern abbreviations."
            } else {
                return "Casual multilingual chat (Russian & English): естественная переписка, messaging, пунктуация, commas, сленг, эмодзи."
            }
        case .notesAndWriting:
            if isRussianOnly {
                return "Структурированные заметки, документы, списки и заголовки с четкой пунктуацией."
            } else if isEnglishOnly {
                return "Structured documentation, notes, outlines, and clear punctuation."
            } else {
                return "Structured notes & documentation (Russian & English): заметки, списки, headers, punctuation, форматирование."
            }
        case .browsersAndResearch:
            if isRussianOnly {
                return "Поисковые запросы, веб-страницы, статьи и интернет-навигация."
            } else if isEnglishOnly {
                return "Web search queries, browser research, websites, and technical articles."
            } else {
                return "Web search & browser research (Russian & English): поиск, статьи, URL, websites, research."
            }
        case .designAndCreative:
            if isRussianOnly {
                return "Дизайн-термины, верстка макетов, компоненты, фреймы, шрифты и графика."
            } else if isEnglishOnly {
                return "UI/UX design, Figma components, frames, vector artboards, and creative terminology."
            } else {
                return "UI/UX & graphic design context: Figma, auto layout, frames, components, макеты, шрифты."
            }
        case .cryptoAndTrading:
            if isRussianOnly {
                return "Криптовалюты, блокчейн, кошельки, токены, стейкинг и трейдинг."
            } else if isEnglishOnly {
                return "Crypto, Web3, blockchain transactions, wallets, tokens, staking, and trading."
            } else {
                return "Crypto & Web3 context: Bitcoin, Ethereum, Solana, TON, USDT, кошелек, стейкинг, trading."
            }
        case .general:
            if isRussianOnly {
                return "Используйте правильную пунктуацию, запятые и заглавные буквы."
            } else if isEnglishOnly {
                return "Use proper punctuation, capitalization, and formatting."
            } else {
                return "Multilingual Russian and English speech: правильная пунктуация, commas, capitalization, заглавные буквы."
            }
        }
    }

    /// Generates a comprehensive prompt string conditioned on active app, location, and custom vocabulary
    public func buildConditioningPrompt(
        basePrompt: String,
        customVocabulary: String,
        userLocation: String = "",
        targetApp: NSRunningApplication? = nil,
        language: String?
    ) -> String {
        let (appName, domain, _) = detectActiveAppDomain(targetApp: targetApp)
        let domainHint = domainContextPrompt(for: domain, language: language)

        var components: [String] = []
        components.append(basePrompt)

        if domain != .general {
            components.append("App: \(appName). \(domainHint)")
        }

        if !userLocation.isEmpty {
            let isRussian = language == "ru" || language == nil
            let locHeader = isRussian ? "Локации и адреса:" : "Locations and streets:"
            let addressAffixes = isRussian
                ? "ул., улица, проспект, бульвар, переулок, шоссе, набережная, дом, корп., стр., кв."
                : "st., ave, blvd, road, drive, lane, apt, suite, bldg"
            components.append("\(locHeader) \(userLocation), \(addressAffixes).")
        }

        let effectiveVocab = activeEffectiveVocabulary(targetApp: targetApp, userVocabulary: customVocabulary)
        if !effectiveVocab.isEmpty {
            components.append("Custom Terms: \(effectiveVocab).")
        }

        return components.joined(separator: " ")
    }

    /// Extracts clean contextual words array for Apple Speech contextualStrings
    public func buildContextualStrings(
        customVocabulary: String,
        userLocation: String = "",
        targetApp: NSRunningApplication? = nil
    ) -> [String] {
        var strings: [String] = []

        // Add effective vocabulary (user + domain)
        let effectiveVocab = activeEffectiveVocabulary(targetApp: targetApp, userVocabulary: customVocabulary)
        let customWords = effectiveVocab
            .components(separatedBy: CharacterSet(charactersIn: ",\n;"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        strings.append(contentsOf: customWords)

        // Add user locations & street indicators
        if !userLocation.isEmpty {
            let locWords = userLocation
                .components(separatedBy: CharacterSet(charactersIn: ",\n;"))
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            strings.append(contentsOf: locWords)
            strings.append(contentsOf: ["ул.", "улица", "проспект", "бульвар", "набережная", "переулок", "шоссе", "дом", "корпус", "строение", "квартира", "метро", "Street", "Avenue", "Boulevard", "Road"])
        }

        return Array(Set(strings)).prefix(120).map { $0 }
    }
}
