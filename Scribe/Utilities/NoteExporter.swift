import Foundation
import Cocoa
import OSLog

private let logger = Logger(subsystem: "com.scribe.app", category: "NoteExporter")

enum NoteApp: String, CaseIterable, Identifiable {
    case none = "none"
    case appleNotes = "appleNotes"
    case obsidian = "obsidian"
    case notion = "notion"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .none: return "None"
        case .appleNotes: return "Apple Notes"
        case .obsidian: return "Obsidian"
        case .notion: return "Notion"
        }
    }
}

enum ExportMode: String, CaseIterable, Identifiable {
    case newNote = "newNote"
    case append = "append"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .newNote: return "New Note"
        case .append: return "Append"
        }
    }
}

class NoteExporter {
    
    @MainActor
    static func export(text: String, state: AppState) {
        guard !text.isEmpty else { return }
        
        let directApps = state.directNoteTargetApps
        let isDirect = state.isDirectNoteRecording
        
        // Export to Apple Notes if explicitly enabled OR if triggered via Direct Note Hotkey with target Apple Notes
        if state.enableAppleNotes || (isDirect && directApps.contains(.appleNotes)) {
            exportToAppleNotes(text: text, mode: state.appleNotesExportMode, targetNote: state.appleNotesTargetNote, state: state)
        }
        
        // Export to Obsidian if explicitly enabled OR if triggered via Direct Note Hotkey with target Obsidian
        if state.enableObsidian || (isDirect && directApps.contains(.obsidian)) {
            exportToObsidian(text: text, mode: state.noteExportMode, vaultURLString: state.obsidianVaultURL, targetNote: state.obsidianTargetNote, state: state)
        }
        
        // Export to Notion if explicitly enabled OR if triggered via Direct Note Hotkey with target Notion
        if state.enableNotion || (isDirect && directApps.contains(.notion)) {
            let token = KeychainHelper.shared.getNotionToken()
            exportToNotion(text: text, mode: state.noteExportMode, integrationToken: token, pageId: state.notionPageId, state: state)
        }
    }
    
    // MARK: - Apple Notes (Hardened AppleScript)
    
    @MainActor
    private static func exportToAppleNotes(text: String, mode: ExportMode, targetNote: String, state: AppState) {
        let dateString = DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short)
        
