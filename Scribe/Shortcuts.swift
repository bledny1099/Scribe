import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// Global hotkey to start/stop recording (default: ⌥S)
    static let toggleRecording = Self("toggleRecording", default: .init(.s, modifiers: .option))
}
