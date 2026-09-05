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
        "по ресёрчи": "поресёрчи",
        "ситаешь": "считаешь",
        "ситаю": "считаю",
        "ситает": "считает",
        "ситаем": "считаем"
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
        ("(?i)\\b(я\\s+)?(искал|ищу|нашел|нашёл|вижу|знаю|поставил)\\s+твой\\s+цеп\\b", "$1$2 твою цель"),
        ("(?i)\\bтвой\\s+цеп\\s+среди\\b", "твою цель среди"),
        ("(?i)\\bтвой\\s+цеп\\b", "твою цель"),
        ("(?i)\\bсвой\\s+цеп\\b", "свою цель"),
        ("(?i)\\bнаш\\s+цеп\\b", "нашу цель"),
        // Modal verb / predicate agreement with infinitive (Russian modal agreement: должен/нужно/надо + инфинитив)
        ("(?i)\\b(долж(?:ен|на|но|ны)|нужно|надо|следует|стоит|мож(?:ет|но|ем|ете|ут))\\s+работает\\b", "$1 работать"),
        ("(?i)\\b(долж(?:ен|на|но|ны)|нужно|надо|следует|стоит|мож(?:ет|но|ем|ете|ут))\\s+(вс[её]|всегда|тоже|также|уже|ещ[её]|вроде|сейчас)\\s+работает\\b", "$1 $2 работать"),
        ("(?i)\\b(долж(?:ен|на|но|ны)|нужно|надо|следует|стоит|мож(?:ет|но|ем|ете|ут))\\s+(нормально|хорошо|качественно|правильно|корректно|быстро|стабильно|ч[её]тко)\\s+работает\\b", "$1 $2 работать"),
        ("(?i)\\b(долж(?:ен|на|но|ны)|нужно|надо|следует|стоит|мож(?:ет|но|ем|ете|ут))\\s+(вс[её]|всегда|тоже|также|уже|ещ[её]|вроде|сейчас)\\s+(нормально|хорошо|качественно|правильно|корректно|быстро|стабильно|ч[её]тко)\\s+работает\\b", "$1 $2 $3 работать"),
        ("(?i)\\b(долж(?:ен|на|но|ны)|нужно|надо|следует|стоит|мож(?:ет|но|ем|ете|ут))\\s+делает\\b", "$1 делать"),
        ("(?i)\\b(долж(?:ен|на|но|ны)|нужно|надо|следует|стоит|мож(?:ет|но|ем|ете|ут))\\s+(вс[её]|всегда|тоже|также|уже|ещ[её]|вроде|сейчас)\\s+делает\\b", "$1 $2 делать"),
        ("(?i)\\b(долж(?:ен|на|но|ны)|нужно|надо|следует|стоит|мож(?:ет|но|ем|ете|ут))\\s+(нормально|хорошо|качественно|правильно|корректно|быстро|стабильно|ч[её]тко)\\s+делает\\b", "$1 $2 делать"),
        ("(?i)\\b(долж(?:ен|на|но|ны)|нужно|надо|следует|стоит|мож(?:ет|но|ем|ете|ут))\\s+(вс[её]|всегда|тоже|также|уже|ещ[её]|вроде|сейчас)\\s+(нормально|хорошо|качественно|правильно|корректно|быстро|стабильно|ч[её]тко)\\s+делает\\b", "$1 $2 $3 делать"),
        ("(?i)\\b(долж(?:ен|на|но|ны)|нужно|надо|следует|стоит|мож(?:ет|но|ем|ете|ут))\\s+(?:(вс[её]|всегда|тоже|также|уже|ещ[её]|вроде|сейчас)\\s+)?(?:(нормально|хорошо|качественно|правильно|корректно|быстро|стабильно|ч[её]тко)\\s+)?открывает\\b", "$1 $2 $3 открывать"),
        ("(?i)\\b(долж(?:ен|на|но|ны)|нужно|надо|следует|стоит|мож(?:ет|но|ем|ете|ут))\\s+(?:(вс[её]|всегда|тоже|также|уже|ещ[её]|вроде|сейчас)\\s+)?(?:(нормально|хорошо|качественно|правильно|корректно|быстро|стабильно|ч[её]тко)\\s+)?закрывает\\b", "$1 $2 $3 закрывать"),
        ("(?i)\\b(долж(?:ен|на|но|ны)|нужно|надо|следует|стоит|мож(?:ет|но|ем|ете|ут))\\s+(?:(вс[её]|всегда|тоже|также|уже|ещ[её]|вроде|сейчас)\\s+)?(?:(нормально|хорошо|качественно|правильно|корректно|быстро|стабильно|ч[её]тко)\\s+)?сохраняет\\b", "$1 $2 $3 сохранять"),
        ("(?i)\\b(долж(?:ен|на|но|ны)|нужно|надо|следует|стоит|мож(?:ет|но|ем|ете|ут))\\s+(?:(вс[её]|всегда|тоже|также|уже|ещ[её]|вроде|сейчас)\\s+)?(?:(нормально|хорошо|качественно|правильно|корректно|быстро|стабильно|ч[её]тко)\\s+)?отображается\\b", "$1 $2 $3 отображаться"),
        ("(?i)\\b(долж(?:ен|на|но|ны)|нужно|надо|следует|стоит|мож(?:ет|но|ем|ете|ут))\\s+(?:(вс[её]|всегда|тоже|также|уже|ещ[её]|вроде|сейчас)\\s+)?(?:(нормально|хорошо|качественно|правильно|корректно|быстро|стабильно|ч[её]тко)\\s+)?появляется\\b", "$1 $2 $3 появляться"),
        ("(?i)\\b(долж(?:ен|на|но|ны)|нужно|надо|следует|стоит|мож(?:ет|но|ем|ете|ут))\\s+(?:(вс[её]|всегда|тоже|также|уже|ещ[её]|вроде|сейчас)\\s+)?(?:(нормально|хорошо|качественно|правильно|корректно|быстро|стабильно|ч[её]тко)\\s+)?запускается\\b", "$1 $2 $3 запускаться"),
        ("(?i)\\b(долж(?:ен|на|но|ны)|нужно|надо|следует|стоит|мож(?:ет|но|ем|ете|ут))\\s+(?:(вс[её]|всегда|тоже|также|уже|ещ[её]|вроде|сейчас)\\s+)?(?:(нормально|хорошо|качественно|правильно|корректно|быстро|стабильно|ч[её]тко)\\s+)?обновляется\\b", "$1 $2 $3 обновляться"),
        ("(?i)\\b(долж(?:ен|на|но|ны)|нужно|надо|следует|стоит|мож(?:ет|но|ем|ете|ут))\\s+(?:(вс[её]|всегда|тоже|также|уже|ещ[её]|вроде|сейчас)\\s+)?(?:(нормально|хорошо|качественно|правильно|корректно|быстро|стабильно|ч[её]тко)\\s+)?функционирует\\b", "$1 $2 $3 функционировать"),

        // Common adverb agreement & acoustic mishearings
        ("(?i)\\bбыстренькое\\b", "быстренько"),
        ("(?i)\\bбыстренький\\b(?=\\s+(?:сдела|поправ|постав|напиш|провер|запуст))", "быстренько"),
        ("(?i)\\bя\\s+часто\\s+справился\\b", "я сейчас справлюсь"),
        ("(?i)\\bя\\s+щас\\s+справился\\b", "я щас справлюсь"),
        ("(?i)\\bя\\s+часто\\s+справлюсь\\b", "я сейчас справлюсь"),

        ("(?i)\\bглавный\\s+цеп\\b", "главная цель"),
        ("(?i)\\bво\\s+время\\s+транскребаци[ейяию]\\b", "во время транскрибации"),
        ("(?i)\\bперед\\s+транскребаци[ейяию]\\b", "перед транскрибацией"),
        ("(?i)\\bтранскребаци[яеию]\\b", "транскрибация"),
        ("(?i)\\bтранскребацией\\b", "транскрибацией"),
        ("(?i)\\bраспозна[её]т\\s+подержи\\b", "распознаёт падежи"),
        ("(?i)\\bраспознает\\s+подержи\\b", "распознаёт падежи"),
        ("(?i)\\bне\\s+очень\\s+распозна[её]т\\s+подерж[ейи]\\b", "не очень распознаёт падежи"),
        ("(?i)\\bготов[ыеых]+\\s+репозитори[яеи]\\b", "готовые репозитории"),
        ("(?i)\\bбуфер(а|е|ом)?\\s+отмен[аыеу]?\\b", "буфер$1 обмена"),
        ("(?i)\\bпотом\\s+что\\b", "потому что"),
        ("(?i)\\bпотому\\s+не\\s+вставлял[аосьия]+\\b", "потом не вставлялась"),
        ("(?i)\\bситаешь\\b", "считаешь"),
        ("(?i)\\bситаю\\b", "считаю"),
        ("(?i)\\bситаем\\b", "считаем"),
        ("(?i)\\bсам\\s+ситаешь\\b", "сам считаешь"),
        ("(?i)\\bкак\\s+ситаешь\\b", "как считаешь"),
        ("(?i)\\bкак\\s+сам\\s+ситаешь\\b", "как сам считаешь"),
        ("(?i)\\bа\\.\\s*семки\\s*а\\.\\s*егорова\\b", "")
    ]

    /// Systematic Russian command verb mappings: 3rd person singular present tense -> 2nd person imperative mood.
    private let russianCommandVerbMap: [String: String] = [
        "создает": "создай",
        "создаёт": "создай",
        "делает": "сделай",
        "сделает": "сделай",
        "сделаю": "сделай",
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

    /// Systematic AI and developer tooling brand name normalizations
    private let brandNormalizationRules: [(pattern: String, replacement: String)] = [
        ("(?i)\\b(?:чат[\\s-]*гпт|чат[\\s-]*gpt|chat[\\s-]*gpt|chatgpt|чат[\\s-]*джи[\\s-]*пи[\\s-]*ти|чат[\\s-]*джипити|чатджипити)\\s*([0-9]+(?:\\.[0-9]+)?(?:[a-z]|o|mini|pro|turbo)?)\\b", "ChatGPT $1"),
        ("(?i)\\b(?:чат[\\s-]*гпт|чат[\\s-]*gpt|chat[\\s-]*gpt|chatgpt|чат[\\s-]*джи[\\s-]*пи[\\s-]*ти|чат[\\s-]*джипити|чатджипити)\\b", "ChatGPT"),
        ("(?i)\\b(?:гпт|джи[\\s-]*пи[\\s-]*ти|джипити)\\s*([0-9]+(?:\\.[0-9]+)?(?:[a-z]|o|mini|pro|turbo)?)\\b", "GPT-$1"),
        ("(?i)\\b(?:гпт|джи[\\s-]*пи[\\s-]*ти|джипити)\\b", "GPT"),
        ("(?i)\\b(?:опен[\\s-]*а[ий]|опен[\\s-]*эй|open[\\s-]*ai)\\b", "OpenAI"),
        ("(?i)\\b(?:клод[\\s-]*код|клауд[\\s-]*код|claude[\\s-]*code)\\b", "Claude Code"),
        ("(?i)\\b(?:джеминай|гемнай|джемини)\\b", "Gemini"),
        ("(?i)\\b(?:перплексити[\\s-]*а[ий]|perplexity[\\s-]*ai)\\b", "Perplexity AI"),
        ("(?i)\\b(?:перплексити)\\b", "Perplexity"),
        ("(?i)\\b(?:миджорни|мидджорни|mid[\\s-]*journey)\\b", "Midjourney"),
        ("(?i)\\b(?:дип[\\s-]*сик|deep[\\s-]*seek)\\b", "DeepSeek"),
        ("(?i)\\b(?:пай[\\s-]*торч|пи[\\s-]*торч|py[\\s-]*torch)\\b", "PyTorch"),
        ("(?i)\\b(?:тензор[\\s-]*флоу|тензор[\\s-]*фло|tensor[\\s-]*flow)\\b", "TensorFlow"),
        ("(?i)\\b(?:супа[\\s-]*бейс|супа[\\s-]*бейз|supa[\\s-]*base)\\b", "Supabase"),
        ("(?i)\\b(?:кубер[\\s-]*нетес|кубер)\\b", "Kubernetes"),
        ("(?i)\\b(?:пост[\\s-]*грес[\\s-]*кью[\\s-]*эль|пост[\\s-]*грес|пост[\\s-]*гре)\\b", "PostgreSQL"),
        ("(?i)\\b(?:тайл[\\s-]*винд|тейл[\\s-]*винд|tailwind[\\s-]*css)\\b", "TailwindCSS"),
        ("(?i)\\b(?:некст[\\s-]*дж[\\s-]*эс|next[\\s-]*js)\\b", "Next.js"),
        ("(?i)\\b(?:вер[\\s-]*сель|вер[\\s-]*сел)\\b", "Vercel"),
        ("(?i)\\b(?:хаггинг[\\s-]*фейс|hugging[\\s-]*face)\\b", "HuggingFace"),
        ("(?i)\\b(?:анти[\\s-]*гравити)\\b", "Antigravity"),
        ("(?i)\\b(?:пулл[\\s-]*реквест|пул[\\s-]*реквест|пуллреквест|пулреквест)\\b", "pull request"),
        ("(?i)\\b(?:код[\\s-]*ревью|кодревью)\\b", "code review"),
        ("(?i)\\b(?:гит[\\s-]*хаб|гитхаб)\\b", "GitHub"),
        ("(?i)\\b(?:гит[\\s-]*лаб|гитлаб)\\b", "GitLab"),
        ("(?i)\\b(?:хкод|икскод)\\b", "Xcode"),
        ("(?i)\\b(?:свифт[\\s-]*юай|свифтюай)\\b", "SwiftUI"),
        ("(?i)\\b(?:свифт[\\s-]*дата|свифтдата)\\b", "SwiftData"),
        ("(?i)\\b(?:виспер[\\s-]*кит|виспур[\\s-]*кит)\\b", "WhisperKit"),
        ("(?i)\\b(?:тайп[\\s-]*скрипт|тайпскрипт)\\b", "TypeScript"),
        ("(?i)\\b(?:пайтон|питон)\\b", "Python")
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

    // MARK: - Russian Subject-Verb Past Tense Gender & Number Agreement

    private struct VerbGenderForms {
        let m: String   // мужской род
        let f: String   // женский род
        let n: String   // средний род
        let pl: String  // множественное число
    }

    private static let russianVerbFormsList: [VerbGenderForms] = [
        // Competition & Sports
        VerbGenderForms(m: "обыграл", f: "обыграла", n: "обыграло", pl: "обыграли"),
        VerbGenderForms(m: "победил", f: "победила", n: "победило", pl: "победили"),
        VerbGenderForms(m: "выиграл", f: "выиграла", n: "выиграло", pl: "выиграли"),
        VerbGenderForms(m: "проиграл", f: "проиграла", n: "проиграло", pl: "проиграли"),
        VerbGenderForms(m: "уступил", f: "уступила", n: "уступило", pl: "уступили"),
        VerbGenderForms(m: "забил", f: "забила", n: "забило", pl: "забили"),
        VerbGenderForms(m: "сыграл", f: "сыграла", n: "сыграло", pl: "сыграли"),
        VerbGenderForms(m: "разгромил", f: "разгромила", n: "разгромило", pl: "разгромили"),
        VerbGenderForms(m: "опередил", f: "опередила", n: "опередило", pl: "опередили"),
        // Tech & System & General actions
        VerbGenderForms(m: "сработал", f: "сработала", n: "сработало", pl: "сработали"),
        VerbGenderForms(m: "запустился", f: "запустилась", n: "запустилось", pl: "запустились"),
        VerbGenderForms(m: "запустил", f: "запустила", n: "запустило", pl: "запустили"),
        VerbGenderForms(m: "упал", f: "упала", n: "упало", pl: "упали"),
        VerbGenderForms(m: "ответил", f: "ответила", n: "ответило", pl: "ответили"),
        VerbGenderForms(m: "выдал", f: "выдала", n: "выдало", pl: "выдали"),
        VerbGenderForms(m: "создал", f: "создала", n: "создало", pl: "создали"),
        VerbGenderForms(m: "сделал", f: "сделала", n: "сделало", pl: "сделали"),
        VerbGenderForms(m: "написал", f: "написала", n: "написало", pl: "написали"),
        VerbGenderForms(m: "показал", f: "показала", n: "показало", pl: "показали"),
        VerbGenderForms(m: "открыл", f: "открыла", n: "открыло", pl: "открыли"),
        VerbGenderForms(m: "закрыл", f: "закрыла", n: "закрыло", pl: "закрыли"),
        VerbGenderForms(m: "сломался", f: "сломалась", n: "сломалось", pl: "сломались"),
        VerbGenderForms(m: "завершился", f: "завершилась", n: "завершилось", pl: "завершились"),
        VerbGenderForms(m: "отправил", f: "отправила", n: "отправило", pl: "отправили"),
        VerbGenderForms(m: "вернул", f: "вернула", n: "вернуло", pl: "вернули"),
        VerbGenderForms(m: "начался", f: "началась", n: "началось", pl: "начались"),
        VerbGenderForms(m: "произошел", f: "произошла", n: "произошло", pl: "произошли"),
        VerbGenderForms(m: "произошёл", f: "произошла", n: "произошло", pl: "произошли"),
        VerbGenderForms(m: "решил", f: "решила", n: "решило", pl: "решили"),
        VerbGenderForms(m: "передал", f: "передала", n: "передало", pl: "передали"),
        VerbGenderForms(m: "набрал", f: "набрала", n: "набрало", pl: "набрали")
    ]

    private let russianVerbLookup: [String: VerbGenderForms]

    // Precompiled regex caches for ultra-fast linguistic validation
    private let compiledAcousticCorrections: [(regex: NSRegularExpression, replacement: String)]
    private let compiledBrandRules: [(regex: NSRegularExpression, replacement: String)]
    private let compiledRussianGrammarRules: [(regex: NSRegularExpression, replacement: String)]
    private let compiledUkrainianWordMap: [(regex: NSRegularExpression, replacement: String)]
    private let compiledNonPhotoRules: [(regex: NSRegularExpression, replacement: String)]
    private let micCheckRegex: NSRegularExpression?
    private let micContextRegex: NSRegularExpression?
    private let transitionRegex: NSRegularExpression?
    private let directiveContextRegex: NSRegularExpression?
    private let compoundFeminineSubjectRegex: NSRegularExpression?
    private let compoundMasculineSubjectRegex: NSRegularExpression?
    private let neuterSubjectVerbRegex: NSRegularExpression?
    private let masculineSubjectVerbRegex: NSRegularExpression?
    private let feminineSubjectVerbRegex: NSRegularExpression?
    private let wordExtractorRegex: NSRegularExpression?

    private init() {
        var verbMap: [String: VerbGenderForms] = [:]
        for entry in Self.russianVerbFormsList {
            verbMap[entry.m.lowercased()] = entry
            verbMap[entry.f.lowercased()] = entry
            verbMap[entry.n.lowercased()] = entry
            verbMap[entry.pl.lowercased()] = entry
        }
        self.russianVerbLookup = verbMap

        // Precompile acoustic corrections
        var acousticCompiled: [(regex: NSRegularExpression, replacement: String)] = []
        for (incorrect, correct) in acousticCorrections {
            let pattern = "(?i)\\b" + NSRegularExpression.escapedPattern(for: incorrect) + "\\b"
            if let reg = try? NSRegularExpression(pattern: pattern) {
                acousticCompiled.append((regex: reg, replacement: correct))
            }
        }
        self.compiledAcousticCorrections = acousticCompiled

        // Precompile brand normalization rules
        var brandCompiled: [(regex: NSRegularExpression, replacement: String)] = []
        for rule in brandNormalizationRules {
            if let reg = try? NSRegularExpression(pattern: rule.pattern) {
                brandCompiled.append((regex: reg, replacement: rule.replacement))
            }
        }
        self.compiledBrandRules = brandCompiled

        // Precompile Russian grammar agreement rules
        var grammarCompiled: [(regex: NSRegularExpression, replacement: String)] = []
        for rule in russianGrammarAgreementRules {
            if let reg = try? NSRegularExpression(pattern: rule.pattern) {
                grammarCompiled.append((regex: reg, replacement: rule.replacement))
            }
        }
        self.compiledRussianGrammarRules = grammarCompiled

        // Precompile Ukrainian word map
        let ukrRules: [(pattern: String, replacement: String)] = [
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
        var ukrCompiled: [(regex: NSRegularExpression, replacement: String)] = []
        for rule in ukrRules {
            if let reg = try? NSRegularExpression(pattern: rule.pattern) {
                ukrCompiled.append((regex: reg, replacement: rule.replacement))
            }
        }
        self.compiledUkrainianWordMap = ukrCompiled

        // Precompile non-photo acoustic rules
        var nonPhotoCompiled: [(regex: NSRegularExpression, replacement: String)] = []
        for (incorrect, correct) in nonPhotoAcousticMap {
            let pattern = "(?i)\\b" + NSRegularExpression.escapedPattern(for: incorrect) + "\\b"
            if let reg = try? NSRegularExpression(pattern: pattern) {
                nonPhotoCompiled.append((regex: reg, replacement: correct))
            }
        }
        self.compiledNonPhotoRules = nonPhotoCompiled

        self.micCheckRegex = try? NSRegularExpression(pattern: "(?i)\\bраз[\\s,]+два[\\s,]+(?:три[\\s,]+)?проявк([а-яё]*)")
        self.micContextRegex = try? NSRegularExpression(pattern: "(?i)\\bпроявк([а-яё]*)\\s+(микрофон|связ|звук|работ|код|гипотез|систем|слух|качеств|данны|файло|тест)")

        let verbKeys = russianCommandVerbMap.keys.sorted { $0.count > $1.count }.joined(separator: "|")
        self.transitionRegex = try? NSRegularExpression(pattern: "(?i)(?:^|(?<=[.!?;\n])|\\b(?:и|а|потом|затем|теперь|дальше|ещ[её]|также|давай|просто|пожалуйста)\\s+)(" + verbKeys + ")\\b")

        let subjectExclusion = "(?:он|она|оно|сервер|скрипт|система|приложение|процесс|сервис|код|бот|воркер|пользователь|юзер|клиент|фреймворк)"
        self.directiveContextRegex = try? NSRegularExpression(pattern: "(?i)(?:^|(?<!\\b" + subjectExclusion + "\\s))\\b(" + verbKeys + ")\\s+(для\\b|в\\b|на\\b|из\\b|под\\b|отдельн|нов|файл|папк|сервер|компонент|скрипт|функци|класс|модул|роут|проект|таблиц|баз|конфиг|ветк|пул|код|тест|кнопк|баг|ошибк|запрос|ответ)")

        self.compoundFeminineSubjectRegex = try? NSRegularExpression(
            pattern: "(?i)\\b(команда|сборная|компания|организация|система|программа|утилита|библиотека|группа)\\s+([А-ЯЁа-яёA-Za-z0-9_-]+)\\s+([а-яё]+)\\b"
        )
        self.compoundMasculineSubjectRegex = try? NSRegularExpression(
            pattern: "(?i)\\b(клуб|состав|коллектив|город|сервер|сервис|проект|процесс)\\s+([А-ЯЁа-яёA-Za-z0-9_-]+)\\s+([а-яё]+)\\b"
        )
        self.neuterSubjectVerbRegex = try? NSRegularExpression(
            pattern: "(?i)\\b(Динамо|Торпедо|Монако|Порту|Атлетико|Лацио|Хетафе|Токио|Осло|Чикаго|жюри|метро|кино|пальто|меню|видео|радио|кафе|авто|пианино|резюме|приложение|действие|решение|событие|окно|сообщение|письмо|обновление|устройство|большинство|меньшинство|руководство|правительство|агентство|министерство|издательство|ведомство)\\s+([а-яё]+)\\b"
        )
        self.masculineSubjectVerbRegex = try? NSRegularExpression(
            pattern: "(?i)\\b(Локомотив|Спартак|Зенит|ЦСКА|Краснодар|Ростов|Рубин|Урал|Арсенал|Челси|Реал|Ювентус|Милан|Интер|Ливерпуль|Манчестер|Тоттенхэм|Аякс|ПСЖ|сервер|сервис|проект|бот|скрипт|процесс|код|файл|компьютер|телефон|канал|чат|сайт|бэкенд|фронтенд|терминал|модуль|алгоритм|запрос|ответ|процессор|контроллер|драйвер)\\s+([а-яё]+)\\b"
        )
        self.feminineSubjectVerbRegex = try? NSRegularExpression(
            pattern: "(?i)\\b(Барселона|Бавария|Севилья|Валенсия|Аталанта|Рома|Бенфика|Боруссия|система|программа|функция|утилита|библиотека|база|строка|ошибка|машина|модель|переменная|вкладка|страница|кнопка|задача)\\s+([а-яё]+)\\b"
        )

        self.wordExtractorRegex = try? NSRegularExpression(pattern: "\\b([\\p{L}\\p{M}'-]+)\\b")
    }

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
        for (regex, correct) in compiledAcousticCorrections {
            let range = NSRange(result.startIndex..<result.endIndex, in: result)
            result = regex.stringByReplacingMatches(
                in: result,
                options: [],
                range: range,
                withTemplate: correct
            )
        }

        // 1b. AI & Tech Brand name normalizations (e.g. "чат гпт" -> "ChatGPT", "chat gpt" -> "ChatGPT")
        for (regex, replacement) in compiledBrandRules {
            let range = NSRange(result.startIndex..<result.endIndex, in: result)
            result = regex.stringByReplacingMatches(
                in: result,
                options: [],
                range: range,
                withTemplate: replacement
            )
        }

        // 2. Context-aware Russian phrase corrections (e.g. testing / mic checks / non-photography speech)
        let hasPhotoContext = photographyKeywords.contains { lowerOriginal.contains($0) }
        if !hasPhotoContext {
            // "раз, два, три, проявка" -> "Раз, два, три, проверка."
            if let regex = micCheckRegex {
                let range = NSRange(result.startIndex..<result.endIndex, in: result)
                result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "Раз, два, три, проверк$1")
            }

            // "тест / проверка связи / микрофона"
            if let regex = micContextRegex {
                let range = NSRange(result.startIndex..<result.endIndex, in: result)
                result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "проверк$1 $2")
            }

            // General "проявка" -> "проверка" inflection map outside photography context
            for (regex, correct) in compiledNonPhotoRules {
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

        // 3. Token-level dictionary validation via Top 100 User Vocabulary & NSSpellChecker
        let langCode = resolveSpellCheckerLanguage(language: language, text: text)
        let isRussian = langCode.hasPrefix("ru")

        if isRussian {
            // 3a. Russian: Ukrainian sanitization, agreement, and imperative command mapping
            for (regex, rep) in compiledUkrainianWordMap {
                let range = NSRange(result.startIndex..<result.endIndex, in: result)
                result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: rep)
            }

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

            for (regex, rep) in compiledRussianGrammarRules {
                let range = NSRange(result.startIndex..<result.endIndex, in: result)
                result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: rep)
            }

            result = applyRussianSubjectVerbGenderAgreement(result)
            result = applyRussianCommandImperativeRules(result)
        } else if langCode.hasPrefix("de") {
            // 3b. German: Compound nouns & Substantiv-Großschreibung
            result = applyGermanRules(result)
        } else if langCode.hasPrefix("fr") {
            // 3c. French: Elision apostrophes & liaison
            result = applyFrenchRules(result)
        } else if langCode.hasPrefix("es") {
            // 3d. Spanish: Inverted punctuation & clitics
            result = applySpanishRules(result)
        } else if langCode.hasPrefix("it") {
            // 3e. Italian: Preposizioni articolate & elisions
            result = applyItalianRules(result)
        } else if langCode.hasPrefix("zh") {
            // 3f. Chinese: Full-width CJK punctuation & alphanumeric spacing
            result = applyChineseRules(result)
        } else if langCode.hasPrefix("hi") {
            // 3g. Hindi: Devanagari Unicode NFC normalization & Nukta correction
            result = applyHindiRules(result)
        }

        let customSet = Set(customVocabulary.map { $0.lowercased() })
        let userFreqDict = UserFrequencyDictionary.shared
        let userTop100Set = userFreqDict.topWordsSet(limit: 100)

        guard let wordRegex = wordExtractorRegex else { return result }

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

        // 1. Initial / transitional commands: "создает...", "и создает...", "потом делает...", "ну создает..."
        if let regex = transitionRegex {
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
        if let regex = directiveContextRegex {
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

    /// Systematically corrects subject-predicate past tense gender and number agreement in Russian.
    private func applyRussianSubjectVerbGenderAgreement(_ text: String) -> String {
        var result = text

        // 1. Compound subjects with feminine generic nouns ("команда Динамо обыграло/обыграл" -> "команда Динамо обыграла")
        if let regex = compoundFeminineSubjectRegex {
            let nsString = result as NSString
            let matches = regex.matches(in: result, options: [], range: NSRange(location: 0, length: nsString.length))
            for match in matches.reversed() {
                let verbRange = match.range(at: 3)
                let verbWord = nsString.substring(with: verbRange)
                let lowerVerb = verbWord.lowercased()
                if let forms = russianVerbLookup[lowerVerb] {
                    let matchedCase = matchCapitalization(original: verbWord, target: forms.f)
                    if let strRange = Range(verbRange, in: result) {
                        result.replaceSubrange(strRange, with: matchedCase)
                    }
                }
            }
        }

        // 2. Compound subjects with masculine generic nouns ("клуб Динамо обыграло/обыграла" -> "клуб Динамо обыграл")
        if let regex = compoundMasculineSubjectRegex {
            let nsString = result as NSString
            let matches = regex.matches(in: result, options: [], range: NSRange(location: 0, length: nsString.length))
            for match in matches.reversed() {
                let verbRange = match.range(at: 3)
                let verbWord = nsString.substring(with: verbRange)
                let lowerVerb = verbWord.lowercased()
                if let forms = russianVerbLookup[lowerVerb] {
                    let matchedCase = matchCapitalization(original: verbWord, target: forms.m)
                    if let strRange = Range(verbRange, in: result) {
                        result.replaceSubrange(strRange, with: matchedCase)
                    }
                }
            }
        }

        // 3. Neuter subjects (e.g. "Динамо обыграла" -> "Динамо обыграло", "видео набрала" -> "видео набрало")
        if let regex = neuterSubjectVerbRegex {
            let nsString = result as NSString
            let matches = regex.matches(in: result, options: [], range: NSRange(location: 0, length: nsString.length))
            for match in matches.reversed() {
                let verbRange = match.range(at: 2)
                let verbWord = nsString.substring(with: verbRange)
                let lowerVerb = verbWord.lowercased()
                if let forms = russianVerbLookup[lowerVerb] {
                    let matchedCase = matchCapitalization(original: verbWord, target: forms.n)
                    if let strRange = Range(verbRange, in: result) {
                        result.replaceSubrange(strRange, with: matchedCase)
                    }
                }
            }
        }

        // 4. Masculine subjects (e.g. "Локомотив обыграла" -> "Локомотив обыграл", "сервер упала" -> "сервер упал")
        if let regex = masculineSubjectVerbRegex {
            let nsString = result as NSString
            let matches = regex.matches(in: result, options: [], range: NSRange(location: 0, length: nsString.length))
            for match in matches.reversed() {
                let verbRange = match.range(at: 2)
                let verbWord = nsString.substring(with: verbRange)
                let lowerVerb = verbWord.lowercased()
                if let forms = russianVerbLookup[lowerVerb] {
                    let matchedCase = matchCapitalization(original: verbWord, target: forms.m)
                    if let strRange = Range(verbRange, in: result) {
                        result.replaceSubrange(strRange, with: matchedCase)
                    }
                }
            }
        }

        // 5. Feminine subjects (e.g. "Барселона обыграл" -> "Барселона обыграла", "система сработал" -> "система сработала")
        if let regex = feminineSubjectVerbRegex {
            let nsString = result as NSString
            let matches = regex.matches(in: result, options: [], range: NSRange(location: 0, length: nsString.length))
            for match in matches.reversed() {
                let verbRange = match.range(at: 2)
                let verbWord = nsString.substring(with: verbRange)
                let lowerVerb = verbWord.lowercased()
                if let forms = russianVerbLookup[lowerVerb] {
                    let matchedCase = matchCapitalization(original: verbWord, target: forms.f)
                    if let strRange = Range(verbRange, in: result) {
                        result.replaceSubrange(strRange, with: matchedCase)
                    }
                }
            }
        }

        return result
    }

    // MARK: - German Language Rules (Komposita & Capitalization)

    private func applyGermanRules(_ text: String) -> String {
        var result = text
        let compoundRules: [(pattern: String, replacement: String)] = [
            ("(?i)\\b(quell|quell-)\\s*(code|texte?)\\b", "Quell$2"),
            ("(?i)\\b(daten|daten-)\\s*(bank|banken|struktur|strukturen|sätze?)\\b", "Daten$2"),
            ("(?i)\\b(benutzer|benutzer-)\\s*(oberfläche|oberflächen|name|konten?)\\b", "Benutzer$2"),
            ("(?i)\\b(sprach|sprach-)\\s*(erkennung|modelle?|assistenten?)\\b", "Sprach$2"),
            ("(?i)\\b(software|software-)\\s*(entwicklung|ingenieure?|architektur)\\b", "Software$2"),
            ("(?i)\\b(kommando|kommando-)\\s*(zeile|zeilen)\\b", "Kommando$2"),
            ("(?i)\\b(entwickler|entwickler-)\\s*(werkzeuge?|tools?)\\b", "Entwickler$2")
        ]
        for rule in compoundRules {
            if let reg = try? NSRegularExpression(pattern: rule.pattern) {
                let range = NSRange(result.startIndex..<result.endIndex, in: result)
                result = reg.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: rule.replacement)
            }
        }
        return result
    }

    // MARK: - French Language Rules (Elision & Liaison)

    private func applyFrenchRules(_ text: String) -> String {
        var result = text
        let elisionRules: [(pattern: String, replacement: String)] = [
            ("(?i)\\b(l|d|c|j|qu|n|s|m|t)\\s+([aàâeéèêëiîïoôuûüyh][a-zàâäéèêëîïôöùûüç-]*)\\b", "$1'$2"),
            ("(?i)\\bd\\s+accord\\b", "d'accord"),
            ("(?i)\\bd\\s+exemple\\b", "d'exemple"),
            ("(?i)\\bc\\s+est\\b", "c'est"),
            ("(?i)\\bj\\s+ai\\b", "j'ai"),
            ("(?i)\\bqu\\s+il\\b", "qu'il"),
            ("(?i)\\bqu\\s+elle\\b", "qu'elle"),
            ("(?i)\\bn\\s+est\\b", "n'est"),
            ("(?i)\\bs\\s+il\\b", "s'il")
        ]
        for rule in elisionRules {
            if let reg = try? NSRegularExpression(pattern: rule.pattern) {
                let range = NSRange(result.startIndex..<result.endIndex, in: result)
                result = reg.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: rule.replacement)
            }
        }
        return result
    }

    // MARK: - Spanish Language Rules (Inverted Punctuation & Clitics)

    private func applySpanishRules(_ text: String) -> String {
        var result = text
        let spanishInterrogatives = "(?i)(?:^|(?<=[.!?;\n]\\s+))(cómo|qué|por qué|dónde|cuándo|cuál|cuáles|quién|quiénes|cuánto|cuánta|cuántos|cuántas)\\b([^.!?\n]*\\?)"
        if let reg = try? NSRegularExpression(pattern: spanishInterrogatives) {
            let range = NSRange(result.startIndex..<result.endIndex, in: result)
            result = reg.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "¿$1$2")
        }

        let cliticRules: [(pattern: String, replacement: String)] = [
            ("(?i)\\bdimelo\\b", "dímelo"),
            ("(?i)\\bhacelo\\b", "hacélo"),
            ("(?i)\\bcompralo\\b", "cómpralo"),
            ("(?i)\\bexplicame\\b", "explícame")
        ]
        for rule in cliticRules {
            if let reg = try? NSRegularExpression(pattern: rule.pattern) {
                let range = NSRange(result.startIndex..<result.endIndex, in: result)
                result = reg.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: rule.replacement)
            }
        }
        return result
    }

    // MARK: - Italian Language Rules (Preposizioni Articolate & Elisions)

    private func applyItalianRules(_ text: String) -> String {
        var result = text
        let prepRules: [(pattern: String, replacement: String)] = [
            ("(?i)\\bin\\s+il\\b", "nel"),
            ("(?i)\\bin\\s+lo\\b", "nello"),
            ("(?i)\\bin\\s+la\\b", "nella"),
            ("(?i)\\bin\\s+l'\\b", "nell'"),
            ("(?i)\\bin\\s+i\\b", "nei"),
            ("(?i)\\bin\\s+gli\\b", "negli"),
            ("(?i)\\bin\\s+le\\b", "nelle"),
            ("(?i)\\bdi\\s+il\\b", "del"),
            ("(?i)\\bdi\\s+lo\\b", "dello"),
            ("(?i)\\bdi\\s+la\\b", "della"),
            ("(?i)\\bdi\\s+l'\\b", "dell'"),
            ("(?i)\\bdi\\s+i\\b", "dei"),
            ("(?i)\\bdi\\s+gli\\b", "degli"),
            ("(?i)\\bdi\\s+le\\b", "delle"),
            ("(?i)\\ba\\s+il\\b", "al"),
            ("(?i)\\ba\\s+lo\\b", "allo"),
            ("(?i)\\ba\\s+la\\b", "alla"),
            ("(?i)\\ba\\s+l'\\b", "all'"),
            ("(?i)\\ba\\s+i\\b", "ai"),
            ("(?i)\\ba\\s+gli\\b", "agli"),
            ("(?i)\\ba\\s+le\\b", "alle"),
            ("(?i)\\bda\\s+il\\b", "dal"),
            ("(?i)\\bda\\s+lo\\b", "dallo"),
            ("(?i)\\bda\\s+la\\b", "dalla"),
            ("(?i)\\bda\\s+l'\\b", "dall'"),
            ("(?i)\\bda\\s+i\\b", "dai"),
            ("(?i)\\bda\\s+gli\\b", "dagli"),
            ("(?i)\\bda\\s+le\\b", "dalle"),
            ("(?i)\\bsu\\s+il\\b", "sul"),
            ("(?i)\\bsu\\s+lo\\b", "sullo"),
            ("(?i)\\bsu\\s+la\\b", "sulla"),
            ("(?i)\\bsu\\s+l'\\b", "sull'"),
            ("(?i)\\bsu\\s+i\\b", "sui"),
            ("(?i)\\bsu\\s+gli\\b", "sugli"),
            ("(?i)\\bsu\\s+le\\b", "sulle"),
            ("(?i)\\bqual'è\\b", "qual è"),
            ("(?i)\\bun\\s+amica\\b", "un'amica")
        ]
        for rule in prepRules {
            if let reg = try? NSRegularExpression(pattern: rule.pattern) {
                let range = NSRange(result.startIndex..<result.endIndex, in: result)
                result = reg.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: rule.replacement)
            }
        }
        return result
    }

    // MARK: - Chinese Language Rules (CJK Punctuation & Alphanumeric Spacing)

    private func applyChineseRules(_ text: String) -> String {
        var result = text

        // Convert ASCII punctuation to full-width CJK punctuation when surrounded by or adjacent to Chinese ideograms
        let cjkPunctuationMap: [(pattern: String, replacement: String)] = [
            ("(?<=[\u{4E00}-\u{9FFF}\u{3400}-\u{4DBF}]),(?=[\u{4E00}-\u{9FFF}\u{3400}-\u{4DBF}\\s]|$)", "，"),
            ("(?<=[\u{4E00}-\u{9FFF}\u{3400}-\u{4DBF}])\\.(?=[\\s]|$)", "。"),
            ("(?<=[\u{4E00}-\u{9FFF}\u{3400}-\u{4DBF}])\\?(?=[\\s]|$)", "？"),
            ("(?<=[\u{4E00}-\u{9FFF}\u{3400}-\u{4DBF}])!(?=[\\s]|$)", "！"),
            ("(?<=[\u{4E00}-\u{9FFF}\u{3400}-\u{4DBF}]):(?=[\\s]|$)", "："),
            ("(?<=[\u{4E00}-\u{9FFF}\u{3400}-\u{4DBF}];)(?=[\\s]|$)", "；")
        ]
        for rule in cjkPunctuationMap {
            if let reg = try? NSRegularExpression(pattern: rule.pattern) {
                let range = NSRange(result.startIndex..<result.endIndex, in: result)
                result = reg.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: rule.replacement)
            }
        }

        // Clean spacing between Chinese characters and English alphanumeric terms
        if let reg = try? NSRegularExpression(pattern: "([\u{4E00}-\u{9FFF}\u{3400}-\u{4DBF}])([A-Za-z0-9])") {
            let range = NSRange(result.startIndex..<result.endIndex, in: result)
            result = reg.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "$1 $2")
        }
        if let reg = try? NSRegularExpression(pattern: "([A-Za-z0-9])([\u{4E00}-\u{9FFF}\u{3400}-\u{4DBF}])") {
            let range = NSRange(result.startIndex..<result.endIndex, in: result)
            result = reg.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "$1 $2")
        }

        return result
    }

    // MARK: - Hindi Language Rules (Devanagari NFC & Nukta Normalization)

    private func applyHindiRules(_ text: String) -> String {
        // Enforce Unicode NFC normalization
        var result = text.precomposedStringWithCanonicalMapping

        // Normalize Nukta spacing and composite glyphs (फ़, ज़, ख़, ग़, क़)
        let nuktaRules: [(pattern: String, replacement: String)] = [
            ("फ\\s*़", "फ़"),
            ("ज\\s*़", "ज़"),
            ("क\\s*़", "क़"),
            ("ख\\s*़", "ख़"),
            ("ग\\s*़", "ग़"),
            ("ड\\s*़", "ड़"),
            ("ढ\\s*़", "ढ़")
        ]
        for rule in nuktaRules {
            if let reg = try? NSRegularExpression(pattern: rule.pattern) {
                let range = NSRange(result.startIndex..<result.endIndex, in: result)
                result = reg.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: rule.replacement)
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
            if lang.hasPrefix("it") { return "it_IT" }
            if lang.hasPrefix("zh") { return "zh_CN" }
            if lang.hasPrefix("hi") { return "hi_IN" }
        }

        // Detect Cyrillic presence for automatic Russian
        let cyrillicScalars = text.unicodeScalars.filter { $0.value >= 0x0400 && $0.value <= 0x04FF }
        if cyrillicScalars.count > 0 {
            return "ru_RU"
        }

        // Detect CJK ideographs for Chinese
        let cjkScalars = text.unicodeScalars.filter { ($0.value >= 0x4E00 && $0.value <= 0x9FFF) || ($0.value >= 0x3400 && $0.value <= 0x4DBF) }
        if cjkScalars.count > 0 {
            return "zh_CN"
        }

        // Detect Devanagari for Hindi
        let devanagariScalars = text.unicodeScalars.filter { $0.value >= 0x0900 && $0.value <= 0x097F }
        if devanagariScalars.count > 0 {
            return "hi_IN"
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
