import AppKit
import SwiftUI

/// Floating borderless panel with behind-window blur (glassmorphism).
/// Does **not** steal focus from the active application.
/// Supports two layouts: classic (square) and waveform (horizontal bar).
/// Supports dark and light background appearance.
final class RecordingPanel: NSPanel {

    private let containerView = NSView()
    private let blurView = NSVisualEffectView()

    // MARK: - Layout Constants

    static let classicSize  = NSSize(width: 220, height: 220)
    static let waveformSize = NSSize(width: 520, height: 72)
    static let minimalSize  = NSSize(width: 140, height: 44)
    static let ecgSize      = NSSize(width: 260, height: 64)
    static let orbSize      = NSSize(width: 200, height: 200)

    static func dynamicWaveformSize(
        targetAppName: String = "",
        isTimerVisible: Bool = true,
        hasAIMode: Bool = false,
        isStatusMessage: Bool = false,
        statusTextLength: Int = 0
    ) -> NSSize {
        if isStatusMessage {
            let textWidth = CGFloat(max(statusTextLength, 6)) * 8.5
            let width = min(max(32 + 16 + textWidth + 36, 160), 340)
            return NSSize(width: width, height: 56)
        }

        // Base width: Left dot cap (36) + Waveform visualizer 52 bars (290) + Stop button cap (32) + padding (38) = 406 pt
        var width: CGFloat = 406
        
        if isTimerVisible {
            width += 52 // Timer digits + margin
        }
        
        if !targetAppName.isEmpty {
            let textWidth = CGFloat(targetAppName.count) * 7.5
            let badgeWidth = max(min(38 + textWidth, 200), 54)
            width += badgeWidth + 14 // badge width + margin
        }
        
        if hasAIMode {
            width += 88 // AI refinement mode badge
        }
        
        return NSSize(width: min(max(width, 406), 760), height: 72)
    }

    static func size(
        for style: OverlayStyle,
        overlaySize: OverlaySize = .s100,
        isEmbeddedPreviewActive: Bool = false,
        previewTextLength: Int = 0,
        targetAppName: String = "",
        isTimerVisible: Bool = true,
        hasAIMode: Bool = false,
        isStatusMessage: Bool = false,
        statusTextLength: Int = 0
    ) -> NSSize {
        var base: NSSize
        switch style {
        case .classic:  base = classicSize
        case .waveform: base = dynamicWaveformSize(
            targetAppName: targetAppName,
            isTimerVisible: isTimerVisible,
            hasAIMode: hasAIMode,
            isStatusMessage: isStatusMessage,
            statusTextLength: statusTextLength
        )
        case .minimal:  base = minimalSize
        case .ecg:
            if isStatusMessage {
                let textWidth = CGFloat(max(statusTextLength, 6)) * 8.5
                let width = min(max(32 + 16 + textWidth + 36, 160), 340)
                base = NSSize(width: width, height: 56)
            } else {
                base = ecgSize
            }
        case .orb:
            if isStatusMessage {
                let textWidth = CGFloat(max(statusTextLength, 6)) * 8.5
                let width = min(max(32 + 16 + textWidth + 36, 160), 340)
                base = NSSize(width: width, height: 56)
            } else {
                base = orbSize
            }
        }

        if isEmbeddedPreviewActive && style.supportsEmbeddedPreview {
            let charsPerLine: Double
            switch style {
            case .waveform: charsPerLine = 45.0
            case .ecg:      charsPerLine = 24.0
            default:        charsPerLine = 20.0
            }
            let estimatedLines = max(1, Int(ceil(Double(previewTextLength) / charsPerLine)))
            let textHeight: CGFloat = CGFloat(estimatedLines) * 18.0
            let extraHeight: CGFloat = 20 + textHeight
            base.height += extraHeight
        }

        let scale = overlaySize.scale
        return NSSize(width: round(base.width * scale), height: round(base.height * scale))
    }

    static func radius(
        for style: OverlayStyle, 
        overlaySize: OverlaySize = .s100, 
        isEmbeddedPreviewActive: Bool = false, 
        previewTextLength: Int = 0,
        targetAppName: String = "",
        isTimerVisible: Bool = true,
        hasAIMode: Bool = false,
        isStatusMessage: Bool = false,
        statusTextLength: Int = 0
    ) -> CGFloat {
        let currentSize = self.size(
            for: style, 
            overlaySize: overlaySize, 
            isEmbeddedPreviewActive: isEmbeddedPreviewActive, 
            previewTextLength: previewTextLength,
            targetAppName: targetAppName,
            isTimerVisible: isTimerVisible,
            hasAIMode: hasAIMode,
            isStatusMessage: isStatusMessage,
            statusTextLength: statusTextLength
        )
        if isStatusMessage {
            return currentSize.height / 2
        }
        switch style {
        case .classic:  return round(24 * overlaySize.scale)
        case .ecg:      return round(24 * overlaySize.scale)
        case .orb:      return round(28 * overlaySize.scale)
        case .waveform, .minimal:
            return currentSize.height / 2
        }
    }

