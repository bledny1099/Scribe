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

    // Instantaneous lock-free live audio level for 60/120 FPS visualizers
    // 32-bit float loads/stores are hardware-atomic on ARM64, eliminating locks and priority inversions on the CoreAudio thread
    private var _liveAudioLevel: Float = 0

    var liveAudioLevel: Float {
        get { _liveAudioLevel }
        set { _liveAudioLevel = newValue }
    }

    private let audioProcessingQueue = DispatchQueue(label: "com.aleksei.scribe.audioProcessing", qos: .userInteractive)
 
    // MARK: - Init
 
    init() {
        setupThrottling()
    }
    
    /// Throttles standard @Published audioLevel updates to 60 Hz for legacy scaleEffect views, keeping main thread free
    func setupThrottling() {
        let interval = 1.0 / 60.0
        
        levelCancellable = audioLevelSubject
            .throttle(for: .seconds(interval), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] level in
                self?.audioLevel = level
            }
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
            guard let self = self, self.isRecording else {
                return
            }
            // Fast vDSP level calculation on real-time thread (lock-free, zero heap allocations)
            let level = AudioRecorder.computeLevel(buffer)
            self._liveAudioLevel = level
 
            // Clone buffer data to safely process asynchronously off the real-time audio thread
            guard let copy = AudioRecorder.copyPCMBuffer(buffer) else { return }
 
            queue.async { [weak self] in
                guard let self = self else { return }
                
                // Dispatch Combine update from background processing queue, never from real-time IO thread
                subject.send(level)
 
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

        isRecording = true
        audioEngine.prepare()
        try audioEngine.start()

        recordingURL = url
        logger.info("Recording started to \(url.lastPathComponent)")
        return url
    }

    /// Stops the current recording and returns the recorded file URL.
    func stopRecording() -> URL? {
        isRecording = false
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        
        // Drain pending audio write blocks
        audioProcessingQueue.sync {
            self.audioFile = nil
        }
        
        audioLevel = 0
        audioLevelSubject.send(0)
        _liveAudioLevel = 0
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

    /// Computes instantaneous audio level (0...1) from PCM buffer using Accelerate vDSP.
    /// Pure function: lock-free, zero-allocation, safe to run directly on real-time CoreAudio threads.
    /// Evaluates all channels (mono/stereo/USB interfaces) to ensure mic signal is never missed.
    public static func computeLevel(_ buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData,
              buffer.frameLength > 0 else { return 0 }

        let frameCount = vDSP_Length(buffer.frameLength)
        var maxRMS: Float = 0
        let channelCount = Int(buffer.format.channelCount)

        for ch in 0..<min(channelCount, 2) {
            var rms: Float = 0
            vDSP_rmsqv(channelData[ch], 1, &rms, frameCount)
            if rms > maxRMS { maxRMS = rms }
        }

        // Convert to dBFS with broad dynamic sensitivity
        // Ambient room noise is below -54 dBFS, conversational speech is -40 to -14 dBFS
        let db = 20 * log10(max(maxRMS, 1e-5))
        let minDb: Float = -54.0
        let maxDb: Float = -6.0
        let normalized = max(0, min(1, (db - minDb) / (maxDb - minDb)))

        // Gentle power curve gives responsive visual animation without clipping
        return pow(normalized, 0.60)
    }
}
