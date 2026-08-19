import AppKit
import Foundation
import os.log

private let logger = Logger(subsystem: "com.aleksei.scribe", category: "AetherContextEngine")

/// Aether Context Biasing Engine (Stage A):
/// Captures active window context and blends it with custom vocabulary to condition acoustic models.
public final class AetherContextEngine: @unchecked Sendable {

    public static let shared = AetherContextEngine()

    private init() {}

    public enum AppDomain {
        case development
        case communication
        case writing
        case general
    }

    /// Determines the domain of the frontmost application
    public func detectActiveAppDomain(targetApp: NSRunningApplication? = nil) -> (name: String, domain: AppDomain) {
        let app = targetApp ?? NSWorkspace.shared.frontmostApplication
        let name = app?.localizedName ?? "General"
        let bundleId = app?.bundleIdentifier?.lowercased() ?? ""

        if bundleId.contains("xcode") ||
           bundleId.contains("vscode") ||
           bundleId.contains("cursor") ||
           bundleId.contains("terminal") ||
           bundleId.contains("iterm") ||
           bundleId.contains("warp") ||
           bundleId.contains("intellij") ||
           bundleId.contains("pycharm") ||
           bundleId.contains("webstorm") ||
           bundleId.contains("sublime") {
            return (name, .development)
        }

        if bundleId.contains("telegram") ||
           bundleId.contains("slack") ||
           bundleId.contains("discord") ||
           bundleId.contains("whatsapp") ||
           bundleId.contains("messages") ||
           bundleId.contains("viber") ||
           bundleId.contains("signal") {
            return (name, .communication)
        }

        if bundleId.contains("notion") ||
           bundleId.contains("obsidian") ||
           bundleId.contains("notes") ||
           bundleId.contains("bear") ||
           bundleId.contains("craft") ||
           bundleId.contains("ulysses") ||
           bundleId.contains("pages") ||
           bundleId.contains("word") {
            return (name, .writing)
        }

        return (name, .general)
    }

    /// Constructs domain-specific contextual priming hints
    public func domainContextPrompt(for domain: AppDomain, language: String?) -> String {
        let lang = (language ?? "").lowercased()
        let isRussianOnly = lang.starts(with: "ru")
        let isEnglishOnly = lang.starts(with: "en")

        switch domain {
        case .development:
            if isRussianOnly {
                return "Контекст разработки кода, терминала и IDE: Git, Swift, TypeScript, Python, Docker, API, PR, commit, merge, branch, function, async, await, deploy, bugs, проект, ветка, коммит."
            } else if isEnglishOnly {
                return "Code development & terminal context: Git, Swift, TypeScript, Python, Docker, API, PR, commit, merge, branch, function, async, await, deploy, bugs."
            } else {
                return "Bilingual code development context (Russian & English): Git, Swift, Xcode, TypeScript, Python, Docker, API, PR, commit, merge, branch, function, async, await, deploy, bugs, проект, ветка, коммит, функция, правка."
            }
        case .communication:
            if isRussianOnly {
                return "Разговорная переписка в мессенджере с естественной пунктуацией, запятыми и эмодзи."
            } else if isEnglishOnly {
                return "Casual chat and messaging context with natural punctuation, commas, and formatting."
            } else {
                return "Casual multilingual chat (Russian & English): естественная переписка, messaging, пунктуация, commas, эмодзи."
            }
        case .writing:
            if isRussianOnly {
                return "Структурированные заметки, документы, списки и заголовки с четкой пунктуацией."
            } else if isEnglishOnly {
                return "Structured documentation, notes, outlines, and clear punctuation."
            } else {
                return "Structured notes & documentation (Russian & English): заметки, списки, headers, punctuation, форматирование."
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
        let (appName, domain) = detectActiveAppDomain(targetApp: targetApp)
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

        if !customVocabulary.isEmpty {
            components.append("Custom Terms: \(customVocabulary).")
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

        // Add custom vocabulary items
        let customWords = customVocabulary
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

        // Add domain terms
        let (_, domain) = detectActiveAppDomain(targetApp: targetApp)
        if domain == .development {
            strings.append(contentsOf: ["GitHub", "GitLab", "Xcode", "VS Code", "Terminal", "Docker", "Kubernetes", "Next.js", "TailwindCSS", "PostgreSQL", "GraphQL", "TypeScript", "SwiftData", "LLM", "API"])
        }

        return Array(Set(strings)).prefix(100).map { $0 }
    }
}
