import AppKit
import Carbon.HIToolbox
import os.log

private let logger = Logger(subsystem: "com.aleksei.scribe", category: "PasteService")

/// Handles clipboard operations and simulated keyboard events for pasting.
@MainActor
final class PasteService {

    /// Copies text to the system pasteboard.
    static func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    /// Appends text to the current clipboard content (separated by a space).
    static func appendToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        let existing = pasteboard.string(forType: .string) ?? ""
        let combined = existing.isEmpty ? text : existing + " " + text
        pasteboard.clearContents()
        pasteboard.setString(combined, forType: .string)
    }

    /// Reads preceding text before cursor to detect if we're continuing an existing sentence
    static func getPrecedingTextContext() -> String? {
        guard AXIsProcessTrusted() else { return nil }
        let systemWide = AXUIElementCreateSystemWide()
        var focusedElement: AnyObject?
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focusedElement) == .success,
              let element = focusedElement as! AXUIElement? else { return nil }

        // 1. Get selected text range
        var selectedRangeValue: AnyObject?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &selectedRangeValue) == .success,
              let rangeVal = selectedRangeValue else { return nil }

        var range = CFRange()
        guard AXValueGetValue(rangeVal as! AXValue, .cfRange, &range) else { return nil }

        // 2. Get full text value of focused field
        var fullTextValue: AnyObject?
        guard AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &fullTextValue) == .success,
              let fullString = fullTextValue as? String else { return nil }

        let cursorIndex = max(0, min(range.location, fullString.count))
        let precedingString = String(fullString.prefix(cursorIndex))
        return precedingString
    }

    /// Adjusts first-letter casing to lowercase if inserting into an ongoing sentence
    static func adjustCasingForContext(text: String) -> String {
        guard !text.isEmpty else { return text }
        guard let preceding = getPrecedingTextContext() else { return text }

        let trimmedPreceding = preceding.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPreceding.isEmpty else { return text }

        if let lastChar = trimmedPreceding.last {
            // Sentence enders require uppercase
            let sentenceEnders: Set<Character> = [".", "!", "?", "…", "\n", "\r"]
            if !sentenceEnders.contains(lastChar) {
                // Mid-sentence continuation: Lowercase first letter
                let firstChar = text.prefix(1)
                let remaining = text.dropFirst()
                return firstChar.lowercased() + remaining
            }
        }
        return text
    }

    /// Checks if Accessibility permission is currently granted.
    static func isAccessibilityGranted() -> Bool {
        return AXIsProcessTrusted()
    }

    /// Simulates ⌘V keystroke via CGEvent to paste into the active application.
    /// Requires Accessibility permission.
    @discardableResult
    static func simulatePaste() -> Bool {
        // If Scribe itself is in focus / active, dispatch native paste to the focused text field
        if NSApp.isActive || (SettingsWindowManager.shared.window?.isKeyWindow == true) {
            if let keyWindow = NSApp.keyWindow, keyWindow.firstResponder != nil {
                let handled = NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: nil)
                if handled {
                    logger.info("Successfully dispatched native paste to Scribe active text field")
                    return true
                }
            }
        }

        guard isAccessibilityGranted() else {
            logger.warning("Accessibility permission not granted — simulatePaste skipped. Text remains in clipboard.")
            return false
        }

        guard let source = CGEventSource(stateID: .hidSystemState),
              let keyDown = CGEvent(keyboardEventSource: source, virtualKey: UInt16(kVK_ANSI_V), keyDown: true),
              let keyUp   = CGEvent(keyboardEventSource: source, virtualKey: UInt16(kVK_ANSI_V), keyDown: false) else {
            logger.error("Failed to create CGEvent for ⌘V paste simulation")
            return false
        }

        keyDown.flags = .maskCommand
        keyUp.flags   = .maskCommand

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)

        logger.info("Successfully posted ⌘V keystrokes to .cghidEventTap")
        return true
    }

    /// Types text directly into the focused window using simulated Unicode keystrokes.
    static func typeText(_ text: String) {
        guard !text.isEmpty, isAccessibilityGranted() else { return }
        guard let source = CGEventSource(stateID: .hidSystemState) else { return }

        for char in text.utf16 {
            var utf16Char = char
            if let eventDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true) {
                eventDown.keyboardSetUnicodeString(stringLength: 1, unicodeString: &utf16Char)
                eventDown.post(tap: .cghidEventTap)
            }
            if let eventUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) {
                eventUp.keyboardSetUnicodeString(stringLength: 1, unicodeString: &utf16Char)
                eventUp.post(tap: .cghidEventTap)
            }
        }
    }

    /// Sends N backspaces to erase previously streamed draft text in the active window.
    static func sendBackspaces(count: Int) {
        guard count > 0, isAccessibilityGranted() else { return }
        guard let source = CGEventSource(stateID: .hidSystemState) else { return }

        for _ in 0..<count {
            if let keyDown = CGEvent(keyboardEventSource: source, virtualKey: UInt16(kVK_Delete), keyDown: true),
               let keyUp = CGEvent(keyboardEventSource: source, virtualKey: UInt16(kVK_Delete), keyDown: false) {
                keyDown.post(tap: .cghidEventTap)
                keyUp.post(tap: .cghidEventTap)
            }
        }
    }

    /// Checks (and optionally prompts for) Accessibility trust.
    /// Returns `true` when the app is already trusted.
    @discardableResult
    static func requestAccessibilityPermission() -> Bool {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        let isTrusted = AXIsProcessTrustedWithOptions(options)
        logger.info("requestAccessibilityPermission checked, isTrusted: \(isTrusted)")
        
        if !isTrusted {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
        
        return isTrusted
    }
}

