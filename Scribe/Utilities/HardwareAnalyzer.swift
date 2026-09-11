import Foundation
import SwiftUI

// MARK: - Model Hardware Advice
public enum ModelHardwareAdvice: Equatable {
    case optimal(messageKey: String)
    case caution(messageKey: String)
    case warning(messageKey: String)

    public var isWarning: Bool {
        if case .warning = self { return true }
        return false
    }

    public var isCaution: Bool {
        if case .caution = self { return true }
        return false
    }

    public var message: String {
        switch self {
        case .optimal(let msg), .caution(let msg), .warning(let msg):
            return msg
        }
    }
}

// MARK: - Hardware Profile
public struct HardwareProfile: Sendable {
    public let chipName: String          // e.g. "Apple M5 Pro", "Apple M1"
    public let ramGB: Int                // e.g. 24, 8, 16
    public let hardwareModel: String     // e.g. "Mac17,9"
    public let isAppleSilicon: Bool
    public let isHighEnd: Bool           // >= 16 GB RAM or Pro/Max/Ultra
    public let isLowMemory: Bool         // <= 8 GB RAM

    public var summary: String {
        "\(chipName) • \(ramGB) GB Unified Memory"
    }

    public var badgeTitle: String {
        if isHighEnd {
            return "Optimal Powerhouse"
        } else if isLowMemory {
            return "8 GB • Limited Memory"
        } else {
            return "Balanced System"
        }
    }

    public var badgeColor: Color {
        if isHighEnd {
            return .purple
        } else if isLowMemory {
            return .orange
        } else {
            return .blue
        }
    }

    public func advice(for modelId: String) -> ModelHardwareAdvice {
        switch modelId {
        case "openai_whisper-large-v3":
            if isLowMemory {
                return .warning(
                    messageKey: "Studio model requires ~2.5–3 GB of unified memory during active dictation. On this Mac with 8 GB RAM, it may cause memory pressure and system lag."
                )
            } else if ramGB < 16 {
                return .caution(
                    messageKey: "Studio model operates best on 16 GB+ RAM. Close heavy background apps for uninterrupted performance."
                )
            } else {
                return .optimal(
                    messageKey: "Chill. Your Mac is fully supported."
                )
            }

        case "openai_whisper-large-v3_turbo":
            if isLowMemory {
                return .caution(
                    messageKey: "Turbo model uses ~950 MB. Fast on Apple Silicon, but monitor memory if running multiple heavy applications."
                )
            } else {
                return .optimal(
                    messageKey: "Chill. Your Mac is fully supported."
                )
            }

        case "openai_whisper-small":
            return .optimal(
                messageKey: "Chill. Your Mac is fully supported."
            )

        default:
            return .optimal(messageKey: "Chill. Your Mac is fully supported.")
        }
    }

    public func shortAdvice(for modelId: String) -> String {
        switch modelId {
        case "openai_whisper-large-v3":
            if isLowMemory {
                return "Your Mac might struggle with this model (needs ~2.5–3 GB RAM)."
            } else if ramGB < 16 {
                return "Needs ~2.5–3 GB RAM. Works best with 16 GB+."
            } else {
                return "Chill. Your Mac is powerful enough for this model, it will handle it easily."
            }

        case "openai_whisper-large-v3_turbo":
            if isLowMemory {
                return "Uses ~950 MB RAM. Monitor memory if multitasking."
            } else {
                return "Chill. Your Mac is powerful enough for this model, it will handle it easily."
            }

        case "openai_whisper-small":
            return "Chill. Lightweight model, your Mac will handle it easily."

        default:
            return "Chill. Your Mac is powerful enough for this model, it will handle it easily."
        }
    }

    public func detailMessage(for modelId: String) -> String {
        switch modelId {
        case "openai_whisper-large-v3":
            return "\(chipName) (\(ramGB) GB) has ample unified memory and compute power for uncompressed Studio inference."
        case "openai_whisper-large-v3_turbo":
            return "Ultra-fast neural latency with a compact ~950 MB footprint on \(chipName)."
        case "openai_whisper-small":
            return "Minimal footprint (~460 MB) for battery saving and everyday speech."
        default:
            return "Runs smoothly on your system."
        }
    }
}

// MARK: - Hardware Analyzer
public final class HardwareAnalyzer: @unchecked Sendable {
    public static let shared = HardwareAnalyzer()

    public let profile: HardwareProfile

