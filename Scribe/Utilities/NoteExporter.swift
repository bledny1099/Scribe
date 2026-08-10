import Foundation
import Cocoa

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
        
        if state.enableAppleNotes {
            exportToAppleNotes(text: text, mode: state.noteExportMode, targetNote: state.appleNotesTargetNote, state: state)
        }
        
        if state.enableObsidian {
            exportToObsidian(text: text, mode: state.noteExportMode, vaultURLString: state.obsidianVaultURL, targetNote: state.obsidianTargetNote, state: state)
        }
        
        if state.enableNotion {
            exportToNotion(text: text, mode: state.noteExportMode, integrationToken: state.notionIntegrationToken, pageId: state.notionPageId, state: state)
        }
    }
    
    // MARK: - Apple Notes
    
    @MainActor
    private static func exportToAppleNotes(text: String, mode: ExportMode, targetNote: String, state: AppState) {
        // AppleScript to interact with Notes app
        let scriptSource: String
        
        // Escape text for AppleScript string
        let escapedText = text.replacingOccurrences(of: "\"", with: "\\\"").replacingOccurrences(of: "\n", with: "<br>")
        let dateString = DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short)
        
        let smartTitle: String
        let words = text.split { $0.isWhitespace || $0.isNewline }
        if words.count <= 6 {
            smartTitle = text
        } else {
            smartTitle = words.prefix(6).joined(separator: " ") + "..."
        }
        
        let tagsText = state.defaultNoteTags.isEmpty ? "" : "<br><br>\\(state.defaultNoteTags)"
        
        if mode == .newNote {
            scriptSource = """
            tell application "Notes"
                tell account "iCloud"
                    make new note with properties {name:"\\(smartTitle)", body:"<h1>\\(smartTitle)</h1><p>\\(escapedText)\\(tagsText)</p>"}
                end tell
            end tell
            """
        } else {
            let fullPath = targetNote.isEmpty ? "Scribe Transcriptions" : targetNote
            let parts = fullPath.components(separatedBy: "/")
            let noteName: String
            let accountTarget: String
            
            if parts.count >= 2 {
                accountTarget = "tell account \"\(parts[0])\""
                noteName = parts.last!
            } else {
                accountTarget = "tell account \"iCloud\""
                noteName = fullPath
            }
            
            let datePrefix = state.appendDateToNotes ? "<p><b>\\(dateString):</b><br>" : "<p>"
            let dateSuffix = "</p>"
            
            scriptSource = """
            tell application "Notes"
                \\(accountTarget)
                    if not (exists note "\\(noteName)") then
                        make new note with properties {name:"\\(noteName)", body:"<h1>\\(noteName)</h1>"}
                    end if
                    set currentBody to body of note "\\(noteName)"
                    set body of note "\\(noteName)" to currentBody & "\\(datePrefix)\\(escapedText)\\(tagsText)\\(dateSuffix)"
                end tell
            end tell
            """
        }
        
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: scriptSource) {
            scriptObject.executeAndReturnError(&error)
            if let error = error {
                print("AppleScript Error: \(error)")
            }
        }
    }
    
    // MARK: - Obsidian
    
    @MainActor
    private static func exportToObsidian(text: String, mode: ExportMode, vaultURLString: String, targetNote: String, state: AppState) {
        guard !vaultURLString.isEmpty, let vaultURL = URL(string: vaultURLString) else {
            print("Obsidian Export Error: No vault URL selected.")
            return
        }
        
        let dateString = DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        
        let noteName: String
        if mode == .newNote {
            noteName = "Scribe_\(dateFormatter.string(from: Date())).md"
        } else {
            noteName = (targetNote.isEmpty ? "Scribe Transcriptions" : targetNote) + ".md"
        }
        
        let fileURL = vaultURL.appendingPathComponent(noteName)
        
        let smartTitle: String
        let words = text.split { $0.isWhitespace || $0.isNewline }
        if words.count <= 6 {
            smartTitle = text
        } else {
            smartTitle = words.prefix(6).joined(separator: " ") + "..."
        }
        
        let tagsText = state.defaultNoteTags.isEmpty ? "" : "\n\n\\(state.defaultNoteTags)"
        
        let contentToAppend = (state.appendDateToNotes ? "\n\n### \\(dateString)\n\\(text)" : "\n\n\\(text)") + tagsText
        
        do {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                let fileHandle = try FileHandle(forWritingTo: fileURL)
                fileHandle.seekToEndOfFile()
                if let data = contentToAppend.data(using: .utf8) {
                    fileHandle.write(data)
                }
                fileHandle.closeFile()
            } else {
                let initialContent = "# \\(smartTitle)\n" + contentToAppend
                try initialContent.write(to: fileURL, atomically: true, encoding: .utf8)
            }
        } catch {
            print("Obsidian Export Error: \(error)")
        }
    }
    
    // MARK: - Notion
    
    @MainActor
    private static func exportToNotion(text: String, mode: ExportMode, integrationToken: String, pageId: String, state: AppState) {
        guard !integrationToken.isEmpty, !pageId.isEmpty else {
            print("Notion Export Error: Missing token or page ID")
            return
        }
        
        let url = URL(string: "https://api.notion.com/v1/blocks/\(pageId)/children")!
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.addValue("Bearer \(integrationToken)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("2022-06-28", forHTTPHeaderField: "Notion-Version")
        
        let dateString = DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short)
        
        let tagsText = state.defaultNoteTags.isEmpty ? "" : "\n\n\\(state.defaultNoteTags)"
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
                            "text": ["content": "\\(dateString):\n"],
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
                print("Notion Export Error: \(error)")
                return
            }
            if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                print("Notion Export HTTP Error: \(httpResponse.statusCode)")
                if let data = data, let responseString = String(data: data, encoding: .utf8) {
                    print("Notion Response: \(responseString)")
                }
            }
        }
        task.resume()
    }
}
