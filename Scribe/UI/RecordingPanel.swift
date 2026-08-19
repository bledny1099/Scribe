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
            let width = min(max(32 + 16 + textWidth + 36, 160), 320)
            return NSSize(width: width, height: 56)
        }

        // Base width: Left dot cap (44) + Waveform visualizer (220) + Stop button cap (44) = 308 pt
        var width: CGFloat = 308
        
        if isTimerVisible {
            width += 48 // Timer digits + spacing
        }
        
        if !targetAppName.isEmpty {
            let textWidth = CGFloat(targetAppName.count) * 7.0
            let badgeWidth = max(min(34 + textWidth, 200), 50)
            width += badgeWidth + 10 // badge width + spacing
        }
        
        if hasAIMode {
            width += 85 // AI refinement mode badge
        }
        
        return NSSize(width: min(max(width, 308), 680), height: 72)
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
        case .ecg:      base = ecgSize
        case .orb:      base = orbSize
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
        self.appearance = appearance.nsAppearance
        blurView.material = appearance.material
        blurView.wantsLayer = true
        blurView.layer?.backgroundColor = appearance.backgroundColor.cgColor
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
    public static func getActiveWindowFrame() -> NSRect? {
        let scribeBundleID = Bundle.main.bundleIdentifier ?? "com.alexey.scribe"
        let scribePID = ProcessInfo.processInfo.processIdentifier

        // 1. Try frontmost application if it's not Scribe
        if let frontApp = NSWorkspace.shared.frontmostApplication,
           frontApp.processIdentifier != scribePID,
           frontApp.bundleIdentifier != scribeBundleID {
            let pid = frontApp.processIdentifier
            let appElement = AXUIElementCreateApplication(pid)
            var focusedWindow: AnyObject?
            if AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedWindow) == .success,
               let win = focusedWindow as! AXUIElement? {
                var positionVal: AnyObject?
                var sizeVal: AnyObject?
                if AXUIElementCopyAttributeValue(win, kAXPositionAttribute as CFString, &positionVal) == .success,
                   AXUIElementCopyAttributeValue(win, kAXSizeAttribute as CFString, &sizeVal) == .success,
                   let posValue = positionVal as! AXValue?,
                   let sizeValue = sizeVal as! AXValue? {
                    var point = CGPoint.zero
                    var size = CGSize.zero
                    AXValueGetValue(posValue, .cgPoint, &point)
                    AXValueGetValue(sizeValue, .cgSize, &size)
                    if size.width > 80 && size.height > 80, let primary = NSScreen.screens.first {
                        let cocoaY = primary.frame.height - (point.y + size.height)
                        return NSRect(x: point.x, y: cocoaY, width: size.width, height: size.height)
                    }
                }
            }
        }

        // 2. Query CGWindowList for the topmost user application window (excluding Scribe and system shells)
        if let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] {
            for window in windowList {
                guard let winPID = window[kCGWindowOwnerPID as String] as? pid_t,
                      winPID != scribePID,
                      let layer = window[kCGWindowLayer as String] as? Int, layer == 0,
                      let boundsDict = window[kCGWindowBounds as String] as? [String: CGFloat],
                      let w = boundsDict["Width"], let h = boundsDict["Height"], w > 150 && h > 150 else {
                    continue
                }
                let ownerName = window[kCGWindowOwnerName as String] as? String ?? ""
                if ownerName == "Scribe" || ownerName == "Window Server" || ownerName == "Dock" || ownerName == "Control Center" || ownerName == "Notification Center" {
                    continue
                }
                let x = boundsDict["X"] ?? 0
                let y = boundsDict["Y"] ?? 0
                if let primary = NSScreen.screens.first {
                    let cocoaY = primary.frame.height - (y + h)
                    return NSRect(x: x, y: cocoaY, width: w, height: h)
                }
            }
        }

        return nil
    }

    /// Positions the panel based on the selected positioning mode.
    func positionPanel(mode: OverlayPositionMode, yOffset: CGFloat = 0) {
        guard let screen = NSScreen.main else { center(); return }
        let screenFrame = screen.visibleFrame

        switch mode {
        case .screenBottom:
            let x = screenFrame.midX - frame.width / 2
            let y = screenFrame.minY + 160 + yOffset
            setFrameOrigin(NSPoint(x: x, y: y))

        case .activeWindow:
            if let windowFrame = Self.getActiveWindowFrame() {
                // If the active window is full screen / maximized (occupies almost the full screen), position at screen bottom
                let isNearlyFullScreen = windowFrame.width >= (screenFrame.width - 60) && windowFrame.height >= (screenFrame.height - 60)
                if isNearlyFullScreen {
                    let x = screenFrame.midX - frame.width / 2
                    let y = screenFrame.minY + 160 + yOffset
                    setFrameOrigin(NSPoint(x: x, y: y))
                } else {
                    // Center horizontally at the active target window
                    var x = windowFrame.midX - frame.width / 2
                    // Place near the bottom edge of the active window
                    var y = windowFrame.minY + 32 + yOffset

                    // Keep strictly inside the screen visible bounds
                    x = max(screenFrame.minX + 16, min(x, screenFrame.maxX - frame.width - 16))
                    y = max(screenFrame.minY + 24, min(y, screenFrame.maxY - frame.height - 24))
                    setFrameOrigin(NSPoint(x: x, y: y))
                }
            } else {
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
