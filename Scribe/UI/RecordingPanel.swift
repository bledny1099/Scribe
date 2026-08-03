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
    static let waveformSize = NSSize(width: 480, height: 72)
    static let minimalSize  = NSSize(width: 140, height: 44)
    static let ecgSize      = NSSize(width: 260, height: 64)
    static let orbSize      = NSSize(width: 200, height: 200)

    static func size(
        for style: OverlayStyle,
        overlaySize: OverlaySize = .s100,
        isEmbeddedPreviewActive: Bool = false,
        previewTextLength: Int = 0
    ) -> NSSize {
        var base: NSSize
        switch style {
        case .classic:  base = classicSize
        case .waveform: base = waveformSize
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

    static func radius(for style: OverlayStyle, overlaySize: OverlaySize = .s100, isEmbeddedPreviewActive: Bool = false) -> CGFloat {
        let baseRadius: CGFloat
        switch style {
        case .classic:  baseRadius = 24
        case .waveform: baseRadius = (isEmbeddedPreviewActive && style.supportsEmbeddedPreview) ? 28 : waveformSize.height / 2
        case .minimal:  baseRadius = minimalSize.height / 2
        case .ecg:      baseRadius = (isEmbeddedPreviewActive && style.supportsEmbeddedPreview) ? 24 : 16
        case .orb:      baseRadius = 28
        }
        return round(baseRadius * overlaySize.scale)
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
        previewTextLength: Int = 0
    ) -> RecordingPanel {
        let size: NSSize = Self.size(
            for: style,
            overlaySize: overlaySize,
            isEmbeddedPreviewActive: isEmbeddedPreviewActive,
            previewTextLength: previewTextLength
        )
        let radius: CGFloat = Self.radius(for: style, overlaySize: overlaySize)

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
    }

    // MARK: - Corner Masking (Prevents Grey Square Artifacts)

    /// Masks blurView and all layers with a pixel-perfect rounded mask image.
    func updateCornerRadius(_ radius: CGFloat) {
        self.cornerRadiusValue = radius
        let size = frame.size
        guard size.width > 0 && size.height > 0 else { return }

        // Create an exact NSImage mask matching the rounded shape
        let maskImage = NSImage(size: size, flipped: false) { rect in
            let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
            NSColor.black.set()
            path.fill()
            return true
        }

        blurView.maskImage = maskImage

        blurView.wantsLayer = true
        blurView.layer?.cornerRadius = radius
        blurView.layer?.masksToBounds = true

        if let content = contentView {
            content.wantsLayer = true
            content.layer?.cornerRadius = radius
            content.layer?.masksToBounds = true
        }
    }

    // MARK: - Content

    /// Embeds a SwiftUI view inside the blur background.
    func setContent<Content: View>(
        _ view: Content,
        style: OverlayStyle = .waveform,
        overlaySize: OverlaySize = .s100,
        isEmbeddedPreviewActive: Bool = false,
        previewTextLength: Int = 0
    ) {
        containerView.subviews.filter { $0 != blurView }.forEach { $0.removeFromSuperview() }

        let baseSize: NSSize = Self.size(for: style, overlaySize: .s100, isEmbeddedPreviewActive: isEmbeddedPreviewActive, previewTextLength: previewTextLength)
        let targetSize: NSSize = Self.size(for: style, overlaySize: overlaySize, isEmbeddedPreviewActive: isEmbeddedPreviewActive, previewTextLength: previewTextLength)
        let scale = overlaySize.scale

        blurView.isHidden = false

        let wrappedView = view
            .frame(width: baseSize.width, height: baseSize.height)
            .scaleEffect(scale)
            .frame(width: targetSize.width, height: targetSize.height)
            .background(Color.clear)

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

        let targetRadius = Self.radius(for: style, overlaySize: overlaySize, isEmbeddedPreviewActive: isEmbeddedPreviewActive)
        updateCornerRadius(targetRadius)
        invalidateShadow()
    }

    /// Positions the panel near the bottom-center of the main screen.
    func positionAtBottom() {
        guard let screen = NSScreen.main else { center(); return }
        let screenFrame = screen.visibleFrame
        let x = screenFrame.midX - frame.width / 2
        let y = screenFrame.minY + 60
        setFrameOrigin(NSPoint(x: x, y: y))
    }

    /// Positions the panel near the bottom-right of the main screen.
    func positionAtBottomRight() {
        guard let screen = NSScreen.main else { center(); return }
        let screenFrame = screen.visibleFrame
        let x = screenFrame.maxX - frame.width - 60
        let y = screenFrame.minY + 60
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
        isMovableByWindowBackground = true
        hidesOnDeactivate         = false
        isOpaque                  = false
        backgroundColor           = .clear
        hasShadow                 = false // Prevents rectangular window shadow artifacts
        animationBehavior         = .utilityWindow
        collectionBehavior        = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
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
