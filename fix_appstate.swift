import Foundation

var content = try! String(contentsOfFile: "/Users/aleksei/Documents/Scribe/Scribe/AppState.swift", encoding: .utf8)

let newProperties = """
    @AppStorage("noteExportMode") public var noteExportMode: String = "obsidian"
    @AppStorage("obsidianTargetNote") public var obsidianTargetNote: String = "Scribe Notes"
    @AppStorage("enableNotion") public var enableNotion: Bool = false
    @AppStorage("notionIntegrationToken") public var notionIntegrationToken: String = ""
    @AppStorage("notionPageId") public var notionPageId: String = ""
    @AppStorage("defaultNoteTags") public var defaultNoteTags: String = ""
    @AppStorage("appendDateToNotes") public var appendDateToNotes: Bool = true
"""

if let range = content.range(of: "@AppStorage(\\"autoTranslate\\") var autoTranslate: Bool = false") {
    content.insert(contentsOf: "\\n" + newProperties, at: range.upperBound)
}

content = content.replacingOccurrences(of: "func updateSettingsPreviewPanel() {", with: "func updateSettingsPreviewPanel(isDragging: Bool = false) {")
content = content.replacingOccurrences(of: "let targetOrigin = targetPreviewOrigin(for: selectedOverlayStyle, size: targetSize)", with: "let targetOrigin = targetPreviewOrigin(for: selectedOverlayStyle, size: targetSize, isDragging: isDragging)")

try! content.write(toFile: "/Users/aleksei/Documents/Scribe/Scribe/AppState.swift", atomically: true, encoding: .utf8)
