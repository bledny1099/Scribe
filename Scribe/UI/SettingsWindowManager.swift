import AppKit
import SwiftUI

/// Manages a custom, borderless transparent window for the Settings screen.
@MainActor
final class SettingsWindowManager {
    static let shared = SettingsWindowManager()

    private var window: NSWindow?
    private weak var currentAppState: AppState?

    private init() {}

    func showSettings(appState: AppState) {
        self.currentAppState = appState
        if let existingWindow = window {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 620),
            styleMask: [.titled, .fullSizeContentView, .closable],
            backing: .buffered,
            defer: false
        )
        
        newWindow.titlebarAppearsTransparent = true
        newWindow.titleVisibility = .hidden
        newWindow.standardWindowButton(.closeButton)?.isHidden = true
        newWindow.standardWindowButton(.miniaturizeButton)?.isHidden = true
        newWindow.standardWindowButton(.zoomButton)?.isHidden = true

        newWindow.isMovableByWindowBackground = true
        newWindow.isOpaque = false
        newWindow.backgroundColor = .clear 
        newWindow.hasShadow = true
        newWindow.level = .normal
        newWindow.hidesOnDeactivate = false

        let blurView = NSVisualEffectView()
        blurView.material = .popover
        blurView.blendingMode = .behindWindow
        blurView.state = .active
        // Removed custom layer corner radius to let the native window handle it perfectly without artifacts


        // Wrap the SwiftUI view
        let settingsView = SettingsView().environmentObject(appState)
        let hostingView = NSHostingView(rootView: settingsView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor

        blurView.addSubview(hostingView)
        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: blurView.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: blurView.bottomAnchor),
            hostingView.leadingAnchor.constraint(equalTo: blurView.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: blurView.trailingAnchor),
        ])

        newWindow.contentView = blurView
        newWindow.center()
        newWindow.isReleasedWhenClosed = false
        newWindow.delegate = WindowDelegate.shared

        self.window = newWindow

        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    var isWindowOpen: Bool {
        window != nil
    }

    var windowFrame: NSRect? {
        window?.frame
    }

    func closeWindow() {
        currentAppState?.hideSettingsPreviewPanel()
        window?.close()
        window = nil
    }

    func windowClosed() {
        currentAppState?.hideSettingsPreviewPanel()
        window = nil
        currentAppState = nil
    }
}

@MainActor
private class WindowDelegate: NSObject, NSWindowDelegate, @unchecked Sendable {
    static let shared = WindowDelegate()

    func windowWillClose(_ notification: Notification) {
        SettingsWindowManager.shared.windowClosed()
    }
}
