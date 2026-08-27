import Foundation
import CoreAudio
import AudioToolbox
import Combine
import SwiftUI
import os.log

private let logger = Logger(subsystem: "com.aleksei.scribe", category: "AudioDeviceManager")

/// Represents an audio input device on macOS (Built-in mic, USB microphone, AirPods, audio interface, etc.)
public struct AudioInputDevice: Identifiable, Hashable, Sendable {
    public let id: AudioDeviceID
    public let uid: String
    public let name: String
    public let isDefault: Bool
    public let transportType: AudioDeviceTransportType

    public enum AudioDeviceTransportType: Sendable {
        case builtIn
        case usb
        case bluetooth
        case aggregate
        case virtual
        case other

        public var iconName: String {
            switch self {
            case .builtIn:   return "laptopcomputer"
            case .usb:       return "cable.connector"
            case .bluetooth: return "airpodspro"
            case .aggregate: return "square.stack.3d.up.fill"
            case .virtual:   return "waveform.badge.mic"
            case .other:     return "mic.fill"
            }
        }
    }
}

/// Central manager for discovering, selecting, and reacting to audio input hardware changes.
@MainActor
public final class AudioDeviceManager: ObservableObject {
    public static let shared = AudioDeviceManager()

    public static let systemDefaultUID = "system_default"

    @AppStorage("selectedAudioInputDeviceUID") public var selectedDeviceUID: String = AudioDeviceManager.systemDefaultUID

    @Published public var availableDevices: [AudioInputDevice] = []
    @Published public var defaultDevice: AudioInputDevice?

    private var devicesPropertyListener: AudioObjectPropertyListenerBlock?
    private init() {
        refreshDevices()
        setupHardwareListeners()
    }

    // MARK: - Device Discovery & Resolution

    /// Re-enumerates all active audio input devices on the system.
    public func refreshDevices() {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        let sizeStatus = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize
        )
        guard sizeStatus == noErr else {
            logger.error("Failed to query audio devices data size")
            return
        }

        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)

        let dataStatus = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &deviceIDs
        )
        guard dataStatus == noErr else {
            logger.error("Failed to read audio device IDs")
            return
        }

        // Get current default input device
        var defaultInputAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var defaultInputDeviceID: AudioDeviceID = 0
        var defaultSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        _ = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &defaultInputAddress,
            0,
            nil,
            &defaultSize,
            &defaultInputDeviceID
        )

        var detectedDevices: [AudioInputDevice] = []

        for id in deviceIDs {
            // Check if device supports input channels
            var streamAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreamConfiguration,
                mScope: kAudioDevicePropertyScopeInput,
                mElement: kAudioObjectPropertyElementMain
            )

            var streamSize: UInt32 = 0
            guard AudioObjectGetPropertyDataSize(id, &streamAddress, 0, nil, &streamSize) == noErr && streamSize > 0 else {
                continue
            }

            let bufferListPointer = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: Int(streamSize))
            defer { bufferListPointer.deallocate() }

            guard AudioObjectGetPropertyData(id, &streamAddress, 0, nil, &streamSize, bufferListPointer) == noErr else {
                continue
            }

            let buffers = UnsafeMutableAudioBufferListPointer(bufferListPointer)
            let channelCount = buffers.reduce(0) { $0 + Int($1.mNumberChannels) }
            guard channelCount > 0 else { continue }

            // Device Name
            let name = Self.getCFStringProperty(id: id, selector: kAudioObjectPropertyName) ?? "Unknown Microphone"

            // Device UID
            let uid = Self.getCFStringProperty(id: id, selector: kAudioDevicePropertyDeviceUID) ?? "\(id)"

            // Transport Type
            var transportAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyTransportType,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            var transportVal: UInt32 = 0
            var transportSize = UInt32(MemoryLayout<UInt32>.size)
            var transportType: AudioInputDevice.AudioDeviceTransportType = .other

            if AudioObjectGetPropertyData(id, &transportAddress, 0, nil, &transportSize, &transportVal) == noErr {
                switch transportVal {
                case kAudioDeviceTransportTypeBuiltIn:
                    transportType = .builtIn
                case kAudioDeviceTransportTypeUSB:
                    transportType = .usb
                case kAudioDeviceTransportTypeBluetooth, kAudioDeviceTransportTypeBluetoothLE:
                    transportType = .bluetooth
                case kAudioDeviceTransportTypeAggregate:
                    transportType = .aggregate
                case kAudioDeviceTransportTypeVirtual:
                    transportType = .virtual
                default:
                    transportType = .other
                }
            }

            let isDef = (id == defaultInputDeviceID)
            let device = AudioInputDevice(
                id: id,
                uid: uid,
                name: name,
                isDefault: isDef,
                transportType: transportType
            )
            detectedDevices.append(device)
        }

        self.availableDevices = detectedDevices
        self.defaultDevice = detectedDevices.first(where: { $0.isDefault }) ?? detectedDevices.first
        logger.info("Discovered \(detectedDevices.count) audio input devices. Selected UID: '\(self.selectedDeviceUID)'")
    }

    /// Resolves the actual AudioDeviceID to use for recording.
    /// If user chose "system_default" or the chosen device is disconnected, returns nil (allowing system default).
    public func resolveCurrentDeviceID() -> AudioDeviceID? {
        if selectedDeviceUID == Self.systemDefaultUID {
            return nil
        }
        if let matched = availableDevices.first(where: { $0.uid == selectedDeviceUID }) {
            return matched.id
        }
        // Fallback to nil (default)
        return nil
    }

    /// Returns the currently active device (either selected device or default device).
    public var activeDevice: AudioInputDevice? {
        if selectedDeviceUID != Self.systemDefaultUID,
           let matched = availableDevices.first(where: { $0.uid == selectedDeviceUID }) {
            return matched
        }
        return defaultDevice
    }

    /// Returns formatted display name of the currently selected microphone.
    public var activeDisplayName: String {
        if selectedDeviceUID == Self.systemDefaultUID {
            if let def = defaultDevice {
                return "\(def.name)"
            }
            return "System Default"
        }
        if let matched = availableDevices.first(where: { $0.uid == selectedDeviceUID }) {
            return matched.name
        }
        return "System Default"
    }

    // MARK: - Hardware Listeners

    private func setupHardwareListeners() {
        var devicesAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let devicesBlock: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            Task { @MainActor [weak self] in
                self?.refreshDevices()
            }
        }
        self.devicesPropertyListener = devicesBlock
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &devicesAddress,
            DispatchQueue.main,
            devicesBlock
        )

        var defaultAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let defaultBlock: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            Task { @MainActor [weak self] in
                self?.refreshDevices()
            }
        }
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &defaultAddress,
            DispatchQueue.main,
            defaultBlock
        )
    }

    // MARK: - Helper

    private static func getCFStringProperty(id: AudioDeviceID, selector: AudioObjectPropertySelector) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var unmanagedString: Unmanaged<CFString>?
        var dataSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        let status = AudioObjectGetPropertyData(id, &address, 0, nil, &dataSize, &unmanagedString)
        if status == noErr, let unmanaged = unmanagedString {
            return unmanaged.takeRetainedValue() as String
        }
        return nil
    }
}
