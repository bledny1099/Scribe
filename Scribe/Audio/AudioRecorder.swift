import AVFoundation
import Accelerate
import Combine
import CoreAudio
import AudioToolbox
import os.log

private let logger = Logger(subsystem: "com.aleksei.scribe", category: "AudioRecorder")

/// Records microphone audio to a WAV file and publishes real-time RMS levels.
final class AudioRecorder: ObservableObject, @unchecked Sendable {

    // MARK: - Published State

    /// Normalized audio level in 0…1 range (updated ~44 times/sec).
    /// Updated from the audio thread via `audioLevelSubject`.
    @Published var audioLevel: Float = 0

    /// Whether the recorder is actively capturing audio.
    @Published var isRecording = false

    // MARK: - Private

    private let audioEngine = AVAudioEngine()
    private var audioFile: AVAudioFile?
    private var recordingURL: URL?
    private var currentFormat: AVAudioFormat?
    
    /// Optional callback to receive live audio buffers (useful for real-time speech recognition).
    var onBufferTap: ((AVAudioPCMBuffer) -> Void)?

    /// In-memory buffer of recorded samples for live preview.
    private var recordedSamples: [Float] = []
    private let samplesLock = NSLock()

    /// Current recording file URL (nil if not recording).
    var currentRecordingURL: URL? { recordingURL }

    /// Subject used to bridge audio thread → main thread without actor isolation.
    private let audioLevelSubject = PassthroughSubject<Float, Never>()
    private var levelCancellable: AnyCancellable?

    private let audioProcessingQueue = DispatchQueue(label: "com.aleksei.scribe.audioProcessing", qos: .userInteractive)

    // MARK: - Init

    init() {
        setupThrottling()
    }
    
    /// Sets up the throttling to a smooth 30 FPS with negligible CPU impact
    func setupThrottling() {
        let interval = 1.0 / 30.0
        
        levelCancellable = audioLevelSubject
            .throttle(for: .seconds(interval), scheduler: DispatchQueue.main, latest: true)
            .assign(to: \.audioLevel, on: self)
    }

    // MARK: - Public API

    /// Starts recording and returns the URL of the output WAV file.
    @discardableResult
    func startRecording() throws -> URL {
        samplesLock.lock()
        recordedSamples.removeAll()
        samplesLock.unlock()

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("scribe_\(UUID().uuidString).wav")

        let inputNode = audioEngine.inputNode
        
        // Route audio input to user-selected hardware microphone
        let selectedUID = UserDefaults.standard.string(forKey: "selectedAudioInputDeviceUID") ?? AudioDeviceManager.systemDefaultUID
        if let targetDeviceID = AudioDeviceManager.findDeviceID(byUID: selectedUID),
           let audioUnit = inputNode.audioUnit {
            var deviceID = targetDeviceID
            let status = AudioUnitSetProperty(
                audioUnit,
                kAudioOutputUnitProperty_CurrentDevice,
                kAudioUnitScope_Global,
                0,
                &deviceID,
                UInt32(MemoryLayout<AudioDeviceID>.size)
            )
            if status == noErr {
                logger.info("Configured audio input device ID: \(deviceID)")
            } else {
                logger.warning("Failed to configure audio input device ID \(deviceID), status: \(status)")
            }
        }

        let recordingFormat = inputNode.outputFormat(forBus: 0)
        currentFormat = recordingFormat

        logger.info("Mic format: \(recordingFormat.sampleRate) Hz, \(recordingFormat.channelCount) ch")

        // Create output file with the recording format
        let file = try AVAudioFile(forWriting: url, settings: recordingFormat.settings)
        audioFile = file

        // Capture subject locally to avoid accessing self from audio thread
        let subject = audioLevelSubject
        let queue = audioProcessingQueue

        inputNode.installTap(onBus: 0, bufferSize: 2048, format: recordingFormat) { [weak self] buffer, _ in
            // Compute RMS level and send to subject on audio thread (non-blocking)
            let level = AudioRecorder.computeLevel(buffer)
            subject.send(level)

            // Clone buffer data to safely process asynchronously off the real-time audio thread
            guard let copy = AudioRecorder.copyPCMBuffer(buffer) else { return }

            queue.async { [weak self] in
                guard let self = self else { return }
                
                // Write to file on background processing queue
                do {
                    try file.write(from: copy)
                } catch {
                    logger.error("Failed to write audio buffer: \(error.localizedDescription)")
                }

                // Save samples in memory for live preview
                if let floatData = copy.floatChannelData?[0] {
                    let frameLength = Int(copy.frameLength)
                    let samples = Array(UnsafeBufferPointer(start: floatData, count: frameLength))
                    self.samplesLock.lock()
                    self.recordedSamples.append(contentsOf: samples)
                    self.samplesLock.unlock()
                }

                // Stream buffer to live speech recognizer
                self.onBufferTap?(copy)
            }
        }

        audioEngine.prepare()
        try audioEngine.start()

        recordingURL = url
        isRecording = true
        logger.info("Recording started to \(url.lastPathComponent)")
        return url
    }

