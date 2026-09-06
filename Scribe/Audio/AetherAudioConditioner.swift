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
            guard let (startFrame, endFrame) = detectSpeechBoundaries(
                channelData: channelData[0],
                count: samplesPerChannel,
                sampleRate: sampleRate
            ) else {
                logger.info("AetherAudioConditioner: No speech detected in audio file. Returning nil to skip transcription.")
                return nil
            }

            let trimmedLength = max(1, endFrame - startFrame)
            guard let trimmedBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(trimmedLength)) else {
                return nil
            }
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
            logger.debug("Aether conditioned audio: trimmed \(samplesPerChannel) -> \(trimmedLength) frames (1.0x natural tempo)")
            return outputURL
        } catch {
            logger.warning("Aether audio conditioning failed: \(error.localizedDescription)")
            return nil
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
        guard frameSize > 0, count > frameSize else { return nil }

        let totalFrames = count / frameSize
        guard totalFrames >= 5 else { return nil } // Less than 100ms is not speech

        // 1. Gather frame RMS values
        var frameRMSValues = [Float](repeating: 0, count: totalFrames)
        for f in 0..<totalFrames {
            let offset = f * frameSize
            var frameRms: Float = 0
            vDSP_rmsqv(channelData.advanced(by: offset), 1, &frameRms, vDSP_Length(frameSize))
            frameRMSValues[f] = frameRms
        }

        // 2. Dynamic energy analysis
        let sortedRMS = frameRMSValues.sorted()
        // Use 5th percentile as noise floor to reliably measure ambient room noise even during speech
        let p05Index = max(0, min(totalFrames - 1, totalFrames / 20))
        let noiseFloorRMS = sortedRMS[p05Index]
        let noiseFloorDb = 20 * log10(max(noiseFloorRMS, 1e-5))

        let maxRMS = sortedRMS.last ?? 0
        let maxDb = 20 * log10(max(maxRMS, 1e-5))
        let dynamicRange = maxDb - noiseFloorDb

        // Audio is silence if peak is below -58 dBFS (Mac microphone silence floor).
        // If peak is between -58 dBFS and -50 dBFS, ensure dynamic range > 2.0 dB to separate soft speech from flat fan/AC hum.
        if maxDb < -58.0 || (maxDb < -50.0 && dynamicRange < 2.0) {
            logger.info("AetherAudioConditioner: Audio is silence (maxDb: \(maxDb) dBFS, noiseFloor: \(noiseFloorDb) dBFS, dynamicRange: \(dynamicRange) dB).")
            return nil
        }

        // Speech threshold: at least 2.0 dB above noise floor, clamped between -56.0 dBFS and -42.0 dBFS
        let speechThresholdDb = min(-42.0, max(-56.0, noiseFloorDb + 2.0))
        let speechThresholdRMS = pow(10.0, speechThresholdDb / 20.0)

        var firstSpeechFrame: Int?
        var lastSpeechFrame: Int?
        var totalSpeechFrames = 0

        for f in 0..<totalFrames {
            if frameRMSValues[f] > speechThresholdRMS {
                let offset = f * frameSize
                if firstSpeechFrame == nil {
                    firstSpeechFrame = offset
                }
                lastSpeechFrame = offset + frameSize
                totalSpeechFrames += 1
            }
        }

        // Must have at least 3 speech frames (~60ms of speech) to avoid single-click transients
        guard let first = firstSpeechFrame, let last = lastSpeechFrame, totalSpeechFrames >= 3 else {
            logger.info("AetherAudioConditioner: Only \(totalSpeechFrames) speech frames found (<3). Audio is silence or clicks.")
            return nil
        }

        // Add 300ms lead and 450ms tail padding
        let leadPadding = Int(sampleRate * 0.30)
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
        let windowSize = max(1, Int(Float(buffer.format.sampleRate) * 0.03)) // 30ms window
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
