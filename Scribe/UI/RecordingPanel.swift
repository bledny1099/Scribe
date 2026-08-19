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
        hasAIMode: Bool = false,
        isStatusMessage: Bool = false,
        statusTextLength: Int = 0
    ) -> NSSize {
        if isStatusMessage {
            let textWidth = CGFloat(max(statusTextLength, 6)) * 8.5
            let width = min(max(32 + 16 + textWidth + 36, 160), 320)
            return NSSize(width: width, height: 56)
        }

        // Base width: Left dot (44) + Waveform visualizer (220) + Timer/Stop/Status (86) + paddings (30) = 380 pt
        var width: CGFloat = 380
        
        if !targetAppName.isEmpty {
            // Target app badge width:
            // icon (13) + spacing (5) + padding (16) = 34 pt
            // Font is system 11 weight semi-bold rounded. Average character width ~7.0 pt.
            let textWidth = CGFloat(targetAppName.count) * 7.0
            let badgeWidth = max(min(34 + textWidth, 200), 50)
            width += badgeWidth + 8 // badge width + spacing
        }
        
        if hasAIMode {
            width += 85 // AI refinement mode badge
        }
        
        return NSSize(width: min(max(width, 380), 660), height: 72)
    }

    static func size(
        for style: OverlayStyle,
        overlaySize: OverlaySize = .s100,
        isEmbeddedPreviewActive: Bool = false,
        previewTextLength: Int = 0,
        targetAppName: String = "",
        hasAIMode: Bool = false,
        isStatusMessage: Bool = false,
        statusTextLength: Int = 0
    ) -> NSSize {
        var base: NSSize
        switch style {
        case .classic:  base = classicSize
        case .waveform: base = dynamicWaveformSize(
            targetAppName: targetAppName,
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

    /// Convenience factory that selects the right size and appearance.
    static func make(
        style: OverlayStyle = .waveform,
        appearance: PanelAppearance = .dark,
        size overlaySize: OverlaySize = .s100,
        isEmbeddedPreviewActive: Bool = false,
        previewTextLength: Int = 0,
        targetAppName: String = "",
        hasAIMode: Bool = false
    ) -> RecordingPanel {
        let size: NSSize = Self.size(
            for: style,
            overlaySize: overlaySize,
            isEmbeddedPreviewActive: isEmbeddedPreviewActive,
            previewTextLength: previewTextLength,
            targetAppName: targetAppName,
            hasAIMode: hasAIMode
        )
        let radius: CGFloat = Self.radius(
            for: style, 
            overlaySize: overlaySize,
            isEmbeddedPreviewActive: isEmbeddedPreviewActive,
            previewTextLength: previewTextLength,
            targetAppName: targetAppName,
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
        hasAIMode: Bool = false
    ) {
        containerView.subviews.filter { $0 != blurView }.forEach { $0.removeFromSuperview() }

        let baseSize: NSSize = Self.size(
            for: style,
            overlaySize: .s100,
            isEmbeddedPreviewActive: isEmbeddedPreviewActive,
            previewTextLength: previewTextLength,
            targetAppName: targetAppName,
            hasAIMode: hasAIMode
        )
        let targetSize: NSSize = Self.size(
            for: style,
            overlaySize: overlaySize,
            isEmbeddedPreviewActive: isEmbeddedPreviewActive,
            previewTextLength: previewTextLength,
            targetAppName: targetAppName,
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
