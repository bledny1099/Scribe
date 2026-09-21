import AppKit
import SwiftUI

/// Manages a custom, borderless transparent window for the Settings screen.
@MainActor
final class SettingsWindowManager {
    static let shared = SettingsWindowManager()

    var window: NSWindow?
    private var blurView: NSVisualEffectView?
    private weak var currentAppState: AppState?

    private init() {}

    func showSettings(appState: AppState, tab: SettingsTab = .general) {
        self.currentAppState = appState
        appState.requestedSettingsTab = tab
        if let existingWindow = window {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            resizeWindow(to: tab.preferredWidth, animate: true)
            return
        }

        let initialWidth: CGFloat = tab.preferredWidth
        let initialHeight: CGFloat = 530

        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: initialWidth, height: initialHeight),
            styleMask: [.titled, .fullSizeContentView, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        newWindow.titlebarAppearsTransparent = true
        newWindow.titleVisibility = .hidden
        newWindow.standardWindowButton(.closeButton)?.isHidden = true
        newWindow.standardWindowButton(.miniaturizeButton)?.isHidden = true
        newWindow.standardWindowButton(.zoomButton)?.isHidden = true
        newWindow.minSize = NSSize(width: 780, height: 490)
        newWindow.showsResizeIndicator = true

        newWindow.isMovableByWindowBackground = false
        newWindow.isOpaque = false
        newWindow.backgroundColor = .clear 
        newWindow.hasShadow = true
        newWindow.level = .normal
        newWindow.hidesOnDeactivate = false

        let blurView = NSVisualEffectView()
        self.blurView = blurView
        
        if let appState = self.currentAppState {
            newWindow.appearance = appState.selectedPanelAppearance.nsAppearance
            blurView.material = appState.selectedPanelAppearance.material
        } else {
            blurView.material = .popover
        }
        
        blurView.blendingMode = .behindWindow
        blurView.state = .active
        // Removed custom layer corner radius to let the native window handle it perfectly without artifacts


        // Wrap the SwiftUI view
        let settingsView = SettingsView().environmentObject(appState)
        let hostingView = NSHostingView(rootView: settingsView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        hostingView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        hostingView.setContentHuggingPriority(.defaultLow, for: .vertical)
        hostingView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        hostingView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)

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

    func updateAppearance(_ appearance: PanelAppearance) {
        window?.appearance = appearance.nsAppearance
        blurView?.material = appearance.material
        blurView?.wantsLayer = true
        blurView?.layer?.backgroundColor = appearance.backgroundColor.cgColor
    }

    var windowFrame: NSRect? {
        window?.frame
    }

    var userExpandedWidth: CGFloat? = nil
    private var isProgrammaticResize: Bool = false

    func resizeWindow(to width: CGFloat, animate: Bool = true) {
        guard let window = window else { return }
        var frame = window.frame
        let diff = width - frame.size.width
        if abs(diff) < 2 { return }

        frame.size.width = width
        frame.origin.x -= diff / 2 // Keep it centered

        if let screen = window.screen ?? NSScreen.main {
            let visible = screen.visibleFrame
            if frame.maxX > visible.maxX - 16 {
                frame.origin.x = visible.maxX - frame.size.width - 16
            }
            if frame.minX < visible.minX + 16 {
                frame.origin.x = visible.minX + 16
            }
        }

        isProgrammaticResize = true
        if animate {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.28
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                window.animator().setFrame(frame, display: true)
            } completionHandler: { [weak self] in
                self?.isProgrammaticResize = false
            }
        } else {
            window.setFrame(frame, display: true)
            isProgrammaticResize = false
        }
    }

    func setTabConstraints(for tab: SettingsTab, animate: Bool = true) {
        guard let window = window else { return }
        
        if !window.styleMask.contains(.resizable) {
            window.styleMask.insert(.resizable)
        }
        window.showsResizeIndicator = true
        window.minSize = NSSize(width: 780, height: 490)
        window.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        
        let targetWidth: CGFloat
        if let expandedWidth = userExpandedWidth {
            targetWidth = max(expandedWidth, tab.preferredWidth)
        } else {
            targetWidth = tab.preferredWidth
        }
        
        resizeWindow(to: targetWidth, animate: animate)
    }

    func ensureMinimumY(_ minY: CGFloat) {
        guard let window = window else { return }
        let currentFrame = window.frame
        if currentFrame.minY < minY {
            guard let screen = window.screen ?? NSScreen.main else { return }
            let maxY = screen.visibleFrame.maxY - currentFrame.height - 20
            let newY = min(minY, maxY)
            if abs(currentFrame.minY - newY) > 2 {
                let newFrame = NSRect(x: currentFrame.origin.x, y: newY, width: currentFrame.width, height: currentFrame.height)
                window.setFrame(newFrame, display: true)
            }
        }
    }
    
    func animateToSize(_ size: CGSize) {
        guard let window = window else { return }
        let currentFrame = window.frame
        let newX = currentFrame.midX - (size.width / 2)
        let newY = currentFrame.maxY - size.height // Anchor top edge
        let newFrame = NSRect(x: newX, y: newY, width: size.width, height: size.height)
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.35
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().setFrame(newFrame, display: true)
        }
    }

    func makeKeyIfNeeded() {
        window?.makeKeyAndOrderFront(nil)
    }

    func windowDidMove() {
        currentAppState?.updateSettingsPreviewPanel(isDragging: true)
    }

    func windowDidResize() {
        currentAppState?.updateSettingsPreviewPanel(isDragging: true)
        guard !isProgrammaticResize, let window = window else { return }
        let currentW = window.frame.width
        if currentW > 835 {
            userExpandedWidth = currentW
        } else {
            userExpandedWidth = nil
        }
    }

    func closeWindow() {
        currentAppState?.hideSettingsPreviewPanel()
        userExpandedWidth = nil
        isProgrammaticResize = false
        window?.close()
        window = nil
        blurView = nil
    }

    func windowClosed() {
        currentAppState?.hideSettingsPreviewPanel()
        userExpandedWidth = nil
        isProgrammaticResize = false
        window = nil
        blurView = nil
        currentAppState = nil
    }
}

@MainActor
private class WindowDelegate: NSObject, NSWindowDelegate, @unchecked Sendable {
    static let shared = WindowDelegate()

    func windowWillClose(_ notification: Notification) {
        SettingsWindowManager.shared.windowClosed()
    }
    
    func windowDidMove(_ notification: Notification) {
        SettingsWindowManager.shared.windowDidMove()
    }

    func windowDidResize(_ notification: Notification) {
        SettingsWindowManager.shared.windowDidResize()
    }
}
