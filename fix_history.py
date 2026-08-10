import re

with open('/Users/aleksei/Documents/Scribe/Scribe/UI/HistoryView.swift', 'r') as f:
    content = f.read()

# Add inSettings flag
old_decl = """struct HistoryView: View {
    @ObservedObject var history = TranscriptionHistory.shared
    @State private var searchText = ""
    @State private var copiedId: UUID?
"""
new_decl = """struct HistoryView: View {
    @ObservedObject var history = TranscriptionHistory.shared
    @State private var searchText = ""
    @State private var copiedId: UUID?
    
    var inSettings: Bool = false
"""
content = content.replace(old_decl, new_decl)

# Hide Header if inSettings
old_header = """            // Header
            HStack {"""
new_header = """            // Header
            if !inSettings {
            HStack {"""
content = content.replace(old_header, new_header)

old_header_end = """            .padding(.top, 24)
            .padding(.bottom, 12)"""
new_header_end = """            .padding(.top, 24)
            .padding(.bottom, 12)
            }"""
content = content.replace(old_header_end, new_header_end)

# Modify frame and shadow
old_modifiers = """        .ignoresSafeArea(.container, edges: .top)
        .frame(width: 440, height: 560)
        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)"""
new_modifiers = """        .ignoresSafeArea(.container, edges: .top)
        .frame(maxWidth: inSettings ? .infinity : 440, maxHeight: inSettings ? .infinity : 560)
        .shadow(color: .black.opacity(0.3), radius: inSettings ? 0 : 20, x: 0, y: inSettings ? 0 : 10)"""
content = content.replace(old_modifiers, new_modifiers)

with open('/Users/aleksei/Documents/Scribe/Scribe/UI/HistoryView.swift', 'w') as f:
    f.write(content)
