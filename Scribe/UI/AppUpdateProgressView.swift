import SwiftUI
import AppKit

// MARK: - App Update Progress Window Manager

@MainActor
final class AppUpdateProgressWindowManager {
    static let shared = AppUpdateProgressWindowManager()

    private var window: NSWindow?
    private var blurView: NSVisualEffectView?

    private init() {}

    func showWindow(appUpdateService: AppUpdateService = .shared, appState: AppState? = nil) {
        if let existing = window {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 420),
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
        newWindow.level = .floating
        newWindow.isReleasedWhenClosed = false
        newWindow.center()

        let blur = NSVisualEffectView()
        self.blurView = blur
        let state = appState ?? AppState.shared
        if let st = state {
            newWindow.appearance = st.selectedPanelAppearance.nsAppearance
            blur.material = st.selectedPanelAppearance.material
        } else {
            blur.material = .popover
        }
        blur.blendingMode = .behindWindow
        blur.state = .active

        let rootView = AppUpdateProgressView(updateService: appUpdateService)
            .environmentObject(state ?? AppState())

        let hostingView = NSHostingView(rootView: rootView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor

        blur.addSubview(hostingView)
        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: blur.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: blur.bottomAnchor),
            hostingView.leadingAnchor.constraint(equalTo: blur.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: blur.trailingAnchor),
        ])

        newWindow.contentView = blur
        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.window = newWindow
    }

    public func closeWindow() {
        window?.close()
        window = nil
    }
}

// MARK: - App Update Progress View (Timeline)

struct AppUpdateProgressView: View {
    @ObservedObject var updateService: AppUpdateService
    @EnvironmentObject var appState: AppState

    private var currentVersion: String {
        updateService.currentVersion.isEmpty ? "2.6.4" : updateService.currentVersion
    }

    private var targetVersion: String {
        updateService.latestVersion.isEmpty ? "latest" : updateService.latestVersion
    }

    public var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)

                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(appState.l("Updating Scribe"))
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)

                    Text("v\(currentVersion) → v\(targetVersion)")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if updateService.errorMessage != nil {
                    Button(action: {
                        AppUpdateProgressWindowManager.shared.closeWindow()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)

            // Timeline Card
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(UpdateStage.allCases.enumerated()), id: \.element) { index, stage in
                    TimelineStageRow(
                        stage: stage,
                        currentStage: updateService.currentStage,
                        isLast: index == UpdateStage.allCases.count - 1,
                        downloadProgress: updateService.downloadProgress,
                        bytesDownloaded: updateService.bytesDownloaded,
                        totalBytes: updateService.totalBytes,
                        appState: appState
                    )
                }
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.primary.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .padding(.horizontal, 24)

            // Footer Status / Error
            if let error = updateService.errorMessage {
                VStack(spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        Text(error)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.red)
                            .lineLimit(2)
                    }

                    if let page = updateService.releasePageURL {
                        Button(action: {
                            NSWorkspace.shared.open(page)
                            AppUpdateProgressWindowManager.shared.closeWindow()
                        }) {
                            Text(appState.l("Open in Browser"))
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.primary.opacity(0.08))
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 24)
            } else {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 6, height: 6)
                        .opacity(0.8)

                    Text(appState.l("Please do not quit Scribe while updating."))
                        .font(.system(size: 11.5, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 16)
            }

            Spacer(minLength: 4)
        }
        .frame(width: 440, height: 420)
    }
}

// MARK: - Timeline Stage Row Component

private struct TimelineStageRow: View {
    let stage: UpdateStage
    let currentStage: UpdateStage
    let isLast: Bool
    let downloadProgress: Double
    let bytesDownloaded: Int64
    let totalBytes: Int64
    let appState: AppState

    private var isCompleted: Bool {
        stage.rawValue < currentStage.rawValue
    }

    private var isCurrent: Bool {
        stage == currentStage
    }

    private var isPending: Bool {
        stage.rawValue > currentStage.rawValue
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // Node & Connector line
            VStack(spacing: 0) {
                ZStack {
                    if isCompleted {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 22, height: 22)

                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                    } else if isCurrent {
                        Circle()
                            .fill(Color.blue.opacity(0.2))
                            .frame(width: 22, height: 22)
                            .overlay(
                                Circle()
                                    .stroke(Color.blue, lineWidth: 1.5)
                            )

                        ProgressView()
                            .controlSize(.mini)
                            .frame(width: 12, height: 12)
                    } else {
                        Circle()
                            .fill(Color.primary.opacity(0.08))
                            .frame(width: 22, height: 22)

                        Image(systemName: stage.icon)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.secondary.opacity(0.6))
                    }
                }

                if !isLast {
                    Rectangle()
                        .fill(isCompleted ? Color.green.opacity(0.6) : Color.primary.opacity(0.1))
                        .frame(width: 1.5, height: stage == .downloading && isCurrent ? 44 : 26)
                        .padding(.vertical, 2)
                }
            }
            .frame(width: 24)

            // Details
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(appState.l(stage.title))
                        .font(.system(size: 13, weight: isCurrent ? .bold : .medium, design: .rounded))
                        .foregroundStyle(isCurrent ? Color.primary : (isCompleted ? Color.primary.opacity(0.85) : Color.secondary))

                    Spacer()

                    if stage == .downloading && isCurrent && totalBytes > 0 {
                        Text("\(Int(downloadProgress * 100))%")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(.blue)
                    }
                }

                if stage == .downloading && isCurrent {
                    VStack(alignment: .leading, spacing: 4) {
                        ProgressView(value: max(0.02, min(1.0, downloadProgress)))
                            .progressViewStyle(.linear)
                            .tint(.blue)

                        if totalBytes > 0 {
                            let dlMB = Double(bytesDownloaded) / 1_048_576.0
                            let totMB = Double(totalBytes) / 1_048_576.0
                            Text(String(format: "%.1f MB / %.1f MB", dlMB, totMB))
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.top, 2)
                    .padding(.bottom, 4)
                } else {
                    Text(appState.l(stage.description))
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundStyle(.secondary.opacity(0.8))
                }
            }
            .padding(.top, 2)
        }
    }
}
