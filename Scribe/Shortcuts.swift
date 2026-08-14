import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// Global hotkey to start/stop recording (default: ⌥S)
    static let toggleRecording = Self("toggleRecording", default: .init(.s, modifiers: .option))

    /// Global hotkey to record and save directly to Notes/Integrations (default: ⌥N)
    static let directNoteRecording = Self("directNoteRecording", default: .init(.n, modifiers: .option))
}
