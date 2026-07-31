import AVFoundation
import Accelerate
import Combine
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

    /// In-memory buffer of recorded samples for live preview.
    @Published private(set) var recordedSamples: [Float] = []

    /// Current recording file URL (nil if not recording).
    var currentRecordingURL: URL? { recordingURL }

    /// Subject used to bridge audio thread → main thread without actor isolation.
    private let audioLevelSubject = PassthroughSubject<Float, Never>()
    private var levelCancellable: AnyCancellable?

    // MARK: - Init

    init() {
        // Subscribe to level updates, throttle and deliver on main thread
        levelCancellable = audioLevelSubject
            .receive(on: DispatchQueue.main)
            .assign(to: \.audioLevel, on: self)
    }

    // MARK: - Public API

    /// Starts recording and returns the URL of the output WAV file.
    @discardableResult
    func startRecording() throws -> URL {
        recordedSamples.removeAll()

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("scribe_\(UUID().uuidString).wav")

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        currentFormat = recordingFormat

        logger.info("Mic format: \(recordingFormat.sampleRate) Hz, \(recordingFormat.channelCount) ch")

        // Create output file with the recording format
        let file = try AVAudioFile(forWriting: url, settings: recordingFormat.settings)
        audioFile = file

        // Capture subject locally to avoid accessing self from audio thread
        let subject = audioLevelSubject

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            // Write to file on the audio thread
            do {
                try file.write(from: buffer)
            } catch {
                logger.error("Failed to write audio buffer: \(error.localizedDescription)")
            }

            // Save samples in memory for live preview
            if let floatData = buffer.floatChannelData?[0] {
                let frameLength = Int(buffer.frameLength)
                let samples = Array(UnsafeBufferPointer(start: floatData, count: frameLength))
                Task { @MainActor in
                    self?.recordedSamples.append(contentsOf: samples)
                }
            }

            // Compute RMS level and send to subject (no actor isolation needed)
            let level = AudioRecorder.computeLevel(buffer)
            subject.send(level)
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
        audioFile = nil
        isRecording = false
        audioLevel = 0
        logger.info("Recording stopped")
        return recordingURL
    }

    /// Creates a valid WAV file from the currently recorded samples.
    @MainActor
    func createSnapshot() -> URL? {
        guard !recordedSamples.isEmpty, let format = currentFormat else { return nil }
        
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("scribe_snapshot_\(UUID().uuidString).wav")
            
        guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(recordedSamples.count)) else {
            return nil
        }
        
        pcmBuffer.frameLength = pcmBuffer.frameCapacity
        if let floatData = pcmBuffer.floatChannelData?[0] {
            recordedSamples.withUnsafeBufferPointer { ptr in
                floatData.assign(from: ptr.baseAddress!, count: recordedSamples.count)
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

        // Convert to dB, then normalize to 0…1 (silence at –50 dB → 0).
        let db = 20 * log10(max(rms, 1e-6))
        return max(0, min(1, (db + 50) / 50))
    }
}
