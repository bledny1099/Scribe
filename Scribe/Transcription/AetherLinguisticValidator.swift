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
        "заскрейпи": "заскрейпи",
        "от скорректируй": "откорректируй",
        "под корректируй": "подкорректируй",
        "со стилизуй": "стилизуй",
        "за имплементируй": "заимплементируй",
        "по тестируй": "потестируй",
        "от валидируй": "отвалидируй",
        "за дебажь": "задебажь",
        "по дебажь": "подебажь",
        "за оптимизируй": "заоптимизируй",
        "по ресерчи": "поресерчи",
        "по ресёрчи": "поресёрчи"
    ]

    /// Context-dependent photographic terms. If none of these keywords exist in text, words like "проявка" are acoustic mishearings of "проверка".
    private let photographyKeywords: [String] = [
        "пленк", "плёнк", "фото", "негатив", "реактив", "бачок", "эмульси", "кадр",
        "лаборатор", "закрепител", "проявител", "проявитель", "darkroom", "film", "35mm"
    ]

    /// Systematic grammatical agreement and declension corrections in Russian speech
    private let russianGrammarAgreementRules: [(pattern: String, replacement: String)] = [
        // Subject-verb agreement (1st person singular "я")
        ("(?i)\\bя\\s+говорит\\b", "я говорю"),
        ("(?i)\\bя\\s+делает\\b", "я делаю"),
        ("(?i)\\bя\\s+знает\\b", "я знаю"),
        ("(?i)\\bя\\s+думает\\b", "я думаю"),
        ("(?i)\\bя\\s+хочет\\b", "я хочу"),
        ("(?i)\\bя\\s+видит\\b", "я вижу"),
        ("(?i)\\bя\\s+слышит\\b", "я слышу"),
        ("(?i)\\bя\\s+понимает\\b", "я понимаю"),
        ("(?i)\\bя\\s+смотрит\\b", "я смотрю"),
        ("(?i)\\bя\\s+пишет\\b", "я пишу"),

        // Subject-verb agreement (2nd person singular "ты")
        ("(?i)\\bты\\s+говорит\\b", "ты говоришь"),
        ("(?i)\\bты\\s+делает\\b", "ты делаешь"),
        ("(?i)\\bты\\s+знает\\b", "ты знаешь"),
        ("(?i)\\bты\\s+думает\\b", "ты думаешь"),
        ("(?i)\\bты\\s+хочет\\b", "ты хочешь"),

        // Subject-verb agreement (1st person plural "мы")
        ("(?i)\\bмы\\s+говорит\\b", "мы говорим"),
        ("(?i)\\bмы\\s+делает\\b", "мы делаем"),
        ("(?i)\\bмы\\s+знает\\b", "мы знаем"),
        ("(?i)\\bмы\\s+думает\\b", "мы думаем"),
        ("(?i)\\bмы\\s+сказал\\b", "мы сказали"),
        ("(?i)\\bмы\\s+сделал\\b", "мы сделали"),

        // Preposition and case agreement
        ("(?i)\\bк\\s+одной\\s+и\\s+том\\s+же\\b", "к одной и той же"),
        ("(?i)\\bк\\s+одной\\s+и\\s+тоже\\b", "к одному и тому же"),
        ("(?i)\\bк\\s+одном\\s+и\\s+том\\s+же\\b", "к одному и тому же"),
        ("(?i)\\bв\\s+одной\\s+и\\s+том\\s+же\\b", "в одном и том же"),
        ("(?i)\\bв\\s+одном\\s+и\\s+той\\s+же\\b", "в одном и том же"),
        ("(?i)\\bна\\s+одной\\s+и\\s+том\\s+же\\b", "на одной и той же"),
        ("(?i)\\bс\\s+одной\\s+и\\s+том\\s+же\\b", "с одной и той же"),

        // Common speech acoustic / case mishearings
        ("(?i)\\bво\\s+время\\s+транскребаци[ейяию]\\b", "во время транскрибации"),
        ("(?i)\\bперед\\s+транскребаци[ейяию]\\b", "перед транскрибацией"),
        ("(?i)\\bтранскребаци[яеию]\\b", "транскрибация"),
        ("(?i)\\bтранскребацией\\b", "транскрибацией"),
        ("(?i)\\bраспозна[её]т\\s+подержи\\b", "распознаёт падежи"),
        ("(?i)\\bраспознает\\s+подержи\\b", "распознаёт падежи"),
        ("(?i)\\bне\\s+очень\\s+распозна[её]т\\s+подерж[ейи]\\b", "не очень распознаёт падежи"),
        ("(?i)\\bготов[ыеых]+\\s+репозитори[яеи]\\b", "готовые репозитории")
    ]

    /// Systematic Russian command verb mappings: 3rd person singular present tense -> 2nd person imperative mood.
    /// When users dictate commands to AI assistants or developer tools, Whisper frequently misrecognizes
    /// imperative verb endings (-й, -и, -ь) as 3rd person (-ет, -ит): e.g. "Создает для сервера" -> "Создай для сервера".
    private let russianCommandVerbMap: [String: String] = [
        "создает": "создай",
        "создаёт": "создай",
        "делает": "сделай",
        "пишет": "напиши",
        "добавляет": "добавь",
        "удаляет": "удали",
        "настраивает": "настрой",
        "исправляет": "исправь",
        "проверяет": "проверь",
        "запускает": "запусти",
        "перезапускает": "перезапусти",
        "обновляет": "обнови",
        "показывает": "покажи",
        "открывает": "открой",
        "закрывает": "закрой",
        "меняет": "поменяй",
        "поменяет": "поменяй",
        "подключает": "подключи",
        "выносит": "вынеси",
        "переносит": "перенеси",
        "переименовывает": "переименуй",
        "генерирует": "сгенерируй",
        "импортирует": "импортируй",
        "экспортирует": "экспортируй",
        "коммитит": "закоммить",
        "закоммитит": "закоммить",
        "пушит": "запушь",
        "запушит": "запушь",
        "деплоит": "задеплой",
        "задеплоит": "задеплой"
    ]

    /// Systematic AI and developer tooling brand name normalizations (e.g. "чат гпт" -> "ChatGPT", "chat gpt" -> "ChatGPT", "чатгпт" -> "ChatGPT", "гпт 4" -> "GPT-4")
    private let brandNormalizationRules: [(pattern: String, replacement: String)] = [
        // ChatGPT model variants (e.g. ChatGPT-4o, ChatGPT 4, ChatGPT 5, chat gpt 4)
        ("(?i)\\b(?:чат[\\s-]*гпт|чат[\\s-]*gpt|chat[\\s-]*gpt|chatgpt|чат[\\s-]*джи[\\s-]*пи[\\s-]*ти|чат[\\s-]*джипити|чатджипити)\\s*([0-9]+(?:\\.[0-9]+)?(?:[a-z]|o|mini|pro|turbo)?)\\b", "ChatGPT $1"),
        // ChatGPT standalone
        ("(?i)\\b(?:чат[\\s-]*гпт|чат[\\s-]*gpt|chat[\\s-]*gpt|chatgpt|чат[\\s-]*джи[\\s-]*пи[\\s-]*ти|чат[\\s-]*джипити|чатджипити)\\b", "ChatGPT"),
        // GPT standalone and versions
        ("(?i)\\b(?:гпт|джи[\\s-]*пи[\\s-]*ти|джипити)\\s*([0-9]+(?:\\.[0-9]+)?(?:[a-z]|o|mini|pro|turbo)?)\\b", "GPT-$1"),
        ("(?i)\\b(?:гпт|джи[\\s-]*пи[\\s-]*ти|джипити)\\b", "GPT"),
        // OpenAI
        ("(?i)\\b(?:опен[\\s-]*а[ий]|опен[\\s-]*эй|open[\\s-]*ai)\\b", "OpenAI"),
        // Claude / Claude Code
        ("(?i)\\b(?:клод[\\s-]*код|клауд[\\s-]*код|claude[\\s-]*code)\\b", "Claude Code"),
        // Gemini / Perplexity / Midjourney / DeepSeek
        ("(?i)\\b(?:джеминай|гемнай|джемини)\\b", "Gemini"),
        ("(?i)\\b(?:перплексити[\\s-]*а[ий]|perplexity[\\s-]*ai)\\b", "Perplexity AI"),
        ("(?i)\\b(?:перплексити)\\b", "Perplexity"),
        ("(?i)\\b(?:миджорни|мидджорни|mid[\\s-]*journey)\\b", "Midjourney"),
        ("(?i)\\b(?:дип[\\s-]*сик|deep[\\s-]*seek)\\b", "DeepSeek"),
        // Frameworks & Dev tools
        ("(?i)\\b(?:пай[\\s-]*торч|пи[\\s-]*торч|py[\\s-]*torch)\\b", "PyTorch"),
        ("(?i)\\b(?:тензор[\\s-]*флоу|тензор[\\s-]*фло|tensor[\\s-]*flow)\\b", "TensorFlow"),
        ("(?i)\\b(?:супа[\\s-]*бейс|супа[\\s-]*бейз|supa[\\s-]*base)\\b", "Supabase"),
        ("(?i)\\b(?:кубер[\\s-]*нетес|кубер)\\b", "Kubernetes"),
        ("(?i)\\b(?:пост[\\s-]*грес[\\s-]*кью[\\s-]*эль|пост[\\s-]*грес|пост[\\s-]*гре)\\b", "PostgreSQL"),
        ("(?i)\\b(?:тайл[\\s-]*винд|тейл[\\s-]*винд|tailwind[\\s-]*css)\\b", "TailwindCSS"),
        ("(?i)\\b(?:некст[\\s-]*дж[\\s-]*эс|next[\\s-]*js)\\b", "Next.js"),
        ("(?i)\\b(?:вер[\\s-]*сель|вер[\\s-]*сел)\\b", "Vercel"),
        ("(?i)\\b(?:хаггинг[\\s-]*фейс|hugging[\\s-]*face)\\b", "HuggingFace"),
        ("(?i)\\b(?:анти[\\s-]*гравити)\\b", "Antigravity")
    ]

    /// Systematic mappings for "проявка" forms -> "проверка" forms outside photography context.
    private let nonPhotoAcousticMap: [String: String] = [
        "проявка": "проверка",
        "проявки": "проверки",
        "проявку": "проверку",
        "проявке": "проверке",
        "проявкой": "проверкой",
        "проявкою": "проверкою",
        "проявкам": "проверкам",
        "проявками": "проверками",
        "проявках": "проверках",
        "прояви": "проверь",
        "проявил": "проверил",
        "проявили": "проверили",
        "проявим": "проверим",
        "проявляем": "проверяем",
        "проявлять": "проверять",
        "проявлен": "проверен",
        "проявлено": "проверено",
        "проявлена": "проверена",
        "проявлены": "проверены"
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
        let lowerOriginal = text.lowercased()

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

        // 1b. AI & Tech Brand name normalizations (e.g. "чат гпт" -> "ChatGPT", "chat gpt" -> "ChatGPT")
        for rule in brandNormalizationRules {
            if let regex = try? NSRegularExpression(pattern: rule.pattern) {
                let range = NSRange(result.startIndex..<result.endIndex, in: result)
                result = regex.stringByReplacingMatches(
                    in: result,
                    options: [],
                    range: range,
                    withTemplate: rule.replacement
                )
            }
        }

        // 2. Context-aware Russian phrase corrections (e.g. testing / mic checks / non-photography speech)
        let hasPhotoContext = photographyKeywords.contains { lowerOriginal.contains($0) }
        if !hasPhotoContext {
            // "раз, два, три, проявка" -> "Раз, два, три, проверка."
            let micCheckPattern = "(?i)\\bраз[\\s,]+два[\\s,]+(?:три[\\s,]+)?проявк([а-яё]*)"
            if let regex = try? NSRegularExpression(pattern: micCheckPattern) {
                let range = NSRange(result.startIndex..<result.endIndex, in: result)
                result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "Раз, два, три, проверк$1")
            }

            // "тест / проверка связи / микрофона"
            let micContextPattern = "(?i)\\bпроявк([а-яё]*)\\s+(микрофон|связ|звук|работ|код|гипотез|систем|слух|качеств|данны|файло|тест)"
            if let regex = try? NSRegularExpression(pattern: micContextPattern) {
                let range = NSRange(result.startIndex..<result.endIndex, in: result)
                result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "проверк$1 $2")
            }

            // General "проявка" -> "проверка" inflection map outside photography context
            for (incorrect, correct) in nonPhotoAcousticMap {
                let pattern = "(?i)\\b" + NSRegularExpression.escapedPattern(for: incorrect) + "\\b"
                if let regex = try? NSRegularExpression(pattern: pattern) {
                    let matches = regex.matches(in: result, options: [], range: NSRange(location: 0, length: (result as NSString).length))
                    for match in matches.reversed() {
                        if let range = Range(match.range, in: result) {
                            let originalWord = String(result[range])
                            let matchedCase = matchCapitalization(original: originalWord, target: correct)
                            result.replaceSubrange(range, with: matchedCase)
                        }
                    }
                }
            }
        }

        // 3. Token-level dictionary validation via Top 100 User Vocabulary & NSSpellChecker
        let langCode = resolveSpellCheckerLanguage(language: language, text: text)
        let isRussian = langCode.hasPrefix("ru")

        // 3a. Sanitize any rogue Ukrainian characters or particles when transcribing in Russian
        if isRussian {
            let ukrainianWordMap: [(pattern: String, replacement: String)] = [
                ("(?i)\\bщо\\b", "что"),
                ("(?i)\\bце\\b", "это"),
                ("(?i)\\bбуло\\b", "было"),
                ("(?i)\\bбув\\b", "был"),
                ("(?i)\\bбули\\b", "были"),
                ("(?i)\\bвже\\b", "уже"),
                ("(?i)\\bякщо\\b", "если"),
                ("(?i)\\bтакож\\b", "также"),
                ("(?i)\\bале\\b", "но"),
                ("(?i)\\bдуже\\b", "очень"),
                ("(?i)\\bдякую\\b", "спасибо"),
                ("(?i)\\bсьогодні\\b", "сегодня"),
                ("(?i)\\bчому\\b", "почему"),
                ("(?i)\\bтому що\\b", "потому что"),
                ("(?i)\\bзараз\\b", "сейчас")
            ]
            for (pat, rep) in ukrainianWordMap {
                if let regex = try? NSRegularExpression(pattern: pat) {
                    let range = NSRange(result.startIndex..<result.endIndex, in: result)
                    result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: rep)
                }
            }

            // Replace single Ukrainian glyphs with Russian equivalents
            let glyphMap: [(String, String)] = [
                ("і", "и"), ("І", "И"),
                ("ї", "и"), ("Ї", "И"),
                ("є", "е"), ("Є", "Е"),
                ("ґ", "г"), ("Ґ", "Г")
            ]
            for (ukr, rus) in glyphMap {
                if result.contains(ukr) {
                    result = result.replacingOccurrences(of: ukr, with: rus)
                }
            }

            // 3b. Grammatical agreement & case declension repairs
            for (pat, rep) in russianGrammarAgreementRules {
                if let regex = try? NSRegularExpression(pattern: pat) {
                    let range = NSRange(result.startIndex..<result.endIndex, in: result)
                    result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: rep)
                }
            }

            // 3c. Command and imperative mood repairs for AI & developer directives
            result = applyRussianCommandImperativeRules(result)
        }

        let customSet = Set(customVocabulary.map { $0.lowercased() })
        let userFreqDict = UserFrequencyDictionary.shared
        let userTop100Set = userFreqDict.topWordsSet(limit: 100)

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

            // If already in user's top words or community dictionary, it's definitively valid
            if userTop100Set.contains(lowerWord) || CommunityVocabularyService.shared.getCachedTermsSetLower().contains(lowerWord) {
                continue
            }

            // Check if there is a strong User Top 100 match (fuzzy candidate)
            if let userCandidate = userFreqDict.findBestFuzzyCandidate(for: word, maxDistance: 2, limit: 100) {
                let userWordFreq = userCandidate.count
                let currentWordFreq = userFreqDict.frequency(of: lowerWord)

                // If current word is non-existent in user history, but close to a frequent user top word
                if userCandidate.distance == 1 && userWordFreq >= 2 && currentWordFreq == 0 {
                    let matchedCase = matchCapitalization(original: word, target: userCandidate.word)
                    replacements.append((range: wordRange, replacement: matchedCase))
                    continue
                }
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

                // Check Top 100 User Words first before generic spellchecker
                if let userMatch = userFreqDict.findBestFuzzyCandidate(for: word, maxDistance: 2, limit: 100) {
                    let matchedCase = matchCapitalization(original: word, target: userMatch.word)
                    replacements.append((range: wordRange, replacement: matchedCase))
                    continue
                }

                // In Russian, do NOT let spell checker overwrite valid case endings (e.g. -ом, -ам, -ях, -е)
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

                if !guesses.isEmpty {
                    // Re-rank guesses by User Top 100 frequency + Community dictionary + phonetic closeness
                    let sortedGuesses = guesses.sorted { g1, g2 in
                        let score1 = scoreGuess(g1, original: lowerWord, userFreqDict: userFreqDict)
                        let score2 = scoreGuess(g2, original: lowerWord, userFreqDict: userFreqDict)
                        return score1 > score2
                    }

                    if let bestGuess = sortedGuesses.first, !bestGuess.isEmpty {
                        if abs(bestGuess.count - word.count) <= 1 && isAcousticallySimilar(word, bestGuess) {
                            let matchedCase = matchCapitalization(original: word, target: bestGuess)
                            replacements.append((range: wordRange, replacement: matchedCase))
                        }
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

    /// Systematic command directive repair for Russian speech:
    /// Converts 3rd person singular present tense verbs to 2nd person imperative mood
    /// when used as direct commands to AI agents, IDEs, or in instructional speech (without a 3rd person subject noun/pronoun).
    private func applyRussianCommandImperativeRules(_ text: String) -> String {
        var result = text
        let verbKeys = russianCommandVerbMap.keys.sorted { $0.count > $1.count }.joined(separator: "|")

        // 1. Initial / transitional commands: "создает...", "и создает...", "потом делает...", "ну создает..."
        let transitionPattern = "(?i)(?:^|(?<=[.!?;\n])|\\b(?:и|а|потом|затем|теперь|дальше|ещ[её]|также|давай|просто|пожалуйста)\\s+)(" + verbKeys + ")\\b"
        if let regex = try? NSRegularExpression(pattern: transitionPattern) {
            let nsString = result as NSString
            let matches = regex.matches(in: result, options: [], range: NSRange(location: 0, length: nsString.length))
            for match in matches.reversed() {
                let verbRange = match.range(at: 1)
                let verbWord = nsString.substring(with: verbRange)
                let lowerVerb = verbWord.lowercased()

                if let imperative = russianCommandVerbMap[lowerVerb] {
                    let matchedCase = matchCapitalization(original: verbWord, target: imperative)
                    if let strRange = Range(verbRange, in: result) {
                        result.replaceSubrange(strRange, with: matchedCase)
                    }
                }
            }
        }

        // 2. Direct object / preposition directive context without explicit subject
        let subjectExclusion = "(?:он|она|оно|сервер|скрипт|система|приложение|процесс|сервис|код|бот|воркер|пользователь|юзер|клиент|фреймворк)"
        let directiveContextPattern = "(?i)(?:^|(?<!\\b" + subjectExclusion + "\\s))\\b(" + verbKeys + ")\\s+(для\\b|в\\b|на\\b|из\\b|под\\b|отдельн|нов|файл|папк|сервер|компонент|скрипт|функци|класс|модул|роут|проект|таблиц|баз|конфиг|ветк|пул|код|тест|кнопк|баг|ошибк|запрос|ответ)"
        if let regex = try? NSRegularExpression(pattern: directiveContextPattern) {
            let nsString = result as NSString
            let matches = regex.matches(in: result, options: [], range: NSRange(location: 0, length: nsString.length))
            for match in matches.reversed() {
                let verbRange = match.range(at: 1)
                let verbWord = nsString.substring(with: verbRange)
                let lowerVerb = verbWord.lowercased()

                if let imperative = russianCommandVerbMap[lowerVerb] {
                    let matchedCase = matchCapitalization(original: verbWord, target: imperative)
                    if let strRange = Range(verbRange, in: result) {
                        result.replaceSubrange(strRange, with: matchedCase)
                    }
                }
            }
        }

        return result
    }

    /// Scores a candidate guess based on user top vocabulary, community dictionary, and distance
    private func scoreGuess(_ guess: String, original: String, userFreqDict: UserFrequencyDictionary) -> Int {
        let lower = guess.lowercased()
        var score = 0
        let userFreq = userFreqDict.frequency(of: lower)
        score += min(userFreq * 25, 200)

        if CommunityVocabularyService.shared.getCachedTermsSetLower().contains(lower) {
            score += 80
        }

        let dist = levenshtein(original, lower)
        score -= dist * 20

        return score
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