        // Sanitize text: HTML entity escaping + AppleScript string escaping
        let sanitizedText = text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\n", with: "<br>")
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        let words = text.split { $0.isWhitespace || $0.isNewline }
        let rawTitle = words.count <= 6 ? text : words.prefix(6).joined(separator: " ") + "..."
        let sanitizedTitle = rawTitle
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        
        let tagsText = state.defaultNoteTags.isEmpty ? "" : "<br><br>\(state.defaultNoteTags.replacingOccurrences(of: "\"", with: "\\\""))"
        let dateHeader = state.appendDateToNotes ? "<p><b>\(dateString):</b></p>" : ""
        
        let scriptSource: String
        if mode == .newNote {
            scriptSource = """
            tell application "Notes"
                make new note with properties {body:"\(dateHeader)<p>\(sanitizedText)\(tagsText)</p>"}
            end tell
            """
        } else {
            let noteName = targetNote.isEmpty ? "Scribe Transcriptions" : targetNote
            let sanitizedNoteName = noteName
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
            scriptSource = """
            tell application "Notes"
                if not (exists note "\(sanitizedNoteName)") then
                    make new note with properties {name:"\(sanitizedNoteName)", body:"<p>\(sanitizedNoteName)</p>"}
                end if
                make new paragraph at end of text of note "\(sanitizedNoteName)" with data "\(dateHeader)<p>\(sanitizedText)\(tagsText)</p>"
            end tell
            """
        }
        
        // Execute asynchronously off the main actor to prevent blocking UI
        DispatchQueue.global(qos: .userInitiated).async {
            var error: NSDictionary?
            if let scriptObject = NSAppleScript(source: scriptSource) {
                scriptObject.executeAndReturnError(&error)
                if let error = error {
                    logger.error("Apple Notes Export AppleScript Error: \(error)")
                } else {
                    logger.info("Successfully exported transcript to Apple Notes")
                }
            }
        }
    }
    
    // MARK: - Obsidian (Path Traversal Hardening)
    
    @MainActor
    private static func exportToObsidian(text: String, mode: ExportMode, vaultURLString: String, targetNote: String, state: AppState) {
        guard !vaultURLString.isEmpty, let vaultURL = URL(string: vaultURLString) else {
            logger.error("Obsidian Export Error: No vault URL selected.")
            return
        }
        
        let dateString = DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        
        // Sanitize filename to prevent path traversal
        let rawNoteName: String
        if mode == .newNote {
            rawNoteName = "Scribe_\(dateFormatter.string(from: Date())).md"
        } else {
            let base = targetNote.isEmpty ? "Scribe Transcriptions" : targetNote
            // Strip any illegal filesystem characters or ../ attempts
            let cleanBase = base.components(separatedBy: CharacterSet(charactersIn: "/\\:?%*|\"<>")).joined(separator: "_")
            rawNoteName = "\(cleanBase).md"
        }
        
        let fileURL = vaultURL.appendingPathComponent(rawNoteName).standardizedFileURL
        
        // Security check: Ensure fileURL is within vault directory
        guard fileURL.path.hasPrefix(vaultURL.standardizedFileURL.path) else {
            logger.error("Obsidian Export Error: Path traversal attempt detected.")
            return
        }
        
        let smartTitle: String
        let words = text.split { $0.isWhitespace || $0.isNewline }
        if words.count <= 6 {
            smartTitle = text
        } else {
            smartTitle = words.prefix(6).joined(separator: " ") + "..."
        }
        
        let tagsText = state.defaultNoteTags.isEmpty ? "" : "\n\n\(state.defaultNoteTags)"
        let contentToAppend = (state.appendDateToNotes ? "\n\n### \(dateString)\n\(text)" : "\n\n\(text)") + tagsText
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                if FileManager.default.fileExists(atPath: fileURL.path) {
                    let fileHandle = try FileHandle(forWritingTo: fileURL)
                    fileHandle.seekToEndOfFile()
                    if let data = contentToAppend.data(using: .utf8) {
                        fileHandle.write(data)
                    }
                    fileHandle.closeFile()
                } else {
                    let initialContent = "# \(smartTitle)\n" + contentToAppend
                    try initialContent.write(to: fileURL, atomically: true, encoding: .utf8)
                }
                logger.info("Successfully exported transcript to Obsidian (\(fileURL.lastPathComponent))")
            } catch {
                logger.error("Obsidian Export Error: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Notion (HTTPS & Bearer Header)
    
    @MainActor
    private static func exportToNotion(text: String, mode: ExportMode, integrationToken: String, pageId: String, state: AppState) {
        guard !integrationToken.isEmpty, !pageId.isEmpty else {
            logger.error("Notion Export Error: Missing token or page ID")
            return
        }
        
        let cleanPageId = pageId.replacingOccurrences(of: "-", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: "https://api.notion.com/v1/blocks/\(cleanPageId)/children") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.addValue("Bearer \(integrationToken)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("2022-06-28", forHTTPHeaderField: "Notion-Version")
        request.timeoutInterval = 10
        
        let dateString = DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short)
        let tagsText = state.defaultNoteTags.isEmpty ? "" : "\n\n\(state.defaultNoteTags)"
        let finalOutputText = text + tagsText
        
        let textBlock: [String: Any]
        if state.appendDateToNotes {
            textBlock = [
                "object": "block",
                "type": "paragraph",
                "paragraph": [
                    "rich_text": [
                        [
                            "type": "text",
                            "text": ["content": "\(dateString):\n"],
                            "annotations": ["bold": true]
                        ],
                        [
                            "type": "text",
                            "text": ["content": finalOutputText]
                        ]
                    ]
                ]
            ]
        } else {
            textBlock = [
                "object": "block",
                "type": "paragraph",
                "paragraph": [
                    "rich_text": [
                        [
                            "type": "text",
                            "text": ["content": finalOutputText]
                        ]
                    ]
                ]
            ]
        }
        
        let body: [String: Any] = ["children": [textBlock]]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                logger.error("Notion Export Error: \(error.localizedDescription)")
                return
            }
            if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                logger.error("Notion Export HTTP Error: \(httpResponse.statusCode)")
            } else {
                logger.info("Successfully exported transcript to Notion")
            }
        }
        task.resume()
    }
}
