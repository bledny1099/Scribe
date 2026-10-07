import AppKit
import Foundation
import OSLog

private let logger = Logger(subsystem: "com.aleksei.scribe", category: "AetherContextEngine")

/// Aether Context Biasing & Multilingual Anti-Hallucination Engine (Stage A):
/// Captures active target application context, dynamically biases acoustic and language models,
/// and applies language-filtered, context-aware blocked word lists to eliminate out-of-domain hallucinations.
public final class AetherContextEngine: @unchecked Sendable {

    public static let shared = AetherContextEngine()

    private init() {}

    public enum AppDomain: String, CaseIterable, Identifiable, Sendable {
        case ideAndCoding = "ideAndCoding"
        case aiChatAndLLMs = "aiChatAndLLMs"
        case messengersAndChat = "messengersAndChat"
        case notesAndWriting = "notesAndWriting"
        case browsersAndResearch = "browsersAndResearch"
        case designAndCreative = "designAndCreative"
        case cryptoAndTrading = "cryptoAndTrading"
        case medicalAndHealth = "medicalAndHealth"
        case nutritionAndBiohacking = "nutritionAndBiohacking"
        case citiesAndLocations = "citiesAndLocations"
        case general = "general"

        public var id: String { rawValue }

        public var displayName: String {
            switch self {
            case .ideAndCoding: return "IDE & Vibe Coding"
            case .aiChatAndLLMs: return "AI Assistants & LLMs"
            case .messengersAndChat: return "Messengers & Chat"
            case .notesAndWriting: return "Notes & Writing"
            case .browsersAndResearch: return "Browser & Research"
            case .designAndCreative: return "Design & Creative"
            case .cryptoAndTrading: return "Crypto & Web3"
            case .medicalAndHealth: return "Medicine & Diagnostics"
            case .nutritionAndBiohacking: return "Nutrition & Biohacking"
            case .citiesAndLocations: return "Cities & Locations"
            case .general: return "General System"
            }
        }

        public var description: String {
            switch self {
            case .ideAndCoding:
                return "Optimized for coding agents, IDEs, Codex, Git, terminals & vibe coding."
            case .aiChatAndLLMs:
                return "Optimized for AI chat, prompts & local models: Gemini, Claude, Kimi, ChatGPT, LM Studio, Ollama."
            case .messengersAndChat:
                return "Optimized for quick messaging, chat slang & natural punctuation."
            case .notesAndWriting:
                return "Optimized for documents, structured lists & Markdown notes."
            case .browsersAndResearch:
                return "Optimized for web searches, documentation & articles."
            case .designAndCreative:
                return "Optimized for UI/UX, layouts, design tokens & typography."
            case .cryptoAndTrading:
                return "Optimized for web3, tokens, blockchain protocols & trading."
            case .medicalAndHealth:
                return "Optimized for medical terms, pharmacology, clinical diagnostics & diseases."
            case .nutritionAndBiohacking:
                return "Optimized for nutrition, vitamins, minerals, amino acids & metabolic pathways."
            case .citiesAndLocations:
                return "Optimized for global cities, island archipelagos, streets, avenues, districts & geolocation navigation."
            case .general:
                return "Balanced system-wide dictation with smart auto-casing."
            }
        }

        public var icon: String {
            switch self {
            case .ideAndCoding: return "chevron.left.forwardslash.chevron.right"
            case .aiChatAndLLMs: return "sparkles"
            case .messengersAndChat: return "bubble.left.and.bubble.right.fill"
            case .notesAndWriting: return "note.text"
            case .browsersAndResearch: return "safari.fill"
            case .designAndCreative: return "paintpalette.fill"
            case .cryptoAndTrading: return "bitcoinsign.circle.fill"
            case .medicalAndHealth: return "cross.case.fill"
            case .nutritionAndBiohacking: return "leaf.fill"
            case .citiesAndLocations: return "mappin.and.ellipse"
            case .general: return "macwindow"
            }
        }
    }

    // MARK: - Specialized Coding Agent Profile

    public enum CodingAgentProfile: String, CaseIterable, Identifiable, Sendable {
        case claudeCode = "claudeCode"
        case cursor = "cursor"
        case antigravity = "antigravity"
        case xcode = "xcode"
        case windsurf = "windsurf"
        case terminal = "terminal"
        case genericCoding = "genericCoding"
        case none = "none"

        public var id: String { rawValue }

        public var displayName: String {
            switch self {
            case .claudeCode: return "Claude Code"
            case .cursor: return "Cursor"
            case .antigravity: return "Antigravity & Codex"
            case .xcode: return "Xcode"
            case .windsurf: return "Windsurf"
            case .terminal: return "Terminal & Shell"
            case .genericCoding: return "IDE & Coding"
            case .none: return "General System"
            }
        }

        public var icon: String {
            switch self {
            case .claudeCode: return "terminal.fill"
            case .cursor: return "cursorarrow.rays"
            case .antigravity: return "atom"
            case .xcode: return "hammer.fill"
            case .windsurf: return "water.waves"
            case .terminal: return "apple.terminal.fill"
            case .genericCoding: return "chevron.left.forwardslash.chevron.right"
            case .none: return "macwindow"
            }
        }
    }

    // MARK: - Specialized Agent Vocabularies

    public static let claudeCodeVocabulary: [String] = [
        "Claude Code", "CLAUDE.md", "/compact", "/cost", "/review", "/pr", "/init", "/memory", "/doctor", "/clear", "/resume", "/config",
        "MCP", "MCP server", "Model Context Protocol", "subagent", "subagents", "invoke_subagent",
        "extended thinking", "thinking budget", "reasoning tokens", "prompt caching", "cache creation", "cache read",
        "Claude 3.7 Sonnet", "Claude 3.5 Sonnet", "Claude 3.5 Haiku", "Claude 3 Opus", "Anthropic",
        "compact context", "context compaction", "cost analysis", "pull request", "vibe coding",
        "клод", "клод код", "компакт", "сделай компакт", "сожми контекст", "косты", "токены", "контекстное окно",
        "память проекта", "субагент", "запусти субагента", "сделай ревью", "создай PR", "пулреквест", "сделай коммит",
        "поправь CLAUDE.md", "МСП", "MCP сервер", "MCP тулы", "бюджет рассуждений", "расширенные рассуждения",
        "промпт кэширование", "запусти тесты", "проверь линтер", "задеплой", "пофикси", "рефакторинг"
    ]

    public static let cursorVocabulary: [String] = [
        "Cursor", "Composer", ".cursorrules", "cursorrules", "Cursor Tab", "@Files", "@Docs", "@Web", "@Git", "@Code", "@Folders",
        "Shadow Workspace", "Notepad", "Notepads", "Apply Diff", "Accept All", "Reject All", "Partial Accept", "Inline Chat",
        "Generate Edit", "Fast Mode", "Agent Mode", "Composer Chat", "Codebase Indexing", "Semantic Search", "Symbol Search",
        "композер", "курсор", "курсоррулс", "примени диф", "прими изменения", "отклони изменения", "открой композер",
        "проиндексируй код", "сгенерируй диф", "частичный акцепт", "добавь в контекст", "вайб-кодинг"
    ]

    public static let antigravityVocabulary: [String] = [
        "Antigravity", "Codex", "Codex CLI", "Antigravity 2.0", "Browser Subagent", "Artifacts", "SKILL.md", "Reactive Wakeup",
        "Subagent", "Subagents", "invoke_subagent", "browser_subagent", "run_command", "replace_file_content", "view_file",
        "write_to_file", "grep_search", "list_dir", "task scheduler", "background task", "conversation transcript", "MCP",
        "антигравити", "кодекс", "браузер агент", "артефакты", "скилл", "субагент", "делегируй", "запусти команду",
        "создай файл", "проверь логи", "реактивный вейкап"
    ]