    private init() {
        // 1. CPU Brand String (e.g. "Apple M5 Pro")
        var cpuSize = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &cpuSize, nil, 0)
        var chip = ""
        if cpuSize > 0 {
            var cpuChars = [CChar](repeating: 0, count: cpuSize)
            sysctlbyname("machdep.cpu.brand_string", &cpuChars, &cpuSize, nil, 0)
            chip = String(cString: cpuChars).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if chip.isEmpty {
            #if arch(arm64)
            chip = "Apple Silicon"
            #else
            chip = "Intel Core"
            #endif
        }

        // 2. Physical RAM in GB
        let ramBytes = ProcessInfo.processInfo.physicalMemory
        let ramGB = max(1, Int(round(Double(ramBytes) / (1024.0 * 1024.0 * 1024.0))))

        // 3. Machine model identifier (e.g. "Mac17,9")
        var modelSize = 0
        sysctlbyname("hw.model", nil, &modelSize, nil, 0)
        var model = ""
        if modelSize > 0 {
            var modelChars = [CChar](repeating: 0, count: modelSize)
            sysctlbyname("hw.model", &modelChars, &modelSize, nil, 0)
            model = String(cString: modelChars).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let isAppleSilicon: Bool
        #if arch(arm64)
        isAppleSilicon = true
        #else
        isAppleSilicon = false
        #endif

        let isHighEnd = ramGB >= 16 || chip.contains("Pro") || chip.contains("Max") || chip.contains("Ultra")
        let isLowMemory = ramGB <= 8

        self.profile = HardwareProfile(
            chipName: chip,
            ramGB: ramGB,
            hardwareModel: model,
            isAppleSilicon: isAppleSilicon,
            isHighEnd: isHighEnd,
            isLowMemory: isLowMemory
        )
    }
}

// MARK: - Device Manager

import IOKit
import OpenDirectory

/// Manages unique hardware device identification and naming for cross-device cloud sync.
public final class DeviceManager: Sendable {
    public static let shared = DeviceManager()

    private let persistentUUIDKey = "scribe_persistent_device_hardware_uuid"

    private init() {}

    /// Unique Apple Account identifier (Apple IDMS identifier, e.g. "com.apple.idms.appleid.prd...")
    /// extracted from macOS Directory Services. Identical on all Macs logged into the same Apple ID.
    public var appleAccountId: String? {
        do {
            let session = ODSession.default()
            let node = try ODNode(session: session, type: ODNodeType(kODNodeTypeLocalNodes))
            let userName = NSUserName()
            let record = try node.record(
                withRecordType: kODRecordTypeUsers,
                name: userName,
                attributes: [kODAttributeTypeAltSecurityIdentities, kODAttributeTypeRecordName]
            )
            if let altIdentities = try? record.values(forAttribute: kODAttributeTypeAltSecurityIdentities) as? [String] {
                for identity in altIdentities {
                    if let range = identity.range(of: "com.apple.idms.appleid.prd.[A-Za-z0-9-]+", options: .regularExpression) {
                        return String(identity[range])
                    }
                }
            }
            if let recNames = try? record.values(forAttribute: kODAttributeTypeRecordName) as? [String] {
                for name in recNames {
                    if name.hasPrefix("com.apple.idms.appleid.prd.") {
                        return name
                    }
                }
            }
        } catch {
            print("[DeviceManager] OpenDirectory Apple ID query error: \(error)")
        }
        return nil
    }

    /// Whether this Mac is currently bound to an Apple Account / iCloud.
    public var isAppleAccountBound: Bool {
        appleAccountId != nil
    }

    /// Unique and permanent hardware UUID for this Mac.
    public var deviceUUID: String {
        let matchingDict = IOServiceMatching("IOPlatformExpertDevice")
        let platformExpert = IOServiceGetMatchingService(kIOMainPortDefault, matchingDict)
        defer {
            if platformExpert != 0 {
                IOObjectRelease(platformExpert)
            }
        }

        if platformExpert != 0 {
            if let uuidAsCFString = IORegistryEntryCreateCFProperty(
                platformExpert,
                kIOPlatformUUIDKey as CFString,
                kCFAllocatorDefault,
                0
            )?.takeRetainedValue() as? String, !uuidAsCFString.isEmpty {
                return uuidAsCFString
            }
        }

        // Fallback: persistent UUID stored in UserDefaults
        if let saved = UserDefaults.standard.string(forKey: persistentUUIDKey), !saved.isEmpty {
            return saved
        }
        let generated = UUID().uuidString
        UserDefaults.standard.set(generated, forKey: persistentUUIDKey)
        return generated
    }

    /// User-friendly Mac name, e.g. "MacBook Pro" or "Aleksei's MacBook Air"
    public var deviceName: String {
        if let hostName = Host.current().localizedName, !hostName.isEmpty {
            return hostName
        }
        return "Mac"
    }
}

