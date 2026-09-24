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
            if existingWindow.frame.height < 645 {
                var f = existingWindow.frame
                let diff = 645 - f.height
                f.origin.y -= diff
                f.size.height = 645
                existingWindow.setFrame(f, display: true)
            }
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            resizeWindow(to: tab.preferredWidth, animate: true)
            return
        }

        let initialWidth: CGFloat = tab.preferredWidth
        let initialHeight: CGFloat = 645

        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: initialWidth, height: initialHeight),
            styleMask: [.titled, .fullSizeContentView, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        newWindow.isRestorable = false
        newWindow.titlebarAppearsTransparent = true
        newWindow.titleVisibility = .hidden
        newWindow.standardWindowButton(.closeButton)?.isHidden = true
        newWindow.standardWindowButton(.miniaturizeButton)?.isHidden = true
        newWindow.standardWindowButton(.zoomButton)?.isHidden = true
        newWindow.minSize = NSSize(width: 700, height: 600)
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
    private var previewUpdateWorkItem: DispatchWorkItem? = nil

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
        previewUpdateWorkItem?.cancel()
        if animate {
            window.setFrame(frame, display: true, animate: true)
            let item = DispatchWorkItem { [weak self] in
                self?.isProgrammaticResize = false
                if self?.currentAppState?.isFloatingPreviewActive == true {
                    self?.currentAppState?.updateSettingsPreviewPanel(isDragging: false, createIfNeeded: false)
                }
            }
            previewUpdateWorkItem = item
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.28, execute: item)
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
        window.minSize = NSSize(width: 700, height: 600)
        window.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        
        if window.frame.height < 645 {
            var f = window.frame
            let diff = 645 - f.height
            f.origin.y -= diff
            f.size.height = 645
            window.setFrame(f, display: true)
        }
        
        let targetWidth = max(tab.preferredWidth, userExpandedWidth ?? 0)
        resizeWindow(to: targetWidth, animate: animate)
    }

    func ensureMinimumY(_ minY: CGFloat) {
        // Intentionally no-op: do not push or constrain the window during drag
    }
    
    func animateToSize(_ size: CGSize) {
        guard let window = window else { return }
        let currentFrame = window.frame
        let newX = currentFrame.midX - (size.width / 2)
        let newY = currentFrame.maxY - size.height // Anchor top edge
        let newFrame = NSRect(x: newX, y: newY, width: size.width, height: size.height)
        
        isProgrammaticResize = true
        previewUpdateWorkItem?.cancel()
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().setFrame(newFrame, display: true)
        }, completionHandler: { [weak self] in
            self?.isProgrammaticResize = false
            if self?.currentAppState?.isFloatingPreviewActive == true {
                self?.currentAppState?.updateSettingsPreviewPanel(isDragging: false, createIfNeeded: false)
            }
        })
    }

    func makeKeyIfNeeded() {
        window?.makeKeyAndOrderFront(nil)
    }

    func windowDidMove() {
        currentAppState?.moveSettingsPreviewPanelWithWindow()
    }

    func windowWillStartLiveResize() {
    }

    func windowDidResize() {
        guard !isProgrammaticResize, let window = window else { return }
        if window.inLiveResize {
            let currentW = window.frame.width
            if currentW > 860 {
                userExpandedWidth = currentW
            } else {
                userExpandedWidth = nil
            }
        }
    }

    func closeWindow() {
        previewUpdateWorkItem?.cancel()
        previewUpdateWorkItem = nil
        currentAppState?.hideSettingsPreviewPanel()
        userExpandedWidth = nil
        isProgrammaticResize = false
        window?.close()
        window = nil
        blurView = nil
    }

    func windowClosed() {
        previewUpdateWorkItem?.cancel()
        previewUpdateWorkItem = nil
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