    public static let xcodeVocabulary: [String] = [
        "Xcode", "SwiftUI", "SwiftData", "Swift 6", "Concurrency", "Sendable", "Actor", "MainActor", "ModelContainer", "#Preview",
        "Instruments", "Time Profiler", "Memory Leaks", "CoreML", "Apple Neural Engine", "Metal", "TestFlight", "Notarization",
        "DerivedData", "Archive", "Scheme", "Build Phase", "Podfile", "Package.swift", "SPM", "ViewBuilder", "StateObject",
        "ObservedObject", "EnvironmentObject", "экскод", "свифт", "свифтдата", "акторы", "изоляция актора", "профайлер",
        "утечки памяти", "нотаризация", "превью", "схема сборки", "пакеты свифт"
    ]

    public static let windsurfVocabulary: [String] = [
        "Windsurf", "Cascade", "Supercomplete", "Codeium", "Memories", "Cascade Agent", "Context Awareness", "Flow State",
        "Collaborative Agent", "Terminal Sync", "виндсерф", "каскад", "суперкомплит", "меморис", "агент каскад", "контекст проекта"
    ]

    public static let terminalVocabulary: [String] = [
        "Terminal", "Zsh", "Ghostty", "iTerm", "Warp", "Kitty", "Alacritty", "Tmux", "Git", "worktree", "git rebase",
        "docker compose", "Dockerfile", "fzf", "zoxide", "ripgrep", "awk", "sed", "sudo", "chmod", "chown", "ssh", "rsync",
        "brew", "npm", "pnpm", "yarn", "cargo", "pip", "curl", "wget", "killall", "pgrep", "lsof", "терминал", "ребейз",
        "ворктри", "докер компоуз", "засквошь коммиты", "алиасы", "скрипт", "пайплайн", "процесс"
    ]

    public static func specializedVocabulary(for profile: CodingAgentProfile) -> [String] {
        switch profile {
        case .claudeCode: return claudeCodeVocabulary
        case .cursor: return cursorVocabulary
        case .antigravity: return antigravityVocabulary
        case .xcode: return xcodeVocabulary
        case .windsurf: return windsurfVocabulary
        case .terminal: return terminalVocabulary
        case .genericCoding, .none: return []
        }
    }

    // MARK: - Multilingual Subtitle & Outro Hallucination Matrix

    public static let multilingualHallucinationsByLanguage: [String: [String]] = [
        "ru": [
            "Субтитры создал", "Субтитры создавал", "Субтитры создавала", "Субтитры добавил",
            "Редактор субтитров", "Корректор", "Продолжение следует", "Спасибо за просмотр",
            "Ставьте лайки", "Подписывайтесь на канал", "Поставьте лайк и колокольчик",
            "До новых встреч в эфире", "Всем пока-пока", "Приятного аппетита",
            "Озвучено специально для", "Ссылка в описании под видео", "Донаты на стриме",
            "Смотрите в следующей серии", "Переведено и озвучено", "Ставьте лайк"
        ],
        "en": [
            "Subtitles by", "Subtitle by", "Subtitles created by", "Translated by",
            "Thank you for watching", "Thanks for watching", "Please subscribe",
            "Like and subscribe", "Don't forget to like and subscribe", "Hit the bell icon",
            "See you in the next video", "To be continued", "Closed captions by",
            "Captions by", "Amara.org", "Next episode", "Link in the description",
            "Support on Patreon", "Thanks for tuning in"
        ],
        "es": [
            "Subtítulos por", "Subtítulos creados por", "Subtítulos realizados por", "Traducido por",
            "Gracias por ver", "Gracias por ver el video", "Muchas gracias por ver",
            "Suscríbete al canal", "Suscríbete", "Dale like y suscríbete",
            "No olvides suscribirte", "Activa la campanita", "Nos vemos en el próximo video",
            "Continuará", "Enlace en la descripción"
        ],
        "de": [
            "Untertitel von", "Untertitel erstellt von", "Übersetzt von",
            "Vielen Dank fürs Zuschauen", "Danke fürs Zuschauen", "Vielen Dank fürs Zusehen",
            "Kanal abonnieren", "Bitte abonnieren", "Glocke aktivieren", "Daumen nach oben",
            "Bis zum nächsten Video", "Fortsetzung folgt", "Link in der Beschreibung"
        ],
        "fr": [
            "Sous-titres par", "Sous-titres réalisés par", "Traduit par",
            "Merci d'avoir regardé", "Merci d'avoir regardé la vidéo", "Merci de votre attention",
            "Abonnez-vous à la chaîne", "N'oubliez pas de vous abonner", "Activez la cloche",
            "À bientôt pour une nouvelle vidéo", "À suivre", "Lien dans la description"
        ],
        "it": [
            "Sottotitoli di", "Sottotitoli a cura di", "Tradotto da",
            "Grazie per la visione", "Grazie per aver guardato", "Grazie di aver visto il video",
            "Iscriviti al canale", "Lascia un like e iscriviti", "Attiva la campanella",
            "Ci vediamo nel prossimo video", "Continua...", "Link in descrizione"
        ],
        "pt": [
            "Legendas por", "Legendas criadas por", "Traduzido por",
            "Obrigado por assistir", "Obrigado por assistir ao vídeo", "Valeu por assistir",
            "Inscreva-se no canal", "Deixe o seu like e se inscreva", "Ative o sininho",
            "Nos vemos no próximo vídeo", "Continua...", "Link na descrição"
        ],
        "zh": [
            "字幕由", "字幕制作", "翻译自", "感谢观看", "感谢收看", "非常感谢您的收看",
            "请订阅频道", "点赞并订阅", "开启小铃铛", "下期再见", "未完待续", "敬请期待"
        ],
        "ja": [
            "字幕作成", "翻訳者", "ご視聴ありがとうございました", "最後までご視聴いただき",
            "チャンネル登録お願いします", "高評価とチャンネル登録", "ベルマークを押して",
            "また次回の動画で", "つづく", "続く", "次回もお楽しみに"
        ],
        "uk": [
            "Субтитри створив", "Субтитри додано", "Перекладено", "Озвучено",
            "Дякую за перегляд", "Дякуємо за перегляд", "Підписуйтесь на канал",
            "Ставте лайки", "Тисніть на дзвіночок", "До зустрічі в наступному відео",
            "Далі буде", "Посилання в описі"
        ],
        "pl": [
            "Napisy stworzone przez", "Przetłumaczone przez", "Dziękuję za oglądanie",
            "Dzięki za obejrzenie", "Subskrybuj kanał", "Zostaw łapkę w górę",
            "Kliknij dzwoneczek", "Do zobaczenia w kolejnym filmie", "Ciąg dalszy nastąpi"
        ],
        "tr": [
            "Altyazı", "Altyazı hazırlayan", "Çeviren", "İzlediğiniz için teşekkürler",
            "İzlediğiniz için teşekkür ederiz", "Kanala abone olmayı unutmayın",
            "Beğenmeyi ve abone olmayı", "Bildirimleri açmayı unutmayın",
            "Bir sonraki videoda görüşmek üzere", "Devam edecek"
        ],
        "ko": [
            "자막 제작", "번역", "시청해 주셔서 감사합니다", "시청해주셔서 감사합니다",
            "구독과 좋아요", "알림 설정", "다음 영상에서 만나요", "계속됩니다"
        ],
        "ar": [
            "ترجمة", "شكرا للمشاهدة", "شكرا على المشاهدة", "اشترك в القناة",
            "لا تنسى الإعجاب والاشتراك", "تفعيل جرس التنبيهات", "إلى اللقاء في الفيديو القادم", "يتبع"
        ],
        "hi": [
            "सबटाइटल", "अनुवाद", "देखने के लिए धन्यवाद", "वीडियो देखने के लिए धन्यवाद",
            "चैनल को सब्सक्राइब करें", "लाइक और सब्सक्राइब करें", "अगले видео में मिलते हैं"
        ]
    ]

