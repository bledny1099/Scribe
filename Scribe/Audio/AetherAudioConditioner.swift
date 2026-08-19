import Foundation
import AVFoundation
import Accelerate
import os.log

private let logger = Logger(subsystem: "com.aleksei.scribe", category: "AetherAudioConditioner")

/// Aether Audio Conditioner (Stage B):
/// High-pass filtering, VAD silence trimming, and loudness normalization for pristine acoustic decoding.
public final class AetherAudioConditioner: @unchecked Sendable {

    public static let shared = AetherAudioConditioner()

    private init() {}

    /// Conditions an input audio file: removes sub-80Hz rumble, strips leading/trailing silence, and normalizes peak loudness.
    /// Returns nil if the file contains no audible human speech above the noise floor.
    public func condition(audioURL: URL) -> URL? {
        do {
            let file = try AVAudioFile(forReading: audioURL)
            let format = file.processingFormat
            let frameCount = AVAudioFrameCount(file.length)

            guard frameCount > 0 else { return nil }

            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
                return audioURL
            }

            try file.read(into: buffer)
            guard let channelData = buffer.floatChannelData else { return audioURL }

            let sampleRate = Float(format.sampleRate)
            let channelCount = Int(format.channelCount)
            let samplesPerChannel = Int(buffer.frameLength)

            if samplesPerChannel < Int(sampleRate * 0.1) {
                // Audio is too short to condition (<100ms), return as is
                return audioURL
            }

            // 1. High-Pass Filter (>80 Hz) to eliminate desk rumble & keyboard thumps
            applyHighPassFilter(channelData: channelData, channelCount: channelCount, count: samplesPerChannel, sampleRate: sampleRate)

            // 2. VAD: Find speech boundaries (leading & trailing silence)
            if let (startFrame, endFrame) = detectSpeechBoundaries(
                channelData: channelData[0],
                count: samplesPerChannel,
                sampleRate: sampleRate
            ) {
                let trimmedLength = max(1, endFrame - startFrame)
                if let trimmedBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(trimmedLength)) {
                    trimmedBuffer.frameLength = AVAudioFrameCount(trimmedLength)
                    for ch in 0..<channelCount {
                        let srcPtr = channelData[ch].advanced(by: startFrame)
                        let dstPtr = trimmedBuffer.floatChannelData![ch]
                        dstPtr.assign(from: srcPtr, count: trimmedLength)
                    }
                    normalizeLoudness(buffer: trimmedBuffer)

                    let outputURL = FileManager.default.temporaryDirectory
                        .appendingPathComponent("aether_conditioned_\(UUID().uuidString).wav")
                    let outputFile = try AVAudioFile(forWriting: outputURL, settings: format.settings)
                    try outputFile.write(from: trimmedBuffer)
                    logger.debug("Aether conditioned audio: trimmed \(samplesPerChannel) -> \(trimmedLength) frames")
                    return outputURL
                }
            }

            // No audible speech detected in audio buffer: return nil to avoid Whisper hallucinations on silence
            logger.debug("Aether VAD detected no audible speech in audio buffer")
            return nil
        } catch {
            logger.warning("Aether audio conditioning failed: \(error.localizedDescription), using raw audio")
            return audioURL
        }
    }

    // MARK: - High-Pass Filter (~80 Hz 1st Order IIR)

    private func applyHighPassFilter(channelData: UnsafePointer<UnsafeMutablePointer<Float>>, channelCount: Int, count: Int, sampleRate: Float) {
        let cutoff: Float = 80.0
        let dt = 1.0 / sampleRate
        let rc = 1.0 / (2.0 * Float.pi * cutoff)
        let alpha = rc / (rc + dt)

        for ch in 0..<channelCount {
            let data = channelData[ch]
            var prevIn: Float = data[0]
            var prevOut: Float = data[0]

            for i in 1..<count {
                let currentIn = data[i]
                let currentOut = alpha * (prevOut + currentIn - prevIn)
                data[i] = currentOut
                prevIn = currentIn
                prevOut = currentOut
            }
        }
    }

    // MARK: - VAD & Speech Boundary Detection

    private func detectSpeechBoundaries(channelData: UnsafePointer<Float>, count: Int, sampleRate: Float) -> (Int, Int)? {
        let frameSize = Int(sampleRate * 0.02) // 20ms frame
        guard frameSize > 0, count > frameSize else { return (0, count) }

        let silenceThresholdDb: Float = -48.0
        let thresholdRMS = pow(10.0, silenceThresholdDb / 20.0)

        var firstSpeechFrame: Int?
        var lastSpeechFrame: Int?
        var totalSpeechFrames = 0

        let totalFrames = count / frameSize

        for f in 0..<totalFrames {
            let offset = f * frameSize
            var frameRms: Float = 0
            vDSP_rmsqv(channelData.advanced(by: offset), 1, &frameRms, vDSP_Length(frameSize))

            if frameRms > thresholdRMS {
                if firstSpeechFrame == nil {
                    firstSpeechFrame = offset
                }
                lastSpeechFrame = min(count, offset + frameSize)
                totalSpeechFrames += 1
            }
        }

        // Require at least 2 frames (~40ms) of speech for single short words (e.g. "Да", "Ок")
        guard let first = firstSpeechFrame, let last = lastSpeechFrame, totalSpeechFrames >= 2 else {
            return nil
        }

        // Add 150ms padding around speech to prevent sharp clipping while eliminating tail silence
        let paddingFrames = Int(sampleRate * 0.15)
        let start = max(0, first - paddingFrames)
        let end = min(count, last + paddingFrames)

        return (start, end)
    }

    // MARK: - Peak Normalization

    private func normalizeLoudness(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData, buffer.frameLength > 0 else { return }
        let channelCount = Int(buffer.format.channelCount)
        let length = vDSP_Length(buffer.frameLength)

        var maxPeak: Float = 0
        for ch in 0..<channelCount {
            var channelPeak: Float = 0
            vDSP_maxv(channelData[ch], 1, &channelPeak, length)
            maxPeak = max(maxPeak, channelPeak)
        }

        // If audio is reasonably audible (> 0.05) and below clipping threshold (< 0.95), normalize to 0.88
        if maxPeak > 0.03 && maxPeak < 0.85 {
            var gain = 0.88 / maxPeak
            for ch in 0..<channelCount {
                vDSP_vsmul(channelData[ch], 1, &gain, channelData[ch], 1, length)
            }
        }
    }
}
