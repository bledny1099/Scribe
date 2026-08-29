import AVFoundation
import AppKit
import Combine
import os.log
import Speech

private let logger = Logger(subsystem: "com.aleksei.scribe", category: "PermissionManager")

/// Manages and polls system permission states (Microphone, Accessibility).
@MainActor
final class PermissionManager: ObservableObject {
    static let shared = PermissionManager()

    @Published var isMicrophoneGranted: Bool = false
    @Published var isAccessibilityGranted: Bool = false
    @Published var isSpeechRecognitionGranted: Bool = false

    private var timer: Timer?
    private var activeObserver: NSObjectProtocol?

    init() {
        checkPermissions()
        if !isMicrophoneGranted || !isAccessibilityGranted || !isSpeechRecognitionGranted {
            startPolling()
        }
        activeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.checkPermissions()
        }
    }

    func checkPermissions() {
        // Microphone status
        let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        let mic = (micStatus == .authorized)
        if isMicrophoneGranted != mic {
            isMicrophoneGranted = mic
        }

        // Accessibility status
        let ax = PasteService.isAccessibilityGranted()
        if isAccessibilityGranted != ax {
            isAccessibilityGranted = ax
        }

        // Speech Recognition status
        let speechStatus = SFSpeechRecognizer.authorizationStatus()
        let speech = (speechStatus == .authorized)
        if isSpeechRecognitionGranted != speech {
            isSpeechRecognitionGranted = speech
        }

        // When all permissions are granted, stop background polling to save CPU
        if isMicrophoneGranted && isAccessibilityGranted && isSpeechRecognitionGranted {
            stopPolling()
        }
    }

    func startPolling() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkPermissions()
            }
        }
    }

    func stopPolling() {
        timer?.invalidate()
        timer = nil
    }

    func requestMicrophone() {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        if status == .denied || status == .restricted {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
                NSWorkspace.shared.open(url)
            }
        } else {
            AVCaptureDevice.requestAccess(for: .audio) { @Sendable granted in
                Task { @MainActor in
                    PermissionManager.shared.isMicrophoneGranted = granted
                    PermissionManager.shared.checkPermissions()
                }
            }
        }
    }

    func requestAccessibility() {
        PasteService.requestAccessibilityPermission()
        checkPermissions()
    }

    func requestSpeechRecognition() {
        SFSpeechRecognizer.requestAuthorization { @Sendable status in
            Task { @MainActor in
                PermissionManager.shared.isSpeechRecognitionGranted = (status == .authorized)
                PermissionManager.shared.checkPermissions()
            }
        }
    }
}