    private var cornerRadiusValue: CGFloat = 24

    // MARK: - Init

    override init(
        contentRect: NSRect,
        styleMask: NSWindow.StyleMask,
        backing bufferingType: NSWindow.BackingStoreType,
        defer flag: Bool
    ) {
        super.init(contentRect: contentRect, styleMask: styleMask, backing: bufferingType, defer: flag)
        configurePanel()
        configureBlur()
    }

    /// Factory method: creates and configures the panel in one shot.
    static func make(
        style: OverlayStyle = .waveform,
        appearance: PanelAppearance = .dark,
        size overlaySize: OverlaySize = .s100,
        isEmbeddedPreviewActive: Bool = false,
        previewTextLength: Int = 0,
        targetAppName: String = "",
        isTimerVisible: Bool = true,
        hasAIMode: Bool = false
    ) -> RecordingPanel {
        let size: NSSize = Self.size(
            for: style,
            overlaySize: overlaySize,
            isEmbeddedPreviewActive: isEmbeddedPreviewActive,
            previewTextLength: previewTextLength,
            targetAppName: targetAppName,
            isTimerVisible: isTimerVisible,
            hasAIMode: hasAIMode
        )
        let radius: CGFloat = Self.radius(
            for: style, 
            overlaySize: overlaySize, 
            isEmbeddedPreviewActive: isEmbeddedPreviewActive, 
            previewTextLength: previewTextLength,
            targetAppName: targetAppName,
            isTimerVisible: isTimerVisible,
            hasAIMode: hasAIMode
        )

        let panel = RecordingPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.updateAppearance(appearance)
        panel.blurView.isHidden = false
        panel.updateCornerRadius(radius)

        return panel
    }

    /// Updates background appearance and material.
    func updateAppearance(_ appearance: PanelAppearance) {
        switch appearance {
        case .dark:
            self.appearance = NSAppearance(named: .vibrantDark)
            blurView.material = .underWindowBackground
            blurView.wantsLayer = true
            blurView.layer?.backgroundColor = NSColor(white: 0.015, alpha: 0.98).cgColor
            blurView.layer?.borderWidth = 0
            blurView.layer?.borderColor = nil
        case .light:
            self.appearance = NSAppearance(named: .vibrantLight)
            blurView.material = .hudWindow
            blurView.wantsLayer = true
            blurView.layer?.backgroundColor = NSColor(white: 0.96, alpha: 0.92).cgColor
            blurView.layer?.borderWidth = 0
            blurView.layer?.borderColor = nil
        case .liquidGlass:
            self.appearance = NSAppearance(named: .vibrantDark)
            blurView.material = .hudWindow
            blurView.wantsLayer = true
            blurView.layer?.backgroundColor = NSColor(white: 0.05, alpha: 0.50).cgColor
            blurView.layer?.borderWidth = 0
            blurView.layer?.borderColor = nil
        }
    }

    // MARK: - Corner Masking (Prevents Grey Square Artifacts)

    private var cachedMaskSize: NSSize?
    private var cachedMaskRadius: CGFloat?
    private var cachedMaskImage: NSImage?

    /// Masks blurView and all layers with a pixel-perfect rounded mask image.
    func updateCornerRadius(_ radius: CGFloat, targetSize: NSSize? = nil) {
        self.cornerRadiusValue = radius
        let size = targetSize ?? frame.size
        guard size.width > 0 && size.height > 0 else { return }
        guard blurView.superview != nil else { return }

        if cachedMaskSize == size && cachedMaskRadius == radius, let img = cachedMaskImage {
            blurView.maskImage = img
        } else {
            let maskImage = NSImage(size: size)
            maskImage.lockFocus()
            let path = NSBezierPath(roundedRect: NSRect(origin: .zero, size: size), xRadius: radius, yRadius: radius)
            NSColor.black.set()
            path.fill()
            maskImage.unlockFocus()
            
            cachedMaskSize = size
            cachedMaskRadius = radius
            cachedMaskImage = maskImage
            blurView.maskImage = maskImage
        }

        blurView.wantsLayer = true
        blurView.layer?.cornerRadius = radius
        blurView.layer?.masksToBounds = true

        if let content = contentView {
            content.wantsLayer = true
            content.layer?.cornerRadius = radius
            content.layer?.masksToBounds = true
        }
    }