    /// Resolves and collects subtitle & video hallucination phrases ONLY for the requested recognition languages
    public func multilingualHallucinations(for recognitionLanguages: [String]) -> [String] {
        var normalizedCodes: Set<String> = []
        for lang in recognitionLanguages {
            let code = lang.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if code == "auto" || code.isEmpty {
                normalizedCodes.insert("ru")
                normalizedCodes.insert("en")
            } else if let prefix = code.split(separator: "-").first {
                normalizedCodes.insert(String(prefix))
            } else {
                normalizedCodes.insert(code)
            }
        }

        if normalizedCodes.isEmpty {
            normalizedCodes = ["ru", "en"]
        }

        var results: [String] = []
        for code in normalizedCodes {
            if let list = Self.multilingualHallucinationsByLanguage[code] {
                results.append(contentsOf: list)
            }
        }
        return Array(Set(results))
    }

    // MARK: - Specialized Coding Agent Profile Detection

    private static let terminalBundleHints = ["terminal", "iterm", "warp", "ghostty", "kitty", "alacritty", "wezterm", "tabby", "hyper"]
    private static let terminalNameHints = ["terminal", "iterm", "warp", "ghostty", "kitty", "alacritty", "wezterm"]
    private static let browserBundleHints = ["safari", "chrome", "chromium", "firefox", "brave", "microsoft.edge", "orion", "opera", "vivaldi", "company.thebrowser", "zen-browser", "yandex.browser"]

    private static func isTerminalEmulator(bundleId: String, nameLower: String) -> Bool {
        terminalBundleHints.contains { bundleId.contains($0) } || terminalNameHints.contains { nameLower.contains($0) }
    }

    private static func isBrowser(bundleId: String, nameLower: String) -> Bool {
        browserBundleHints.contains { bundleId.contains($0) } || nameLower == "arc"
    }

    /// Detects whether the active application is a specialized coding agent like Claude Code, Cursor, Xcode, etc.
    /// Window titles are only trusted inside terminals (CLI agents) so a browser tab titled "Cursor pricing"
    /// or "Xcode docs" never switches the recognizer into an IDE profile.
    public func detectCodingAgentProfile(targetApp: NSRunningApplication? = nil) -> CodingAgentProfile {
        let app = targetApp ?? NSWorkspace.shared.frontmostApplication
        let bundleId = (app?.bundleIdentifier ?? "").lowercased()
        let nameLower = (app?.localizedName ?? "").lowercased()

        if Self.isBrowser(bundleId: bundleId, nameLower: nameLower) {
            return .none
        }

        let isTerminal = Self.isTerminalEmulator(bundleId: bundleId, nameLower: nameLower)

        // Static bundle/name checks first: no Accessibility round-trip needed.
        if bundleId.contains("antigravity") || nameLower.contains("antigravity") ||
           bundleId.contains("codex") || nameLower.contains("codex") {
            return .antigravity
        }
        if bundleId.contains("cursor") || nameLower == "cursor" {
            return .cursor
        }
        if bundleId.contains("windsurf") || bundleId.contains("codeium") || nameLower.contains("windsurf") {
            return .windsurf
        }
        if bundleId == "com.apple.dt.xcode" || nameLower == "xcode" {
            return .xcode
        }

        let isGenericEditor = bundleId.contains("vscode") ||
            bundleId.contains("vscodium") ||
            bundleId.contains("trae") ||
            bundleId == "dev.zed.zed" ||
            bundleId.contains("fleet") ||
            bundleId.contains("intellij") ||
            bundleId.contains("pycharm") ||
            bundleId.contains("webstorm") ||
            bundleId.contains("clion") ||
            bundleId.contains("goland") ||
            bundleId.contains("sublime") ||
            bundleId.contains("android.studio") ||
            nameLower == "zed" ||
            nameLower.contains("visual studio code") ||
            nameLower == "trae"

        guard isTerminal || isGenericEditor else {
            return .none
        }

        // Title-based checks only for terminals (Claude Code / Codex CLI) and editors (Claude Code extension, .cursorrules).
        let winContext = inspectActiveWindowContext(targetApp: app)
        let windowTitleLower = (winContext.windowTitle ?? "").lowercased()
        let docFileNameLower = (winContext.documentFileName ?? "").lowercased()

        if isTerminal {
            if windowTitleLower.contains("claude") || docFileNameLower == "claude.md" {
                return .claudeCode
            }
            if windowTitleLower.contains("codex") {
                return .antigravity
            }
            return .terminal
        }

        // Generic editor
        if windowTitleLower.contains("claude code") || docFileNameLower == "claude.md" {
            return .claudeCode
        }
        if docFileNameLower == ".cursorrules" {
            return .cursor
        }
        return .genericCoding
    }

    // MARK: - App Domain Detection

    /// Determines the domain of the target or frontmost application
    public func detectActiveAppDomain(targetApp: NSRunningApplication? = nil) -> (name: String, domain: AppDomain, bundleId: String, icon: NSImage?) {
        let app = targetApp ?? NSWorkspace.shared.frontmostApplication
        let name = app?.localizedName ?? "General"
        let bundleId = (app?.bundleIdentifier ?? "").lowercased()
        let nameLower = name.lowercased()
        let icon: NSImage? = app?.icon ?? app?.bundleURL.map { NSWorkspace.shared.icon(forFile: $0.path) }

        // 0. Specialized Coding Agents (backend-only specialization; UI keeps the true application name)
        let profile = detectCodingAgentProfile(targetApp: app)
        if profile != .none && profile != .genericCoding {
            return (name, .ideAndCoding, bundleId, icon)
        }

        // 1. Other IDEs & code editors (terminals and agent IDEs are already covered by the profile above)
        if profile == .genericCoding || bundleId.contains("copilot") || nameLower.contains("copilot") {
            return (name, .ideAndCoding, bundleId, icon)
        }

        // 2. AI Assistants, Chatbots & Local LLMs (Gemini, Claude, Kimi, ChatGPT, LM Studio, Ollama, etc.)
        if bundleId.contains("chatgpt") ||
           bundleId.contains("openai") ||
           bundleId.contains("claude") ||
           bundleId.contains("anthropic") ||
           bundleId.contains("gemini") ||
           bundleId.contains("kimi") ||
           bundleId.contains("moonshot") ||
           bundleId.contains("perplexity") ||
           bundleId.contains("deepseek") ||
           bundleId.contains("ollama") ||
           bundleId.contains("lmstudio") ||
           bundleId.contains("bionic") ||
           bundleId.contains("jan.ai") ||
           bundleId.contains("quora.poe") ||
           nameLower.contains("chatgpt") ||
           nameLower.contains("claude") ||
           nameLower.contains("gemini") ||
           nameLower.contains("kimi") ||
           nameLower.contains("perplexity") ||
           nameLower.contains("deepseek") ||
           nameLower.contains("ollama") ||
           nameLower.contains("lm studio") ||
           nameLower.contains("lmstudio") ||
           nameLower.contains("bionic") ||
           nameLower == "poe" ||
           nameLower == "jan" {
            return (name, .aiChatAndLLMs, bundleId, icon)
        }

        // 3. Messengers, Social & Team Chat
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
            return (name, .messengersAndChat, bundleId, icon)
        }

