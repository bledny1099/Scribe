import AVFoundation
import AppKit
import Combine
import os.log

private let logger = Logger(subsystem: "com.aleksei.scribe", category: "PermissionManager")

/// Manages and polls system permission states (Microphone, Accessibility).
@MainActor
final class PermissionManager: ObservableObject {
    static let shared = PermissionManager()

    @Published var isMicrophoneGranted: Bool = false
    @Published var isAccessibilityGranted: Bool = false

    private var timer: Timer?

    init() {
        checkPermissions()
        startPolling()
    }

    func checkPermissions() {
        // Microphone status
        let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        isMicrophoneGranted = (micStatus == .authorized)

        // Accessibility status
        isAccessibilityGranted = PasteService.isAccessibilityGranted()
    }

    func startPolling() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkPermissions()
            }
        }
    }

    func requestMicrophone() {
        AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
            Task { @MainActor in
                self?.isMicrophoneGranted = granted
                self?.checkPermissions()
            }
        }
    }

    func requestAccessibility() {
        PasteService.requestAccessibilityPermission()
        checkPermissions()
    }
}