    override func setFrame(_ frameRect: NSRect, display displayFlag: Bool) {
        super.setFrame(frameRect, display: displayFlag)
        guard contentView != nil else { return }
        updateCornerRadius(cornerRadiusValue, targetSize: frameRect.size)
    }

    override func setFrame(_ frameRect: NSRect, display displayFlag: Bool, animate animateFlag: Bool) {
        super.setFrame(frameRect, display: displayFlag, animate: animateFlag)
        guard contentView != nil else { return }
        updateCornerRadius(cornerRadiusValue, targetSize: frameRect.size)
    }

    // MARK: - Content

    /// Embeds a SwiftUI view inside the blur background.
    func setContent<Content: View>(
        _ view: Content,
        style: OverlayStyle = .waveform,
        overlaySize: OverlaySize = .s100,
        isEmbeddedPreviewActive: Bool = false,
        previewTextLength: Int = 0,
        targetAppName: String = "",
        isTimerVisible: Bool = true,
        hasAIMode: Bool = false
    ) {
        containerView.subviews.filter { $0 != blurView }.forEach { $0.removeFromSuperview() }

        let baseSize: NSSize = Self.size(
            for: style,
            overlaySize: .s100,
            isEmbeddedPreviewActive: isEmbeddedPreviewActive,
            previewTextLength: previewTextLength,
            targetAppName: targetAppName,
            isTimerVisible: isTimerVisible,
            hasAIMode: hasAIMode
        )
        let targetSize: NSSize = Self.size(
            for: style,
            overlaySize: overlaySize,
            isEmbeddedPreviewActive: isEmbeddedPreviewActive,
            previewTextLength: previewTextLength,
            targetAppName: targetAppName,
            isTimerVisible: isTimerVisible,
            hasAIMode: hasAIMode
        )
        let scale = overlaySize.scale

        blurView.isHidden = false

        let wrappedView = AnyView(
            view
                .frame(width: baseSize.width, height: baseSize.height)
                .scaleEffect(scale)
                .frame(width: targetSize.width, height: targetSize.height)
                .background(Color.clear)
        )

        if let existingHosting = containerView.subviews.compactMap({ $0 as? NSHostingView<AnyView> }).first {
            existingHosting.rootView = wrappedView
        } else {
            containerView.subviews.filter { $0 != blurView }.forEach { $0.removeFromSuperview() }
            let hostingView = NSHostingView(rootView: wrappedView)
            hostingView.translatesAutoresizingMaskIntoConstraints = false

            hostingView.wantsLayer = true
            hostingView.layer?.backgroundColor = .clear

            containerView.addSubview(hostingView)
            NSLayoutConstraint.activate([
                hostingView.topAnchor.constraint(equalTo: containerView.topAnchor),
                hostingView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
                hostingView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                hostingView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            ])
        }

        let targetRadius = Self.radius(
            for: style, 
            overlaySize: overlaySize, 
            isEmbeddedPreviewActive: isEmbeddedPreviewActive,
            previewTextLength: previewTextLength,
            targetAppName: targetAppName,
            hasAIMode: hasAIMode
        )
        updateCornerRadius(targetRadius, targetSize: targetSize)
        invalidateShadow()
    }

