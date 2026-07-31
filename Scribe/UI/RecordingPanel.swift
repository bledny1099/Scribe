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

    static func size(for style: OverlayStyle) -> NSSize {
        switch style {
        case .classic:  return classicSize
        case .waveform: return waveformSize
        case .minimal:  return minimalSize
        case .ecg:      return ecgSize
        }
    }

    static func radius(for style: OverlayStyle) -> CGFloat {
        switch style {
        case .classic:  return 24
        case .waveform: return waveformSize.height / 2
        case .minimal:  return minimalSize.height / 2
        case .ecg:      return 16
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
    static func make(style: OverlayStyle = .waveform, appearance: PanelAppearance = .dark) -> RecordingPanel {
        let size: NSSize = Self.size(for: style)
        let radius: CGFloat = Self.radius(for: style)

        let panel = RecordingPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.appearance = appearance.nsAppearance
        panel.blurView.material = appearance.material
        panel.blurView.isHidden = false
        panel.updateCornerRadius(radius)

        return panel
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
    func setContent<Content: View>(_ view: Content, style: OverlayStyle = .waveform) {
        containerView.subviews.filter { $0 != blurView }.forEach { $0.removeFromSuperview() }

        let size: NSSize = Self.size(for: style)
        let radius: CGFloat = Self.radius(for: style)
        blurView.isHidden = false

        let wrappedView = view
            .frame(width: size.width, height: size.height)
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

        updateCornerRadius(radius)
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
