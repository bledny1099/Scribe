import ServiceManagement
import os.log

private let logger = Logger(subsystem: "com.aleksei.scribe", category: "LaunchAtLogin")

/// Helper for managing the app's Launch at Login state via SMAppService.
enum LaunchAtLoginHelper {

    /// Whether the app is currently registered to launch at login.
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Enable or disable launch at login.
    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
                logger.info("Registered for launch at login")
            } else {
                try SMAppService.mainApp.unregister()
                logger.info("Unregistered from launch at login")
            }
        } catch {
            logger.error("Launch at login failed: \(error.localizedDescription)")
        }
    }
}
