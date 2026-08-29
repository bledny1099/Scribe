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
                return "Optimized for coding agents, IDEs, Git, terminals & tech stacks."
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

    // MARK: - App Domain Detection

    /// Determines the domain of the target or frontmost application
    public func detectActiveAppDomain(targetApp: NSRunningApplication? = nil) -> (name: String, domain: AppDomain, bundleId: String, icon: NSImage?) {
        let app = targetApp ?? NSWorkspace.shared.frontmostApplication
        let name = app?.localizedName ?? "General"
        let bundleId = (app?.bundleIdentifier ?? "").lowercased()
        let nameLower = name.lowercased()
        let icon: NSImage? = app?.icon ?? (app?.bundleURL != nil ? NSWorkspace.shared.icon(forFile: app!.bundleURL!.path) : nil)

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
            return (name, .ideAndCoding, bundleId, icon)
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
            return (name, .messengersAndChat, bundleId, icon)
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
            return (name, .notesAndWriting, bundleId, icon)
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
        case .medicalAndHealth:
            return [
                "МРТ", "КТ", "УЗИ", "ЭКГ", "ЭхоКГ", "Холтер", "ЭЭГ", "ФГДС", "Колоноскопия", "Биопсия", "Лапароскопия",
                "ОАК", "ОАМ", "Биохимия", "Коагулограмма", "Гликированный гемоглобин", "СОЭ", "С-реактивный белок",
                "Ферритин", "Д-димер", "Тропонин", "Креатинин", "АЛТ", "АСТ", "Билирубин", "ТТГ", "Т3", "Т4", "Кортизол",
                "Кардиология", "Неврология", "Эндокринология", "Гастроэнтерология", "Пульмонология", "Онкология", "Хирургия",
                "Аспирин", "Ибупрофен", "Парацетамол", "Амоксициллин", "Дексаметазон", "Омепразол", "Метформин", "Инсулин",
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
            return []
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

        case .browsersAndResearch, .designAndCreative, .cryptoAndTrading, .medicalAndHealth, .nutritionAndBiohacking, .citiesAndLocations, .general:
            return languageHallucinations
        }
    }

    // MARK: - Dynamic Effective Mergers

    /// Merges user custom vocabulary with target application domain vocabulary
    public func activeEffectiveVocabulary(targetApp: NSRunningApplication? = nil, userVocabulary: String, userLocation: String = "") -> String {
        let (_, domain, _, _) = detectActiveAppDomain(targetApp: targetApp)
        let domainWords = domainSpecificVocabulary(for: domain)
        
        var userWords = userVocabulary.components(separatedBy: CharacterSet(charactersIn: ",\n;"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if !userLocation.isEmpty {
            let locWords = userLocation.components(separatedBy: CharacterSet(charactersIn: ",\n;"))
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            userWords.append(contentsOf: locWords)
        }

        var combined = userWords
        for w in domainWords {
            if !combined.contains(where: { $0.caseInsensitiveCompare(w) == .orderedSame }) {
                combined.append(w)
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
                return "Используйте правильную пунктуацию, запятые и заглавные буквы."
            } else if isEnglishOnly {
                return "Use proper punctuation, capitalization, and formatting."
            } else {
                return "Multilingual Russian and English speech: правильная пунктуация, commas, capitalization, заглавные буквы."
            }
        }
    }

    // MARK: - Window & Active Document Accessibility Context

    public struct WindowContext: Sendable {
        public let windowTitle: String?
        public let documentFileName: String?
        public let fileExtension: String?
        public let keywords: [String]
    }

    /// Inspects the frontmost active window title and open document name via Accessibility API (100% locally, no network).
    public func inspectActiveWindowContext(targetApp: NSRunningApplication? = nil) -> WindowContext {
        guard AXIsProcessTrusted() else {
            return WindowContext(windowTitle: nil, documentFileName: nil, fileExtension: nil, keywords: [])
        }

        let app = targetApp ?? NSWorkspace.shared.frontmostApplication
        guard let pid = app?.processIdentifier else {
            return WindowContext(windowTitle: nil, documentFileName: nil, fileExtension: nil, keywords: [])
        }

        let appElement = AXUIElementCreateApplication(pid)
        var focusedWindowValue: AnyObject?
        let copyRes = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedWindowValue)

        var title: String?
        var documentURL: String?

        if copyRes == .success, let window = focusedWindowValue {
            // 1. Window Title
            var titleVal: AnyObject?
            if AXUIElementCopyAttributeValue(window as! AXUIElement, kAXTitleAttribute as CFString, &titleVal) == .success,
               let t = titleVal as? String, !t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                title = t.trimmingCharacters(in: .whitespacesAndNewlines)
            }

            // 2. Document URL / Path
            var docVal: AnyObject?
            if AXUIElementCopyAttributeValue(window as! AXUIElement, kAXDocumentAttribute as CFString, &docVal) == .success,
               let doc = docVal as? String, !doc.isEmpty {
                documentURL = doc
            }
        }

        var fileName: String?
        var fileExt: String?
        var extractedKeywords: [String] = []

        if let doc = documentURL {
            let url = URL(fileURLWithPath: doc)
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
        let domainHint = domainContextPrompt(for: domain, language: language)

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

        let effectiveVocab = activeEffectiveVocabulary(targetApp: targetApp, userVocabulary: customVocabulary, userLocation: userLocation)
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
        let effectiveVocab = activeEffectiveVocabulary(targetApp: targetApp, userVocabulary: customVocabulary, userLocation: userLocation)
        let customWords = effectiveVocab
            .components(separatedBy: CharacterSet(charactersIn: ",\n;"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        strings.append(contentsOf: customWords)

        // Add active window & document keywords
        let winContext = inspectActiveWindowContext(targetApp: targetApp)
        if !winContext.keywords.isEmpty {
            strings.append(contentsOf: winContext.keywords)
        }

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

        return Array(Set(strings)).prefix(120).map { $0 }
    }
}

