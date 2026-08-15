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