    /// Stops the current recording and returns the recorded file URL.
    func stopRecording() -> URL? {
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        
        // Drain pending audio write blocks
        audioProcessingQueue.sync {
            self.audioFile = nil
        }
        
        isRecording = false
        audioLevel = 0
        logger.info("Recording stopped")
        return recordingURL
    }

    /// Copies an AVAudioPCMBuffer safely
    public static func copyPCMBuffer(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        guard let copy = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: buffer.frameCapacity) else {
            return nil
        }
        copy.frameLength = buffer.frameLength
        if let srcData = buffer.floatChannelData, let dstData = copy.floatChannelData {
            let channelCount = Int(buffer.format.channelCount)
            let frameLength = Int(buffer.frameLength)
            for ch in 0..<channelCount {
                dstData[ch].update(from: srcData[ch], count: frameLength)
            }
        }
        return copy
    }

    /// Securely wipes memory buffers containing recorded audio samples.
    func purgeMemory() {
        samplesLock.lock()
        if !recordedSamples.isEmpty {
            recordedSamples.withUnsafeMutableBufferPointer { ptr in
                if let base = ptr.baseAddress {
                    base.initialize(repeating: 0, count: ptr.count)
                }
            }
            recordedSamples.removeAll(keepingCapacity: false)
        }
        samplesLock.unlock()
    }

    /// Creates a valid WAV file from the currently recorded samples.
    func createSnapshot() -> URL? {
        samplesLock.lock()
        let samplesCopy = recordedSamples
        let format = currentFormat
        samplesLock.unlock()

        guard !samplesCopy.isEmpty, let format = format else { return nil }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("scribe_snapshot_\(UUID().uuidString).wav")
            
        guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samplesCopy.count)) else {
            return nil
        }
        
        pcmBuffer.frameLength = pcmBuffer.frameCapacity
        if let floatData = pcmBuffer.floatChannelData?[0] {
            samplesCopy.withUnsafeBufferPointer { ptr in
                floatData.assign(from: ptr.baseAddress!, count: samplesCopy.count)
            }
        }
        
        do {
            let file = try AVAudioFile(forWriting: url, settings: format.settings)
            try file.write(from: pcmBuffer)
            return url
        } catch {
            logger.error("Failed to write snapshot: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - RMS Metering (vDSP)

    /// Static so it can be called from a non-isolated closure without capturing self.
    private static func computeLevel(_ buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData,
              buffer.frameLength > 0 else { return 0 }

        var rms: Float = 0
        vDSP_rmsqv(channelData[0], 1, &rms, vDSP_Length(buffer.frameLength))

        // Convert to dB with wider sensitivity for quiet speech and distant microphones
        // Silence floor at -54 dB, normal speech around -35 to -14 dB, peaks at -6 dB
        let db = 20 * log10(max(rms, 1e-5))
        let minDb: Float = -52.0
        let maxDb: Float = -6.0
        let normalized = max(0, min(1, (db - minDb) / (maxDb - minDb)))

        // Adaptive expansion curve (power 0.62) to make quiet/distant speech visually lively without clipping
        return pow(normalized, 0.62)
    }
}
