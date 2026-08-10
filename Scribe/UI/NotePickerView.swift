import SwiftUI
import AppKit

class NoteNode: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let fullPath: String
    var children: [NoteNode]?
    
    init(name: String, fullPath: String, children: [NoteNode]? = nil) {
        self.name = name
        self.fullPath = fullPath
        self.children = children
    }
    
    static func == (lhs: NoteNode, rhs: NoteNode) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct NoteNodeView: View {
    let node: NoteNode
    @Binding var selection: String
    @Binding var isPresented: Bool
    @State private var isExpanded: Bool
    
    init(node: NoteNode, selection: Binding<String>, isPresented: Binding<Bool>, initiallyExpanded: Bool = false) {
        self.node = node
        self._selection = selection
        self._isPresented = isPresented
        self._isExpanded = State(initialValue: initiallyExpanded)
    }
    
    var body: some View {
        if let children = node.children {
            DisclosureGroup(isExpanded: $isExpanded) {
                ForEach(children) { child in
                    NoteNodeView(node: child, selection: $selection, isPresented: $isPresented)
                }
            } label: {
                Label(node.name, systemImage: "folder")
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation { isExpanded.toggle() }
                    }
            }
        } else {
            Button(action: {
                selection = node.fullPath
                isPresented = false
            }) {
                Label(node.name, systemImage: "doc.text")
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.vertical, 2)
        }
    }
}

struct NotePickerPopover: View {
    var nodes: [NoteNode]
    @Binding var selection: String
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            if nodes.isEmpty {
                Text("No notes found")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(nodes) { node in
                            NoteNodeView(node: node, selection: $selection, isPresented: $isPresented, initiallyExpanded: true)
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(width: 250, height: 280)
    }
}

struct NotePickerView: View {
    @Binding var targetNote: String
    var appType: NoteApp
    var vaultURL: String
    
    @State private var availableNodes: [NoteNode] = []
    @State private var isFetching = false
    @State private var showPopover = false
    
    var body: some View {
        HStack {
            TextField("e.g. Scribe Transcriptions", text: $targetNote)
                .textFieldStyle(.roundedBorder)
                .frame(width: 200)
                .popover(isPresented: $showPopover, attachmentAnchor: .point(.bottom), arrowEdge: .top) {
                    NotePickerPopover(nodes: availableNodes, selection: $targetNote, isPresented: $showPopover)
                }
            
            if isFetching {
                ProgressView()
                    .controlSize(.small)
            } else {
                Button(action: { showPopover.toggle() }) {
                    Image(systemName: "folder")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                
                Button(action: fetchNotes) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .onAppear {
            fetchNotes()
        }
        .onChange(of: vaultURL) { _ in
            if appType == .obsidian {
                fetchNotes()
            }
        }
    }
    
    private func fetchNotes() {
        guard !isFetching else { return }
        isFetching = true
        
        Task.detached(priority: .background) {
            var fetched: [String] = []
            
            if appType == .appleNotes {
                fetched = fetchAppleNotes()
            } else if appType == .obsidian {
                fetched = fetchObsidianNotes(vaultURLString: vaultURL)
            }
            
            let nodes = buildTree(from: fetched)
            
            await MainActor.run {
                self.availableNodes = nodes
                self.isFetching = false
            }
        }
    }
    
    nonisolated private func buildTree(from paths: [String]) -> [NoteNode] {
        let root = NoteNode(name: "root", fullPath: "", children: [])
        
        for path in paths {
            let parts = path.components(separatedBy: "/")
            var currentNode = root
            var currentPath = ""
            
            for (index, part) in parts.enumerated() {
                let isFile = (index == parts.count - 1)
                currentPath += (currentPath.isEmpty ? "" : "/") + part
                
                if let existing = currentNode.children?.first(where: { $0.name == part && ($0.children == nil) == isFile }) {
                    currentNode = existing
                } else {
                    let newNode = NoteNode(name: part, fullPath: isFile ? currentPath : "", children: isFile ? nil : [])
                    currentNode.children?.append(newNode)
                    currentNode = newNode
                }
            }
        }
        
        func sortNode(_ node: NoteNode) {
            node.children?.sort(by: { 
                let lhsIsDir = $0.children != nil
                let rhsIsDir = $1.children != nil
                if lhsIsDir && !rhsIsDir { return true }
                if !lhsIsDir && rhsIsDir { return false }
                return $0.name.localizedStandardCompare($1.name) == .orderedAscending
            })
            node.children?.forEach { sortNode($0) }
        }
        sortNode(root)
        
        return root.children ?? []
    }
    
    nonisolated private func fetchAppleNotes() -> [String] {
        let scriptSource = """
        tell application "Notes"
            set outList to {}
            
            script folderTraversal
                on getNotes(currentFolder, currentPath)
                    using terms from application "Notes"
                        repeat with n in notes of currentFolder
                            set end of outList to currentPath & name of n
                        end repeat
                        repeat with f in folders of currentFolder
                            getNotes(f, currentPath & name of f & "/")
                        end repeat
                    end using terms from
                end getNotes
            end script
            
            repeat with a in accounts
                set accName to name of a
                repeat with f in folders of a
                    folderTraversal's getNotes(f, accName & "/" & name of f & "/")
                end repeat
            end repeat
            
            return outList
        end tell
        """
        
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: scriptSource) {
            let output = scriptObject.executeAndReturnError(&error)
            if let listDescriptor = output.coerce(toDescriptorType: typeAEList) {
                var notes: [String] = []
                for i in 1...listDescriptor.numberOfItems {
                    if let noteName = listDescriptor.atIndex(i)?.stringValue {
                        notes.append(noteName)
                    }
                }
                return notes
            } else if error != nil {
                print("AppleScript fetch notes error")
            }
        }
        
        return []
    }
    
    nonisolated private func fetchObsidianNotes(vaultURLString: String) -> [String] {
        guard !vaultURLString.isEmpty, let vaultURL = URL(string: vaultURLString) else { return [] }
        let fileManager = FileManager.default
        var notes: [String] = []
        
        let keys: [URLResourceKey] = [.isRegularFileKey]
        if let enumerator = fileManager.enumerator(at: vaultURL, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]) {
            for case let fileURL as URL in enumerator {
                if fileURL.pathExtension == "md" {
                    let path = fileURL.path
                    let vaultPath = vaultURL.path
                    
                    var relativePath = path
                    if path.hasPrefix(vaultPath) {
                        relativePath = String(path.dropFirst(vaultPath.count))
                        if relativePath.hasPrefix("/") {
                            relativePath = String(relativePath.dropFirst())
                        }
                    }
                    
                    if relativePath.hasSuffix(".md") {
                        relativePath = String(relativePath.dropLast(3))
                    }
                    
                    notes.append(relativePath)
                }
            }
        }
        return notes
    }
}
