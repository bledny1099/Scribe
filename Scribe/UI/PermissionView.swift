import AppKit
import SwiftUI

// MARK: - Reusable Permissions Card (Matching Liquid Glass Design)

struct PermissionsCard: View {
    @ObservedObject var permissionManager = PermissionManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("PERMISSIONS")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
                .padding(.bottom, 8)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                // Microphone row
                PermissionRow(
                    title: "Microphone",
                    icon: "mic.fill",
                    isGranted: permissionManager.isMicrophoneGranted,
                    action: { permissionManager.requestMicrophone() }
                )

                Divider()
                    .padding(.horizontal, 16)

                // Accessibility row
                PermissionRow(
                    title: "Accessibility",
                    icon: "hand.raised.fill",
                    isGranted: permissionManager.isAccessibilityGranted,
                    action: { permissionManager.requestAccessibility() }
                )
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.primary.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
            )
        }
    }
}

struct PermissionRow: View {
    let title: String
    let icon: String
    let isGranted: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(isGranted
                        ? Color.green.opacity(0.15)
                        : Color.primary.opacity(0.06)
                    )
                    .frame(width: 32, height: 32)

                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isGranted ? .green : .secondary)
            }

            Text(title)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.primary)

            Spacer()

            if isGranted {
                HStack(spacing: 5) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.green)

                    Text("Granted")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .transition(.scale.combined(with: .opacity))
            } else {
                Button("Grant Access") {
                    action()
                }
                .buttonStyle(GlassButtonStyle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isGranted)
    }
}

// MARK: - Onboarding Permission Window Content

struct PermissionWelcomeView: View {
    @ObservedObject var permissionManager = PermissionManager.shared
    @State private var showingSupportModal = false
    var onComplete: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 24)

            // Header
            HStack {
                Text("Welcome")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 16)

            // Scrollable Content
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    // App Introduction Section
                    GlassSection(title: "About Scribe", icon: "waveform") {
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.blue, Color.purple],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 52, height: 52)

                                Image(systemName: "waveform")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                            .shadow(color: .blue.opacity(0.3), radius: 10, y: 4)

                            Text("Scribe converts your speech to text and automatically pastes it into your active app via ⌘V.")
                                .font(.system(size: 13, weight: .regular))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity)
                    }

                    // Permissions Section
                    GlassSection(title: "Required Permissions", icon: "lock.shield") {
                        VStack(spacing: 0) {
                            PermissionRow(
                                title: "Microphone",
                                icon: "mic.fill",
                                isGranted: permissionManager.isMicrophoneGranted,
                                action: { permissionManager.requestMicrophone() }
                            )

                            Divider()
                                .padding(.horizontal, 16)

                            PermissionRow(
                                title: "Accessibility",
                                icon: "hand.raised.fill",
                                isGranted: permissionManager.isAccessibilityGranted,
                                action: { permissionManager.requestAccessibility() }
                            )
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.primary.opacity(0.03))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
                        )
                    }

                    // Support Developer Button
                    Button(action: {
                        showingSupportModal = true
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "heart.fill")
                                .foregroundStyle(.pink)
                            Text("Support Scribe ☕️")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(.primary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.ultraThinMaterial)
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.primary.opacity(0.04))
                            }
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Color.primary.opacity(0.15), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .sheet(isPresented: $showingSupportModal) {
                        SupportDeveloperModal()
                    }

                    // Get Started Button
                    let allGranted = permissionManager.isMicrophoneGranted && permissionManager.isAccessibilityGranted
                    Button(action: {
                        if let onComplete = onComplete {
                            onComplete()
                        } else {
                            PermissionWindowManager.shared.closeWindow()
                        }
                    }) {
                        HStack(spacing: 8) {
                            Text(allGranted ? "Get Started" : "Continue")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))

                            if allGranted {
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 12, weight: .bold))
                            }
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(
                                        LinearGradient(
                                            colors: allGranted
                                                ? [Color.blue, Color.purple]
                                                : [Color.primary.opacity(0.15), Color.primary.opacity(0.2)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )

                                if allGranted {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    Color.white.opacity(0.25),
                                                    Color.clear,
                                                ],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )
                                }
                            }
                        )
                        .shadow(
                            color: allGranted ? .blue.opacity(0.3) : .clear,
                            radius: 8, y: 4
                        )
                    }
                    .buttonStyle(.plain)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: allGranted)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .ignoresSafeArea(.container, edges: .top)
        .frame(width: 400, height: 550)
        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
        .onAppear {
            // Force a fresh permission check when the view appears
            permissionManager.checkPermissions()
        }
    }
}

// MARK: - Permission Window Manager

@MainActor
final class PermissionWindowManager {
    static let shared = PermissionWindowManager()

    private var window: NSWindow?
    private var appState: AppState?

    func showWindow(appState: AppState? = nil) {
        if let appState = appState {
            self.appState = appState
        }

        if let existing = window {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 550),
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
        newWindow.isReleasedWhenClosed = false
        newWindow.center()

        // Blur background — same as Settings window
        let blurView = NSVisualEffectView()
        blurView.material = .popover
        blurView.blendingMode = .behindWindow
        blurView.state = .active

        let welcomeView = PermissionWelcomeView(onComplete: { [weak self] in
            guard let self = self else { return }
            let state = self.appState
            self.closeWindow()
            if let state = state {
                SettingsWindowManager.shared.showSettings(appState: state)
            }
        })

        let hostingView = NSHostingView(rootView: welcomeView)
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

        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.window = newWindow
    }

    func closeWindow() {
        window?.close()
        window = nil
    }
}
