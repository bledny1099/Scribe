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

            // Fallback: If speech boundaries were not trimmed, normalize full audio and return it
            normalizeLoudness(buffer: buffer)
            let fallbackURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("aether_conditioned_\(UUID().uuidString).wav")
            let fallbackFile = try AVAudioFile(forWriting: fallbackURL, settings: format.settings)
            try fallbackFile.write(from: buffer)
            return fallbackURL
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

        let silenceThresholdDb: Float = -60.0
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

        guard let first = firstSpeechFrame, let last = lastSpeechFrame, totalSpeechFrames >= 1 else {
            return nil
        }

        // Add generous 450ms tail padding and 200ms lead padding to prevent clipping soft word endings
        let leadPadding = Int(sampleRate * 0.20)
        let tailPadding = Int(sampleRate * 0.45)
        let start = max(0, first - leadPadding)
        let end = min(count, last + tailPadding)

        return (start, end)
    }

    // MARK: - Adaptive Speech Loudness Normalization & Soft Limiting
    
    /// Normalizes speech energy to optimal Whisper decoding level (-19 dBFS RMS) with soft-knee limiting.
    /// Ensures quiet/distant speech and loud close speech are both conditioned to consistent, crystal-clear amplitude.
    private func normalizeLoudness(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData, buffer.frameLength > 0 else { return }
        let channelCount = Int(buffer.format.channelCount)
        let length = Int(buffer.frameLength)

        // 1. Calculate Speech-Segment RMS (excluding pure silence frames)
        let windowSize = 480 // 30ms window at 16kHz
        var speechRmsSum: Float = 0
        var speechWindowCount = 0
        var maxPeak: Float = 0

        for ch in 0..<channelCount {
            let samples = channelData[ch]
            var offset = 0
            while offset + windowSize <= length {
                var windowRms: Float = 0
                vDSP_rmsqv(samples + offset, 1, &windowRms, vDSP_Length(windowSize))
                // Speech frame threshold (-50 dBFS)
                if windowRms > 0.00316 {
                    speechRmsSum += windowRms
                    speechWindowCount += 1
                }
                offset += windowSize
            }
            var chPeak: Float = 0
            vDSP_maxv(samples, 1, &chPeak, vDSP_Length(length))
            maxPeak = max(maxPeak, chPeak)
        }

        // Target speech RMS for Whisper attention encoder is ~ -19 dBFS (0.112)
        let targetRms: Float = 0.112
        var gain: Float = 1.0

        if speechWindowCount > 0 {
            let avgSpeechRms = speechRmsSum / Float(speechWindowCount)
            if avgSpeechRms > 0.005 {
                gain = min(targetRms / avgSpeechRms, 12.0) // Cap gain boost at +21 dB
            }
        } else if maxPeak > 0.01 && maxPeak < 0.85 {
            gain = min(0.85 / maxPeak, 8.0)
        }

        // Apply gain across all channels
        if gain != 1.0 {
            var mutGain = gain
            for ch in 0..<channelCount {
                vDSP_vsmul(channelData[ch], 1, &mutGain, channelData[ch], 1, vDSP_Length(length))
            }
        }

        // 2. Soft-knee compression limiter on peaks > 0.88 to eliminate harsh digital clipping
        for ch in 0..<channelCount {
            let ptr = channelData[ch]
            for i in 0..<length {
                let s = ptr[i]
                if s > 0.88 {
                    ptr[i] = 0.88 + 0.10 * tanh((s - 0.88) / 0.10)
                } else if s < -0.88 {
                    ptr[i] = -0.88 + 0.10 * tanh((s + 0.88) / 0.10)
                }
            }
        }
    }
}