        // 4. Notes, Documents & Writing
        if bundleId.contains("notion") ||
           bundleId.contains("obsidian") ||
           bundleId.contains("notes") ||
           bundleId.contains("shinyfrog.bear") ||
           bundleId.contains("lukilabs.craft") ||
           bundleId.contains("ulysses") ||
           bundleId.contains("iwork.pages") ||
           bundleId.contains("microsoft.word") ||
           bundleId.contains("scrivener") ||
           bundleId.contains("textedit") ||
           nameLower.contains("notion") ||
           nameLower.contains("obsidian") ||
           nameLower.contains("notes") {
            return (name, .notesAndWriting, bundleId, icon)
        }

        // 5. Browsers & Research
        if Self.isBrowser(bundleId: bundleId, nameLower: nameLower) {
            let winContext = inspectActiveWindowContext(targetApp: app)
            if let wt = winContext.windowTitle?.lowercased() {
                if wt.contains("v0.dev") || wt.contains("bolt.new") || wt.contains("antigravity") || wt.contains("codex") || wt.contains("github") {
                    return (name, .ideAndCoding, bundleId, icon)
                }
                if wt.contains("chatgpt") || wt.contains("claude") || wt.contains("gemini") ||
                   wt.contains("kimi") || wt.contains("perplexity") || wt.contains("deepseek") ||
                   wt.contains("ai studio") || wt.contains("ollama") || wt.contains("lm studio") || wt.contains("poe") {
                    return (name, .aiChatAndLLMs, bundleId, icon)
                }
            }
            return (name, .browsersAndResearch, bundleId, icon)
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
            return (name, .designAndCreative, bundleId, icon)
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
            return (name, .cryptoAndTrading, bundleId, icon)
        }

        // 7. Medical, Clinical & Health Apps
        if bundleId.contains("health") ||
           bundleId.contains("medscape") ||
           bundleId.contains("uptodate") ||
           bundleId.contains("epocrates") ||
           bundleId.contains("emias") ||
           nameLower.contains("health") ||
           nameLower.contains("medical") ||
           nameLower.contains("клиника") ||
           nameLower.contains("медицина") ||
           nameLower.contains("анализы") {
            return (name, .medicalAndHealth, bundleId, icon)
        }

        // 8. Nutrition, Fitness & Biohacking
        if bundleId.contains("myfitnesspal") ||
           bundleId.contains("yazio") ||
           bundleId.contains("cronometer") ||
           bundleId.contains("fatsecret") ||
           bundleId.contains("whoop") ||
           bundleId.contains("oura") ||
           nameLower.contains("fitness") ||
           nameLower.contains("diet") ||
           nameLower.contains("nutrition") {
            return (name, .nutritionAndBiohacking, bundleId, icon)
        }

        // 9. Cities, Maps, Travel & Navigation Apps
        if bundleId.contains("maps") ||
           bundleId.contains("navigation") ||
           bundleId.contains("yandexmaps") ||
           bundleId.contains("yandexnavi") ||
           bundleId.contains("2gis") ||
           bundleId.contains("doublegis") ||
           bundleId.contains("uber") ||
           bundleId.contains("careem") ||
           bundleId.contains("bolt") ||
           bundleId.contains("waze") ||
           bundleId.contains("citymapper") ||
           bundleId.contains("airbnb") ||
           bundleId.contains("booking") ||
           bundleId.contains("tripadvisor") ||
           bundleId.contains("flightradar") ||
           nameLower.contains("maps") ||
           nameLower.contains("карты") ||
           nameLower.contains("навигатор") ||
           nameLower.contains("такси") ||
           nameLower.contains("2gis") {
            return (name, .citiesAndLocations, bundleId, icon)
        }

