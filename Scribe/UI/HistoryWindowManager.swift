import AppKit
import SwiftUI

/// Manages a custom, borderless transparent window for the History screen.
@MainActor
final class HistoryWindowManager {
    static let shared = HistoryWindowManager()

    private var window: NSWindow?
    private var blurView: NSVisualEffectView?
    private weak var currentAppState: AppState?

    private init() {}

    func showWindow(appState: AppState) {
        self.currentAppState = appState
        if let existing = window {
            if existing.alphaValue == 0 {
                existing.makeKeyAndOrderFront(nil)
                NSAnimationContext.runAnimationGroup { ctx in
                    ctx.duration = 0.25
                    existing.animator().alphaValue = 1.0
                }
            } else {
                existing.makeKeyAndOrderFront(nil)
            }
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 500),
            styleMask: [.titled, .fullSizeContentView, .closable],
            backing: .buffered,
            defer: false
        )
        newWindow.alphaValue = 0.0

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
        newWindow.isReleasedWhenClosed = false

        // Blur background
        let blurView = NSVisualEffectView()
        self.blurView = blurView
        
        blurView.material = appState.selectedPanelAppearance.material
        newWindow.appearance = appState.selectedPanelAppearance.nsAppearance
        
        blurView.blendingMode = .behindWindow
        blurView.state = .active

        let hostingView = NSHostingView(rootView: HistoryView())
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
        newWindow.delegate = HistoryWindowDelegate.shared

        self.window = newWindow

        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.25
            newWindow.animator().alphaValue = 1.0
        }
    }

    func updateAppearance(_ appearance: PanelAppearance) {
        window?.appearance = appearance.nsAppearance
        blurView?.material = appearance.material
    }

    func closeWindow() {
        guard let win = window else { return }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.2
            win.animator().alphaValue = 0.0
        }, completionHandler: {
            win.close()
        })
    }

    func windowClosed() {
        window = nil
        blurView = nil
        currentAppState = nil
    }
}

@MainActor
private class HistoryWindowDelegate: NSObject, NSWindowDelegate, @unchecked Sendable {
    static let shared = HistoryWindowDelegate()

    func windowWillClose(_ notification: Notification) {
        HistoryWindowManager.shared.windowClosed()
    }
}