    /// Retrieves the bounds of the currently active frontmost window (in Cocoa bottom-left coordinates).
    /// Retrieves the bounds of the currently active frontmost window (in Cocoa bottom-left coordinates).
    public static func getActiveWindowFrame(targetApp: NSRunningApplication? = nil) -> NSRect? {
        let scribeBundleID = Bundle.main.bundleIdentifier ?? "com.aleksei.scribe"
        let scribePID = ProcessInfo.processInfo.processIdentifier
        guard let primaryScreen = NSScreen.screens.first else { return nil }
        let primaryHeight = primaryScreen.frame.height

        // Determine target application: prefer targetApp if provided and not Scribe, else frontmost non-Scribe app
        let app: NSRunningApplication?
        if let target = targetApp, target.processIdentifier != scribePID && target.bundleIdentifier != scribeBundleID {
            app = target
        } else if let front = NSWorkspace.shared.frontmostApplication, front.processIdentifier != scribePID && front.bundleIdentifier != scribeBundleID {
            app = front
        } else {
            app = NSWorkspace.shared.runningApplications.first(where: { $0.isActive && $0.processIdentifier != scribePID && $0.bundleIdentifier != scribeBundleID })
        }

        guard let frontApp = app else { return nil }
        let pid = frontApp.processIdentifier

        // Helper to extract bounds from AXUIElement
        func getAXBounds(element: AXUIElement) -> NSRect? {
            var posVal: AnyObject?
            var sizeVal: AnyObject?
            if AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &posVal) == .success,
               AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeVal) == .success,
               let pVal = posVal as! AXValue?,
               let sVal = sizeVal as! AXValue? {
                var point = CGPoint.zero
                var size = CGSize.zero
                AXValueGetValue(pVal, .cgPoint, &point)
                AXValueGetValue(sVal, .cgSize, &size)
                if size.width >= 240 && size.height >= 160 {
                    let cocoaY = primaryHeight - (point.y + size.height)
                    return NSRect(x: point.x, y: cocoaY, width: size.width, height: size.height)
                }
            }
            return nil
        }

        // 1. Check Accessibility API on frontmost app
        let appElement = AXUIElementCreateApplication(pid)

        // Try MainWindow first (best representation of the primary app window)
        var mainWinObj: AnyObject?
        if AXUIElementCopyAttributeValue(appElement, kAXMainWindowAttribute as CFString, &mainWinObj) == .success,
           let win = mainWinObj as! AXUIElement? {
            if let frame = getAXBounds(element: win) {
                return frame
            }
        }

        // Try FocusedWindow next
        var focusedWinObj: AnyObject?
        if AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedWinObj) == .success,
           let win = focusedWinObj as! AXUIElement? {
            var roleObj: AnyObject?
            _ = AXUIElementCopyAttributeValue(win, kAXRoleAttribute as CFString, &roleObj)
            let role = roleObj as? String ?? ""

            if role == (kAXWindowRole as String) {
                if let frame = getAXBounds(element: win) {
                    return frame
                }
            } else {
                // If focused element is a child group or sidebar, query its parent window
                var parentWinObj: AnyObject?
                if AXUIElementCopyAttributeValue(win, kAXWindowAttribute as CFString, &parentWinObj) == .success,
                   let pWin = parentWinObj as! AXUIElement? {
                    if let frame = getAXBounds(element: pWin) {
                        return frame
                    }
                }
            }
        }

        // 2. Query CGWindowList: list is pre-sorted in Z-order (top-to-bottom).
        // The first layer-0 window matching the application PID is the active focused window.
        if let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] {
            for window in windowList {
                guard let winPID = window[kCGWindowOwnerPID as String] as? pid_t,
                      winPID == pid,
                      let layer = window[kCGWindowLayer as String] as? Int, layer == 0,
                      let boundsDict = window[kCGWindowBounds as String] as? [String: CGFloat],
                      let w = boundsDict["Width"], let h = boundsDict["Height"],
                      w >= 240 && h >= 160 else {
                    continue
                }

                if let alpha = window[kCGWindowAlpha as String] as? CGFloat, alpha < 0.2 {
                    continue
                }

                let x = boundsDict["X"] ?? 0
                let y = boundsDict["Y"] ?? 0
                let cocoaY = primaryHeight - (y + h)
                return NSRect(x: x, y: cocoaY, width: w, height: h)
            }

            // Fallback: check other application windows on layer 0
            for window in windowList {
                guard let winPID = window[kCGWindowOwnerPID as String] as? pid_t,
                      winPID != scribePID,
                      let layer = window[kCGWindowLayer as String] as? Int, layer == 0,
                      let boundsDict = window[kCGWindowBounds as String] as? [String: CGFloat],
                      let w = boundsDict["Width"], let h = boundsDict["Height"],
                      w >= 360 && h >= 220 else {
                    continue
                }
                let ownerName = window[kCGWindowOwnerName as String] as? String ?? ""
                if ownerName == "Scribe" || ownerName == "Window Server" || ownerName == "Dock" || ownerName == "Control Center" || ownerName == "Notification Center" {
                    continue
                }
                let x = boundsDict["X"] ?? 0
                let y = boundsDict["Y"] ?? 0
                let cocoaY = primaryHeight - (y + h)
                return NSRect(x: x, y: cocoaY, width: w, height: h)
            }
        }

        return nil
    }

    /// Positions the panel based on the selected positioning mode.
    func positionPanel(mode: OverlayPositionMode, targetApp: NSRunningApplication? = nil, yOffset: CGFloat = 0) {
        switch mode {
        case .screenBottom:
            guard let screen = NSScreen.main ?? NSScreen.screens.first else { center(); return }
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - frame.width / 2
            let y = screenFrame.minY + 160 + yOffset
            setFrameOrigin(NSPoint(x: x, y: y))

        case .activeWindow:
            if let windowFrame = Self.getActiveWindowFrame(targetApp: targetApp) {
                // Find the screen containing the active window
                let windowCenter = NSPoint(x: windowFrame.midX, y: windowFrame.midY)
                let targetScreen = NSScreen.screens.first(where: { $0.frame.contains(windowCenter) })
                    ?? NSScreen.screens.first(where: { $0.frame.intersects(windowFrame) })
                    ?? NSScreen.main
                    ?? NSScreen.screens.first
                let screenFrame = targetScreen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)

                // If the active window is full screen / maximized, position at screen bottom
                let isNearlyFullScreen = windowFrame.width >= (screenFrame.width - 60) && windowFrame.height >= (screenFrame.height - 60)
                let isValidWindowFrame = windowFrame.intersects(screenFrame) && windowFrame.width >= 200

                if isNearlyFullScreen || !isValidWindowFrame {
                    let x = screenFrame.midX - frame.width / 2
                    let y = screenFrame.minY + 160 + yOffset
                    setFrameOrigin(NSPoint(x: x, y: y))
                } else {
                    // Center horizontally within the active target window
                    var x = windowFrame.midX - frame.width / 2
                    // Place comfortably in lower portion of the active target window
                    var y = windowFrame.minY + 36 + yOffset

                    // Keep strictly inside the target screen visible bounds with comfortable padding
                    let minAllowedY = screenFrame.minY + 24
                    let maxAllowedY = screenFrame.maxY - frame.height - 24
                    let minAllowedX = screenFrame.minX + 24
                    let maxAllowedX = screenFrame.maxX - frame.width - 24

                    x = max(minAllowedX, min(x, maxAllowedX))
                    y = max(minAllowedY, min(y, maxAllowedY))
                    setFrameOrigin(NSPoint(x: x, y: y))
                }
            } else {
                guard let screen = NSScreen.main ?? NSScreen.screens.first else { center(); return }
                let screenFrame = screen.visibleFrame
                let x = screenFrame.midX - frame.width / 2
                let y = screenFrame.minY + 160 + yOffset
                setFrameOrigin(NSPoint(x: x, y: y))
            }
        }
    }

    /// Positions the panel near the bottom-center of the main screen.
    func positionAtBottom(yOffset: CGFloat = 0) {
        guard let screen = NSScreen.main else { center(); return }
        let screenFrame = screen.visibleFrame
        let x = screenFrame.midX - frame.width / 2
        let y = screenFrame.minY + 160 + yOffset
        setFrameOrigin(NSPoint(x: x, y: y))
    }

    /// Positions the panel near the bottom-right of the main screen.
    func positionAtBottomRight() {
        guard let screen = NSScreen.main else { center(); return }
        let screenFrame = screen.visibleFrame
        let x = screenFrame.maxX - frame.width - 60
        let y = screenFrame.minY + 160
        setFrameOrigin(NSPoint(x: x, y: y))
    }

    /// Positions the panel directly to the right of a reference window frame (e.g. Settings window).
    func positionToRight(of referenceFrame: NSRect, spacing: CGFloat = 24) {
        guard let screen = NSScreen.main else { center(); return }
        let screenFrame = screen.visibleFrame
        
        let preferredX = referenceFrame.maxX + spacing
        let maxAllowedX = screenFrame.maxX - frame.width - 20
        let x = min(preferredX, maxAllowedX)
        
        let preferredY = referenceFrame.midY - frame.height / 2
        let y = max(screenFrame.minY + 20, min(preferredY, screenFrame.maxY - frame.height - 20))
        
        setFrameOrigin(NSPoint(x: x, y: y))
    }

    // MARK: - Overrides — keep the panel passive

    override var canBecomeKey: Bool  { false }
    override var canBecomeMain: Bool { false }

    // MARK: - Private Setup

    private func configurePanel() {
        isFloatingPanel           = true
        level                     = .floating
        isMovableByWindowBackground = false
        hidesOnDeactivate         = false
        isOpaque                  = false
        backgroundColor           = .clear
        hasShadow                 = false // Prevents rectangular window shadow artifacts
        animationBehavior         = .utilityWindow
        collectionBehavior        = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        isReleasedWhenClosed      = false
    }

    private func configureBlur() {
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = .clear

        blurView.material     = .hudWindow
        blurView.blendingMode = .behindWindow
        blurView.state        = .active
        blurView.wantsLayer   = true
        blurView.layer?.cornerRadius   = cornerRadiusValue
        blurView.layer?.masksToBounds  = true

        containerView.addSubview(blurView)
        blurView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            blurView.topAnchor.constraint(equalTo: containerView.topAnchor),
            blurView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            blurView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
        ])

        contentView = containerView
    }
}