        return (name, .general, bundleId, icon)
    }

    // MARK: - Domain-Specific Vocabulary Biasing

    /// Specialized vocabulary injected to prime Whisper and Apple Speech for the active domain
    public func domainSpecificVocabulary(for domain: AppDomain, targetApp: NSRunningApplication? = nil) -> [String] {
        let profile = detectCodingAgentProfile(targetApp: targetApp)
        let agentVocab = Self.specializedVocabulary(for: profile)
        if !agentVocab.isEmpty {
            return agentVocab + [
                "вайб-кодинг", "вайбкодинг", "vibe coding", "TypeScript", "SwiftUI",
                "SwiftData", "Rust", "Next.js", "TailwindCSS", "PostgreSQL", "Docker", "API", "SDK", "JSON",
                "regex", "refactor", "pull request", "commit", "merge", "branch", "async", "await", "deploy", "bugs"
            ]
        }

        switch domain {
        case .ideAndCoding:
            return [
                "вайб-кодинг", "вайбкодинг", "vibe coding", "Codex", "Codex CLI", "Claude Code", "Antigravity", "Antigravity 2.0",
                "TypeScript", "SwiftUI", "SwiftData", "Rust", "Next.js", "TailwindCSS", "PostgreSQL", "GraphQL",
                "Docker", "Kubernetes", "Supabase", "Vercel", "GitHub", "GitLab", "Xcode", "VS Code", "Terminal", "Copilot",
                "API", "SDK", "JSON", "regex", "refactor", "pull request", "commit", "merge", "branch", "async",
                "await", "struct", "class", "enum", "endpoint", "backend", "frontend", "fullstack", "MCP",
                "коммит", "пул реквест", "ветка", "деплой", "баг", "пофиксить", "рефакторинг", "функция", "эндпоинт",
                "сделай", "сделай что-то", "создай", "напиши", "добавь", "удали", "пофикси", "запусти", "проверь", "обнови", "настрой", "исправь", "покажи", "сгенерируй",
                "микросервисы", "Serverless", "ClickHouse", "Redis", "Kafka", "RabbitMQ", "gRPC", "Protobuf", "WebSockets", "FastAPI", "NestJS", "Prisma", "Drizzle ORM", "Shadcn UI", "Radix UI"
            ]
        case .aiChatAndLLMs:
            return [
                "Gemini", "Claude", "Kimi", "ChatGPT", "LM Studio", "LM Studio Bionic", "Ollama", "Perplexity", "DeepSeek",
                "Poe", "Jan", "LocalAI", "Bionic GPT", "GGUF", "LoRA", "QLoRA", "Hugging Face", "vLLM", "Llama", "Mistral", "Qwen",
                "DeepSeek-R1", "Claude 3.5 Sonnet", "Gemini 1.5 Pro", "GPT-4o", "o1", "o3-mini",
                "промпт", "системный промпт", "токены", "контекст", "температура", "инференс", "квантование", "эмбеддинги",
                "веса модели", "нейросеть", "чат-бот", "рассуждения", "промптинг",
                "system prompt", "reasoning", "chain of thought", "tokens", "inference", "context window", "temperature", "prompt engineering",
                "RAG", "Fine-tuning", "FlashAttention", "KV-cache", "Function Calling", "AI Agents", "LangGraph", "LlamaIndex"
            ]
        case .messengersAndChat:
            return [
                "топчик", "swag", "анскилл", "вайб", "кринж", "хайп", "краш", "чилл", "флекс", "рофл", "пруф",
                "найс", "скилл", "созвон", "митинг", "апдейт", "чекни", "сейчас", "встретимся", "ок", "норм",
                "Telegram", "Discord", "Slack", "WhatsApp", "Messages", "Signal",
                "масс-маркет", "люкс", "оверсайз", "дроп", "коллаб", "худи", "свитшот", "лоферы", "аутфит", "просекко", "апероль"
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
        case .medicalAndHealth:
            return [
                "Гипертензия", "Инфаркт миокарда", "Аритмия", "Инсульт", "Диабет", "Гипотиреоз", "Гастрит", "Пневмония", "Астма"
            ]
        case .nutritionAndBiohacking:
            return [
                "Витамин D3", "Витамин B12", "Витамин C", "Витамин K2", "Магний глицинат", "Магний треонат", "Цинк пиколинат",
                "Селен", "Омега-3", "EPA", "DHA", "Фосфолипиды", "Лецитин", "Холин", "Инозитол", "Коэнзим Q10", "NAD+", "NMN",
                "Берберин", "Глутатион", "NAC", "Ашваганда", "Ежовик гребенчатый", "Lion's Mane", "L-теанин", "Креатин", "BCAA",
                "Коллаген", "Пробиотики", "Пребиотики", "Микробиом", "БЖУ", "Кетоз", "Автофагия", "Инсулинорезистентность"
            ]
        case .citiesAndLocations:
            return [
                "Абу-Даби", "Abu Dhabi", "Саадият", "остров Саадият", "Saadiyat Island", "Яс", "остров Яс", "Yas Island",
                "Рим", "Аль-Рим", "остров Аль-Рим", "Al Reem Island", "Reem Island", "Аль-Марьях", "остров Аль-Марьях", "Al Maryah Island",
                "Джубайл", "остров Джубайл", "Jubail Island", "Худайрият", "остров Худайрият", "Hudayriyat Island",
                "Нурай", "остров Нурай", "Nurai Island", "Лулу", "остров Лулу", "Lulu Island", "Сир-Бани-Яс", "Sir Bani Yas",
                "Корниш", "Корниш Роуд", "Corniche Road", "Шейх Заед", "Шейх Зайд", "Sheikh Zayed Road", "Шейх Рашид Бин Саид",
                "улица Хамдан", "Hamdan Street", "улица Халифа", "Khalifa Street", "улица Электра", "Electra Street",
                "Аль-Салам", "Al Salam Street", "Аэропорт Роуд", "Airport Road", "Мурур Роуд", "Muroor Road",
                "Аль-Батин", "Al Bateen", "Аль-Халидия", "Al Khalidiyah", "Масдар Сити", "Masdar City", "Аль-Раха", "Al Raha Beach",
                "Аль-Риф", "Al Reef", "Халифа Сити", "Khalifa City", "Мохамед Бин Заед Сити", "MBZ City", "Дубай", "Dubai",
                "Палм-Джумейра", "Palm Jumeirah", "Блювотерс", "Bluewaters Island", "Дубай Марина", "Dubai Marina", "Даунтаун", "Downtown",
                "Бурдж-Халифа", "Burj Khalifa", "Бизнес Бэй", "Business Bay", "DIFC", "Сити Вок", "City Walk", "Ла Мер", "La Mer",
                "Манхэттен", "Manhattan", "Бруклин", "Brooklyn", "Оксфорд-стрит", "Oxford Street", "Сохо", "Soho",
                "Москва", "Moscow", "Тверская", "Арбат", "Патриаршие пруды", "Москва-Сити", "Санкт-Петербург", "Невский проспект",
                "Бали", "Bali", "Чангу", "Canggu", "Семиньяк", "Seminyak", "Убуд", "Ubud", "Сингапур", "Singapore", "Сентоза", "Sentosa Island"
            ]
        case .general:
            return [
                "Dom Perignon", "Moet & Chandon", "Veuve Clicquot", "Cristal", "Prosecco", "Chianti", "Bordeaux",
                "Cabernet Sauvignon", "Sauvignon Blanc", "Hennessy", "The Macallan", "Jameson", "Jack Daniel's",
                "Aperol Spritz", "Jagermeister", "Guinness", "Rolex", "Patek Philippe", "Audemars Piguet",
                "Vacheron Constantin", "Richard Mille", "Cartier", "Omega", "Breitling", "IWC", "Hublot",
                "TAG Heuer", "Tissot", "Casio", "G-Shock", "Louis Vuitton", "Hermes", "Chanel", "Dior",
                "Gucci", "Prada", "Saint Laurent", "Balenciaga", "Bottega Veneta", "Loro Piana", "Brunello Cucinelli",
                "Stone Island", "Supreme", "Stussy", "Massimo Dutti", "Zara", "H&M", "Uniqlo", "Nike", "Adidas",
                "New Balance", "масс-маркет", "люкс", "оверсайз", "тихая роскошь", "худи", "свитшот", "лоферы"
            ]
        }
    }

    // MARK: - Domain-Specific Blocked Words (Anti-Hallucination Matrix)

    /// Words and phrases that should NEVER be used or hallucinated in the given domain, filtered strictly for active languages
    public func domainSpecificBlockedWords(for domain: AppDomain, recognitionLanguages: [String] = []) -> [String] {
        let languageHallucinations = multilingualHallucinations(for: recognitionLanguages)

        switch domain {
        case .ideAndCoding:
            // In IDEs & coding, block language-filtered outro noise and streaming greetings
            var domainNoise: [String] = []
            if recognitionLanguages.contains(where: { $0.starts(with: "ru") }) || recognitionLanguages.isEmpty {
                domainNoise.append(contentsOf: ["Поставьте лайк и колокольчик", "До новых встреч в эфире", "Всем пока-пока", "Приятного аппетита"])
            }
            if recognitionLanguages.contains(where: { $0.starts(with: "en") }) || recognitionLanguages.isEmpty {
                domainNoise.append(contentsOf: ["Smash that like button", "See you next time", "Have a great day everyone"])
            }
            return languageHallucinations + domainNoise

        case .messengersAndChat:
            // In Messengers, block accidental code boilerplate hallucinations
            return languageHallucinations + [
                "<!DOCTYPE html>", "public static void main", "SELECT * FROM", "return 0;", "console.log"
            ]

        case .notesAndWriting:
            // In Notes, block streaming & chat spam
            var streamSpam: [String] = []
            if recognitionLanguages.contains(where: { $0.starts(with: "ru") }) || recognitionLanguages.isEmpty {
                streamSpam.append(contentsOf: ["Донаты на стриме", "Ссылка в описании под видео"])
            }
            if recognitionLanguages.contains(where: { $0.starts(with: "en") }) || recognitionLanguages.isEmpty {
                streamSpam.append(contentsOf: ["Donate on stream", "Check the link in the bio"])
            }
            return languageHallucinations + streamSpam

        case .aiChatAndLLMs, .browsersAndResearch, .designAndCreative, .cryptoAndTrading, .medicalAndHealth, .nutritionAndBiohacking, .citiesAndLocations, .general:
            return languageHallucinations
        }
    }

    // MARK: - Dynamic Effective Mergers

    /// Merges user custom vocabulary with target application domain vocabulary
    public func activeEffectiveVocabulary(targetApp: NSRunningApplication? = nil, userVocabulary: String, userLocation: String = "") -> String {
        let (_, domain, _, _) = detectActiveAppDomain(targetApp: targetApp)
        let domainWords = domainSpecificVocabulary(for: domain, targetApp: targetApp)
        
        var userWords = userVocabulary.components(separatedBy: CharacterSet(charactersIn: ",\n;"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).normalizedPlainVocabularyWord() }
            .filter { !$0.isEmpty }

        if !userLocation.isEmpty {
            let locWords = userLocation.components(separatedBy: CharacterSet(charactersIn: ",\n;"))
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).normalizedPlainVocabularyWord() }
                .filter { !$0.isEmpty }
            userWords.append(contentsOf: locWords)
        }

        var combined = userWords
        var seen = Set(userWords.map { $0.lowercased() })
        for w in domainWords {
            let norm = w.normalizedPlainVocabularyWord()
            if seen.insert(norm.lowercased()).inserted {
                combined.append(norm)
            }
        }
        return combined.joined(separator: ", ")
    }

    /// Merges user blocked words with domain-specific anti-hallucination lists for the given recognition languages
    public func activeEffectiveBlockedWords(
        targetApp: NSRunningApplication? = nil,
        userBlockedWords: String,
        recognitionLanguages: [String] = []
    ) -> String {
        let (_, domain, _, _) = detectActiveAppDomain(targetApp: targetApp)
        let domainBlocked = domainSpecificBlockedWords(for: domain, recognitionLanguages: recognitionLanguages)

        let userBlocked = userBlockedWords.components(separatedBy: CharacterSet(charactersIn: ",\n;"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var combined = userBlocked
        var seen = Set(userBlocked.map { $0.lowercased() })
        for b in domainBlocked where seen.insert(b.lowercased()).inserted {
            combined.append(b)
        }
        return combined.joined(separator: ", ")
    }

    // MARK: - Acoustic Conditioning Prompts

    /// Constructs domain-specific contextual priming hints
    public func domainContextPrompt(for domain: AppDomain, language: String?, targetApp: NSRunningApplication? = nil) -> String {
        let profile = detectCodingAgentProfile(targetApp: targetApp)
        let lang = (language ?? "").lowercased()
        let isRussianOnly = lang.starts(with: "ru")
        let isEnglishOnly = lang.starts(with: "en")

        switch profile {
        case .claudeCode:
            if isRussianOnly {
                return "Claude Code агент разработки: голосовые команды и директивы в повелительном наклонении (сделай, создай, добавь, напиши, удали, пофикси, запусти, проверь, обнови, настрой, сожми контекст, проверь косты, запусти субагента, сделай ревью, создай PR, задеплой), специализированные команды и термины (/compact, CLAUDE.md, /cost, /review, /pr, MCP сервер, субагенты, reasoning tokens, prompt caching, vibe coding)."
            } else if isEnglishOnly {
                return "Claude Code AI coding agent: imperative commands (create, make, do, add, write, delete, fix, run, check, update, configure, deploy), unique agent features and workflows (/compact, CLAUDE.md, /cost, /review, /pr, MCP protocol, subagents, reasoning tokens, prompt caching, vibe coding)."
            } else {
                return "Claude Code AI coding agent directives (Russian & English): /compact, CLAUDE.md, /cost, /review, /pr, MCP, subagent, reasoning tokens, prompt caching, vibe coding, сделай, создай, добавь, напиши, удали, пофикси, запусти, проверь, сожми контекст, проверь косты."
            }

        case .cursor:
            if isRussianOnly {
                return "Cursor IDE и Composer: голосовые директивы (открой композер, примени диф, прими изменения, отклони, примени ко всем, добавь в контекст), символы и фичи (Composer, .cursorrules, @Files, @Docs, @Web, @Git, Cursor Tab, Shadow Workspace, Notepads, vibe coding)."
            } else if isEnglishOnly {
                return "Cursor IDE & Composer directives: imperative commands (open composer, apply diff, accept all, reject, add to context), context symbols and features (Composer, .cursorrules, @Files, @Docs, @Web, @Git, Cursor Tab, Shadow Workspace, Notepads, vibe coding)."
            } else {
                return "Cursor IDE & Composer context (Russian & English): Composer, .cursorrules, @Files, @Docs, @Web, Apply Diff, Accept All, Cursor Tab, Notepads, открой композер, примени диф, прими изменения."
            }

        case .antigravity:
            if isRussianOnly {
                return "Antigravity & Codex автономный парный агент: голосовые директивы (запусти субагента, проверь браузер, создай артефакт, примени скилл, запусти команду, пофикси код), инструменты (Browser Subagent, Artifacts Engine, SKILL.md, Reactive Wakeup, MCP servers, replace_file_content, run_command, vibe coding)."
            } else if isEnglishOnly {
                return "Antigravity & Codex autonomous pair programmer: imperative commands (launch subagent, check browser, generate artifact, apply skill, run command, fix code), agent features (Browser Subagent, Artifacts Engine, SKILL.md, Reactive Wakeup, MCP servers, replace_file_content, run_command, vibe coding)."
            } else {
                return "Antigravity & Codex context (Russian & English): Browser Subagent, Artifacts, SKILL.md, Reactive Wakeup, MCP, subagent, run_command, replace_file_content, субагент, браузер агент, артефакты."
            }

        case .xcode:
            if isRussianOnly {
                return "Apple Xcode и Swift разработка: голосовые директивы (собери проект, запусти тесты, открой превью, проверь профайлер, пофикси утечки), термины (SwiftUI, SwiftData, Swift 6, Concurrency, Sendable, Actor, MainActor, ModelContainer, #Preview, Instruments, Time Profiler, CoreML, Apple Neural Engine, TestFlight, нотаризация)."
            } else if isEnglishOnly {
                return "Apple Xcode & Swift native development: commands (build project, run tests, open preview, profile instruments, fix leaks), architecture terms (SwiftUI, SwiftData, Swift 6, Concurrency, Sendable, Actor, MainActor, ModelContainer, #Preview, Instruments, Time Profiler, CoreML, Apple Neural Engine, TestFlight, Notarization)."
            } else {
                return "Xcode & Swift native development (Russian & English): SwiftUI, SwiftData, Swift 6, Concurrency, Sendable, Actor, ModelContainer, #Preview, Instruments, Time Profiler, акторы, изоляция актора, нотаризация."
            }

        case .windsurf:
            if isRussianOnly {
                return "Windsurf и Cascade агент разработки: голосовые команды (запусти каскад, примени правки, обнови память проекта), фичи (Cascade Agent, Supercomplete, Memories, Live Terminal Sync, Codeium, vibe coding)."
            } else if isEnglishOnly {
                return "Windsurf & Cascade collaborative agent: commands (run cascade, apply changes, update memories), features (Cascade Agent, Supercomplete, Memories, Live Terminal Sync, Codeium, vibe coding)."
            } else {
                return "Windsurf & Cascade agent context (Russian & English): Cascade Agent, Supercomplete, Memories, Live Terminal, Codeium, каскад, суперкомплит, vibe coding."
            }

        case .terminal:
            if isRussianOnly {
                return "Терминал, командная строка и DevOps: голосовые команды (сделай ребейз, создай ворктри, запусти докер, проверь процессы, открой сессию), утилиты (Zsh, Ghostty, iTerm, Warp, Tmux, git worktree, git rebase, docker compose, fzf, zoxide, ripgrep, sudo, ssh, brew)."
            } else if isEnglishOnly {
                return "Terminal, Shell & DevOps CLI: commands (rebase branch, create worktree, run docker, check processes, open session), CLI tools (Zsh, Ghostty, iTerm, Warp, Tmux, git worktree, git rebase, docker compose, fzf, zoxide, ripgrep, sudo, ssh, brew)."
            } else {
                return "Terminal & Shell DevOps context (Russian & English): git worktree, git rebase, docker compose, Zsh, Ghostty, Warp, Tmux, fzf, zoxide, ripgrep, ребейз, ворктри, докер компоуз."
            }

        case .genericCoding, .none:
            break
        }

        switch domain {
        case .ideAndCoding:
            if isRussianOnly {
                return "Вайб-кодинг, разработка и управление ИИ-агентами: голосовые директивы и команды в повелительном наклонении (сделай, сделай что-то, создай, добавь, напиши, удали, пофикси, запусти, проверь, обнови, настрой, открой, закрой, поменяй, переименуй, задеплой, исправь, покажи, сгенерируй, вайб-кодинг, вайбкодинг), термины разработки (Git, Swift, TypeScript, Python, Docker, API, PR, commit, merge, branch, function, async, await, deploy, bugs, MCP, Codex, Antigravity, Claude Code)."
            } else if isEnglishOnly {
                return "Vibe coding, IDE development, and AI agent instructions: imperative commands (create, make, do, add, write, delete, fix, run, check, update, configure, open, close, change, rename, deploy, show, vibe coding), programming terms (Git, Swift, TypeScript, Python, Docker, API, PR, commit, merge, branch, function, async, await, deploy, bugs, MCP, Codex, Antigravity, Claude Code)."
            } else {
                return "Bilingual vibe coding & IDE AI commands (Russian & English): вайб-кодинг, вайбкодинг, vibe coding, сделай, сделай что-то, создай, добавь, напиши, удали, пофикси, запусти, проверь, исправь, Git, Swift, Xcode, TypeScript, Python, Docker, API, PR, commit, merge, branch, function, async, await, deploy, bugs, MCP, Codex, Antigravity, Claude Code."
            }
        case .aiChatAndLLMs:
            if isRussianOnly {
                return "Промпты, диалоги с ИИ и управление моделями: Gemini, Claude, Kimi, ChatGPT, LM Studio, LM Studio Bionic, Ollama, DeepSeek, Perplexity, промпт, системный промпт, токены, контекст, температура, рассуждения, инференс, GGUF, LoRA, веса, квантование, нейросеть."
            } else if isEnglishOnly {
                return "AI chat, prompt engineering, and LLM reasoning: Gemini, Claude, Kimi, ChatGPT, LM Studio, LM Studio Bionic, Ollama, DeepSeek, Perplexity, system prompt, tokens, context window, temperature, inference, GGUF, LoRA, embeddings."
            } else {
                return "Multilingual AI chat & LLM prompts (Russian & English): Gemini, Claude, Kimi, ChatGPT, LM Studio, LM Studio Bionic, Ollama, DeepSeek, Perplexity, промпт, системный промпт, токены, контекст, температура, reasoning, tokens, inference."
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
                return "Структурированные заметки, документы, списки и заголовки с четкой пунктуацией: создай, добавь, план, задачи, выводы."
            } else if isEnglishOnly {
                return "Structured documentation, notes, outlines, and clear punctuation: create, add, plan, tasks, summary."
            } else {
                return "Structured notes & documentation (Russian & English): заметки, списки, headers, punctuation, форматирование."
            }
        case .browsersAndResearch:
            if isRussianOnly {
                return "Поисковые запросы, веб-страницы, статьи и интернет-навигация: найди, открой, поиск, документация."
            } else if isEnglishOnly {
                return "Web search queries, browser research, websites, and technical articles."
            } else {
                return "Web search & browser research (Russian & English): поиск, статьи, URL, websites, research."
            }
        case .designAndCreative:
            if isRussianOnly {
                return "Дизайн-термины, верстка макетов, компоненты, фреймы, шрифты и графика: сделай, добавь, выровняй, макеты, шрифты."
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
        case .medicalAndHealth:
            if isRussianOnly {
                return "Медицинский контекст, анализы, фармакология, процедуры и клиническая диагностика: МРТ, КТ, УЗИ, ЭКГ, биохимия, диагнозы, препараты."
            } else if isEnglishOnly {
                return "Clinical medical context, laboratory diagnostics, pharmacology, symptoms, and procedures: MRI, CT, ECG, CBC, diseases, medication."
            } else {
                return "Medical & clinical context (Russian & English): МРТ, КТ, УЗИ, ЭКГ, анализы, диагнозы, pharmacology, MRI, CT, healthcare."
            }
        case .nutritionAndBiohacking:
            if isRussianOnly {
                return "Нутрициология, биохакинг, метаболизм, витамины, минералы, добавки: Витамин D3, Омега-3, магний, микробиом, кетоз, БЖУ."
            } else if isEnglishOnly {
                return "Nutrition, biohacking, metabolic health, supplements, vitamins, and minerals: Vitamin D3, Omega-3, magnesium, microbiome, ketosis, macros."
            } else {
                return "Nutrition & biohacking context (Russian & English): витамины, добавки, нутрициология, Vitamin D3, Omega-3, magnesium, metabolism."
            }
        case .citiesAndLocations:
            if isRussianOnly {
                return "Города, острова, архипелаги, улицы, локации и навигация: Абу-Даби, остров Саадият, остров Яс, остров Аль-Рим, Аль-Марьях, Джубайл, Худайрият, Нурай, Корниш, Шейх Заед Роуд, Дубай, Палм-Джумейра, Дубай Марина, Даунтаун, Манхэттен, Москва, Бали, Сингапур."
            } else if isEnglishOnly {
                return "Cities, islands, archipelagos, streets, locations, and navigation context: Abu Dhabi, Saadiyat Island, Yas Island, Al Reem Island, Al Maryah, Jubail, Hudayriyat, Nurai, Corniche, Sheikh Zayed Road, Dubai, Palm Jumeirah, Dubai Marina, Downtown, Manhattan, London, Tokyo, Bali, Singapore."
            } else {
                return "Cities, islands, and locations context (Russian & English): Абу-Даби, Saadiyat Island, Yas Island, Al Reem Island, Al Maryah, Jubail, Corniche, Sheikh Zayed Road, Dubai, Palm Jumeirah, Marina, Downtown, Москва, London, Manhattan, Bali, Singapore."
            }
        case .general:
            if isRussianOnly {
                return "Команды и естественная речь: сделай, сделай что-то, создай, добавь, напиши, проверь, используйте правильную пунктуацию, запятые и заглавные буквы."
            } else if isEnglishOnly {
                return "Use proper punctuation, capitalization, and formatting."
            } else {
                return "Multilingual Russian and English speech: правильная пунктуация, commas, capitalization, заглавные буквы."
            }
        }
    }

    public func domainContextPrompt(for domain: AppDomain, language: String?) -> String {
        return domainContextPrompt(for: domain, language: language, targetApp: nil)
    }

    // MARK: - Window & Active Document Accessibility Context

    public struct WindowContext: Sendable {
        public let windowTitle: String?
        public let documentFileName: String?
        public let fileExtension: String?
        public let keywords: [String]
    }

    private static let emptyWindowContext = WindowContext(windowTitle: nil, documentFileName: nil, fileExtension: nil, keywords: [])
    private static let windowContextTTL: CFAbsoluteTime = 1.0
    private let windowContextLock = NSLock()
    private var cachedWindowContext: (pid: pid_t, timestamp: CFAbsoluteTime, value: WindowContext)?

    /// Inspects the frontmost active window title and open document name via Accessibility API (100% locally, no network).
    /// Results are cached per process for a short TTL: prompt building, vocabulary merging and domain detection all
    /// ask for the same window during one dictation, and each AX call is a synchronous IPC round-trip.
    public func inspectActiveWindowContext(targetApp: NSRunningApplication? = nil) -> WindowContext {
        guard AXIsProcessTrusted() else {
            return Self.emptyWindowContext
        }

        let app = targetApp ?? NSWorkspace.shared.frontmostApplication
        guard let pid = app?.processIdentifier else {
            return Self.emptyWindowContext
        }

        let now = CFAbsoluteTimeGetCurrent()
        windowContextLock.lock()
        if let cached = cachedWindowContext, cached.pid == pid, now - cached.timestamp < Self.windowContextTTL {
            windowContextLock.unlock()
            return cached.value
        }
        windowContextLock.unlock()

        let result = queryWindowContext(pid: pid)

        windowContextLock.lock()
        cachedWindowContext = (pid, CFAbsoluteTimeGetCurrent(), result)
        windowContextLock.unlock()
        return result
    }

    private func queryWindowContext(pid: pid_t) -> WindowContext {
        let appElement = AXUIElementCreateApplication(pid)
        // Default AX timeout is ~6s; a beachballing target app must never stall dictation.
        AXUIElementSetMessagingTimeout(appElement, 0.25)

        var focusedWindowValue: AnyObject?
        let copyRes = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedWindowValue)

        var title: String?
        var documentURL: String?

        if copyRes == .success, let windowRef = focusedWindowValue, CFGetTypeID(windowRef) == AXUIElementGetTypeID() {
            let window = windowRef as! AXUIElement
            AXUIElementSetMessagingTimeout(window, 0.25)
            // 1. Window Title
            var titleVal: AnyObject?
            if AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleVal) == .success,
               let t = titleVal as? String, !t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                title = t.trimmingCharacters(in: .whitespacesAndNewlines)
            }

            // 2. Document URL / Path
            var docVal: AnyObject?
            if AXUIElementCopyAttributeValue(window, kAXDocumentAttribute as CFString, &docVal) == .success,
               let doc = docVal as? String, !doc.isEmpty {
                documentURL = doc
            }
        }

        var fileName: String?
        var fileExt: String?
        var extractedKeywords: [String] = []

        if let doc = documentURL {
            // AXDocument is usually a percent-encoded file:// URL, sometimes a plain path.
            let url = doc.hasPrefix("file://") ? (URL(string: doc) ?? URL(fileURLWithPath: doc)) : URL(fileURLWithPath: doc)
            fileName = url.lastPathComponent
            fileExt = url.pathExtension.isEmpty ? nil : url.pathExtension
            if let fn = fileName { extractedKeywords.append(fn) }
        } else if let t = title {
            // Extract possible file name from title e.g. "auth.ts — Scribe — Cursor" or "SettingsView.swift"
            let components = t.components(separatedBy: CharacterSet(charactersIn: " —-–|/\\"))
            for comp in components {
                let trimmed = comp.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.contains(".") && trimmed.count >= 3 && trimmed.count <= 40 {
                    let ext = (trimmed as NSString).pathExtension
                    if !ext.isEmpty && ext.count <= 6 {
                        fileName = trimmed
                        fileExt = ext
                        extractedKeywords.append(trimmed)
                        break
                    }
                }
            }
            // Add clean keywords from window title (letters and digits, len >= 3)
            let rawWords = t.components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { $0.count >= 3 && $0.count <= 25 }
            for w in rawWords {
                if !extractedKeywords.contains(w) {
                    extractedKeywords.append(w)
                }
            }
        }

        return WindowContext(
            windowTitle: title,
            documentFileName: fileName,
            fileExtension: fileExt,
            keywords: Array(extractedKeywords.prefix(8))
        )
    }

    /// Generates a comprehensive prompt string conditioned on active app, location, and custom vocabulary
    public func buildConditioningPrompt(
        basePrompt: String,
        customVocabulary: String,
        userLocation: String = "",
        targetApp: NSRunningApplication? = nil,
        language: String?
    ) -> String {
        let (appName, domain, _, _) = detectActiveAppDomain(targetApp: targetApp)
        let domainHint = domainContextPrompt(for: domain, language: language, targetApp: targetApp)

        var components: [String] = []
        components.append(basePrompt)

        if domain != .general {
            components.append("App: \(appName). \(domainHint)")
        }

        // Local Window & Document Context (100% on-device)
        let winContext = inspectActiveWindowContext(targetApp: targetApp)
        if let fn = winContext.documentFileName {
            components.append("Active file: \(fn).")
        } else if let wt = winContext.windowTitle, !wt.isEmpty {
            let cleanTitle = String(wt.prefix(50))
            components.append("Window: \(cleanTitle).")
        }

        if !userLocation.isEmpty {
            let isRussian = language == "ru" || language == nil
            let locHeader = isRussian ? "Локации, острова и адреса:" : "Locations, islands and streets:"
            let addressAffixes = isRussian
                ? "остров, о., архипелаг, ул., улица, проспект, бульвар, переулок, шоссе, набережная, наб., площадь, пл., корп., стр., вл."
                : "island, isl., st., ave, blvd, road, drive, lane, apt, suite, bldg, crescent, way, walk, marina"
            components.append("\(locHeader) \(userLocation), \(addressAffixes).")
        }

        // 4. Personal Speech Habits & Directives from Writing Monitor
        if let habitsHint = UserGrammarProfile.shared.topDirectivesPromptHint(language: language) {
            components.append(habitsHint)
        }

        let learnedRareWords = UserGrammarProfile.shared.topIdiosyncraticWords(limit: 20)
        let effectiveVocab = activeEffectiveVocabulary(targetApp: targetApp, userVocabulary: customVocabulary, userLocation: userLocation)
        
        var combinedVocabItems = effectiveVocab.components(separatedBy: CharacterSet(charactersIn: ",\n;"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            
        let isEnglishTarget = language?.lowercased().starts(with: "en") == true
        var seenVocab = Set(combinedVocabItems.map { $0.lowercased() })
        for rw in learnedRareWords {
            if isEnglishTarget {
                let hasCyrillic = rw.unicodeScalars.contains { ($0.value >= 0x0400 && $0.value <= 0x04FF) || ($0.value >= 0x0500 && $0.value <= 0x052F) }
                if hasCyrillic { continue }
            }
            let norm = rw.normalizedPlainVocabularyWord()
            if seenVocab.insert(norm.lowercased()).inserted {
                combinedVocabItems.append(norm)
            }
        }
        
        let finalVocab = combinedVocabItems.joined(separator: ", ")
        if !finalVocab.isEmpty {
            components.append("Custom Terms: \(finalVocab).")
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

        // Active window & document keywords first: they are the most specific signal and must survive the cap below.
        let winContext = inspectActiveWindowContext(targetApp: targetApp)
        strings.append(contentsOf: winContext.keywords)

        // Add effective vocabulary (user + domain)
        let effectiveVocab = activeEffectiveVocabulary(targetApp: targetApp, userVocabulary: customVocabulary, userLocation: userLocation)
        let customWords = effectiveVocab
            .components(separatedBy: CharacterSet(charactersIn: ",\n;"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        strings.append(contentsOf: customWords)

        // Add learned rare words from Writing Monitor
        let learnedRare = UserGrammarProfile.shared.topIdiosyncraticWords(limit: 20)
        strings.append(contentsOf: learnedRare.map { $0.normalizedPlainVocabularyWord() })

        // Add user locations & street indicators
        if !userLocation.isEmpty {
            let locWords = userLocation
                .components(separatedBy: CharacterSet(charactersIn: ",\n;"))
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            strings.append(contentsOf: locWords)
            strings.append(contentsOf: [
                "остров", "island", "о.", "isl.", "Саадият", "Яс", "Рим", "Аль-Рим", "Аль-Марьях", "Джубайл", "Худайрият",
                "Нурай", "Корниш", "Шейх Заед", "Масдар", "Палм-Джумейра", "Дубай Марина", "Даунтаун",
                "ул.", "улица", "проспект", "бульвар", "набережная", "переулок", "шоссе", "дом", "корпус", "строение", "квартира", "метро",
                "Street", "Avenue", "Boulevard", "Road", "Way", "Drive", "Lane", "Square", "Corniche"
            ])
        }

        // Ordered, case-insensitive dedupe. Array(Set(...)) used to shuffle priorities and drop random user terms at the cap.
        var seen = Set<String>()
        var ordered: [String] = []
        ordered.reserveCapacity(min(strings.count, 120))
        for s in strings where ordered.count < 120 {
            if seen.insert(s.lowercased()).inserted {
                ordered.append(s)
            }
        }
        return ordered
    }
}

