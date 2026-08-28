import Foundation
import FirebaseCore
import FirebaseFirestore
import os.log

private let logger = Logger(subsystem: "com.aleksei.scribe", category: "TelemetryService")

/// Anonymous installation and usage telemetry service for tracking active users in Firebase Firestore.
public final class TelemetryService: @unchecked Sendable {
    public static let shared = TelemetryService()

    private let db: Firestore?
    private let installationKey = "scribe_anonymous_installation_id"
    private let hasReportedInstallKey = "scribe_has_reported_install"

    private init() {
        if FirebaseApp.app() == nil {
            if let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
               let options = FirebaseOptions(contentsOfFile: path) {
                FirebaseApp.configure(options: options)
            } else {
                FirebaseApp.configure()
            }
        }
        self.db = FirebaseApp.app() != nil ? Firestore.firestore() : nil
    }

    /// Unique anonymous device UUID
    public var installationId: String {
        if let existing = UserDefaults.standard.string(forKey: installationKey) {
            return existing
        }
        let newId = UUID().uuidString
        UserDefaults.standard.set(newId, forKey: installationKey)
        return newId
    }

    /// Records initial installation and active session ping to Firestore
    public func recordAppLaunch() {
        guard let db = db else {
            logger.warning("Firestore is unavailable, skipping telemetry ping")
            return
        }

        let id = installationId
        let isFirstInstall = !UserDefaults.standard.bool(forKey: hasReportedInstallKey)
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "2.5.0"
        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        let chip = getChipName()
        let locale = Locale.current.identifier

        var data: [String: Any] = [
            "installationId": id,
            "version": version,
            "os": osVersion,
            "chip": chip,
            "locale": locale,
            "lastSeenAt": FieldValue.serverTimestamp(),
            "launchCount": FieldValue.increment(Int64(1))
        ]

        if isFirstInstall {
            data["installedAt"] = FieldValue.serverTimestamp()
        }

        db.collection("installations").document(id).setData(data, merge: true) { error in
            if let error = error {
                logger.warning("Telemetry ping failed: \(error.localizedDescription)")
            } else {
                logger.info("Telemetry ping successful (id: \(id), first: \(isFirstInstall))")
                if isFirstInstall {
                    UserDefaults.standard.set(true, forKey: self.hasReportedInstallKey)
                }
            }
        }
    }

    private func getChipName() -> String {
        var size = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
        if size > 0 {
            var name = [CChar](repeating: 0, count: size)
            sysctlbyname("machdep.cpu.brand_string", &name, &size, nil, 0)
            let brand = String(cString: name)
            if !brand.isEmpty { return brand }
        }
        return "Apple Silicon"
    }
}
