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

            // If audio is longer than 3 minutes (e.g. lecture or long meeting), stabilize volume in streaming chunks
            if frameCount > AVAudioFrameCount(format.sampleRate * 180) {
                logger.info("AetherAudioConditioner: Long audio file (\(Int(Double(frameCount) / format.sampleRate))s). Running streaming AGC microphone volume stabilization.")
                return conditionLongAudio(audioURL: audioURL, file: file, format: format, frameCount: frameCount)
            }

            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
                return audioURL
            }

            try file.read(into: buffer)
            guard let channelData = buffer.floatChannelData else { return audioURL }

            let sampleRate = Float(format.sampleRate)
            let channelCount = Int(format.channelCount)
            let samplesPerChannel = Int(buffer.frameLength)

            if samplesPerChannel < Int(sampleRate * 0.1) {
                // Audio is too short to contain speech (<100ms)
                logger.info("AetherAudioConditioner: Audio is too short (<100ms). Returning nil.")
                return nil
            }

            // 1. High-Pass Filter (>80 Hz) to eliminate desk rumble & keyboard thumps
            applyHighPassFilter(channelData: channelData, channelCount: channelCount, count: samplesPerChannel, sampleRate: sampleRate)

            // 2. VAD: Find speech boundaries (leading & trailing silence)
            guard let (startFrame, endFrame) = detectSpeechBoundaries(
                channelData: channelData,
                channelCount: channelCount,
                count: samplesPerChannel,
                sampleRate: sampleRate
            ) else {
                logger.info("AetherAudioConditioner: No speech detected in audio (silence/ambient noise). Returning nil.")
                return nil
            }

            let trimmedLength = max(1, endFrame - startFrame)
            guard let trimmedBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(trimmedLength)) else {
                return audioURL
            }
            trimmedBuffer.frameLength = AVAudioFrameCount(trimmedLength)

            // If a 2-channel USB interface carries the microphone on only one channel, mirror the active channel
            // so downstream mono downmixing never halves signal amplitude or reads a dead channel.
            var dominantChannel: Int? = nil
            if channelCount >= 2 {
                var rms0: Float = 0
                var rms1: Float = 0
                vDSP_rmsqv(channelData[0].advanced(by: startFrame), 1, &rms0, vDSP_Length(trimmedLength))
                vDSP_rmsqv(channelData[1].advanced(by: startFrame), 1, &rms1, vDSP_Length(trimmedLength))
                if rms0 > rms1 * 3.0 {
                    dominantChannel = 0
                } else if rms1 > rms0 * 3.0 {
                    dominantChannel = 1
                }
            }

            for ch in 0..<channelCount {
                let sourceChannel = dominantChannel ?? ch
                let srcPtr = channelData[sourceChannel].advanced(by: startFrame)
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
            logger.warning("Aether audio conditioning failed: \(error.localizedDescription). Falling back to original audio.")
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

    private func detectSpeechBoundaries(channelData: UnsafePointer<UnsafeMutablePointer<Float>>, channelCount: Int, count: Int, sampleRate: Float) -> (Int, Int)? {
        let frameSize = Int(sampleRate * 0.02) // 20ms frame
        guard frameSize > 0, count > frameSize else { return nil }

        let totalFrames = count / frameSize
        guard totalFrames >= 5 else { return nil } // Less than 100ms is not speech

        // 1. Gather frame RMS values. Multi-channel interfaces (e.g. Fifine SC3) often carry the mic on only
        // one channel, so take the loudest channel per frame instead of trusting channel 0.
        var frameRMSValues = [Float](repeating: 0, count: totalFrames)
        for f in 0..<totalFrames {
            let offset = f * frameSize
            var loudest: Float = 0
            for ch in 0..<max(1, channelCount) {
                var frameRms: Float = 0
                vDSP_rmsqv(channelData[ch].advanced(by: offset), 1, &frameRms, vDSP_Length(frameSize))
                loudest = max(loudest, frameRms)
            }
            frameRMSValues[f] = loudest
        }

        // 2. Dynamic energy analysis
        let sortedRMS = frameRMSValues.sorted()
        // Use 5th percentile as ambient noise floor so quiet words and phrase endings are never mistaken for noise
        let p05Index = max(0, min(totalFrames - 1, totalFrames / 20))
        let noiseFloorRMS = sortedRMS[p05Index]
        let noiseFloorDb = 20 * log10(max(noiseFloorRMS, 1e-5))

        let maxRMS = sortedRMS.last ?? 0
        let maxDb = 20 * log10(max(maxRMS, 1e-5))
        let dynamicRange = maxDb - noiseFloorDb

        // Reject only true silence / dead mic where peak energy is below -54 dBFS
        if maxDb < -54.0 || (maxDb < -46.0 && dynamicRange < 2.5) {
            logger.info("AetherAudioConditioner: Audio is silence (maxDb: \(maxDb) dBFS, noiseFloor: \(noiseFloorDb) dBFS, dynamicRange: \(dynamicRange) dB).")
            return nil
        }

        // Speech threshold: at least 2.5 dB above ambient noise floor, clamped between -55.0 dBFS and -40.0 dBFS
        let speechThresholdDb = min(-40.0, max(-55.0, noiseFloorDb + 2.5))
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

        // Must have at least 3 speech frames (~60ms of voiced speech)
        guard var first = firstSpeechFrame, var last = lastSpeechFrame, totalSpeechFrames >= 3 else {
            logger.info("AetherAudioConditioner: Only \(totalSpeechFrames) speech frames found (<3). Audio is silence or click.")
            return nil
        }

        // Expand boundaries with a gentle threshold so quiet syllables at the start and end of phrases are preserved
        let boundaryThresholdDb = min(-48.0, max(-62.0, noiseFloorDb + 1.5))
        let boundaryThresholdRMS = pow(10.0, boundaryThresholdDb / 20.0)
        func isSustained(_ f: Int) -> Bool {
            let lo = max(0, f - 2), hi = min(totalFrames - 1, f + 2)
            var active = 0
            for k in lo...hi where frameRMSValues[k] > boundaryThresholdRMS { active += 1 }
            return active >= 2
        }
        if let f = (0..<totalFrames).first(where: isSustained) {
            first = min(first, f * frameSize)
        }
        if let f = (0..<totalFrames).reversed().first(where: isSustained) {
            last = max(last, (f + 1) * frameSize)
        }

        // Preserve 400ms before speech onset (captures soft unvoiced initial consonants in English/Russian)
        // and 1.50s after speech offset so trailing words and endings are never cut off.
        let leadPadding = Int(sampleRate * 0.40)
        let tailPadding = Int(sampleRate * 1.50)
        let start = max(0, first - leadPadding)
        var end = min(count, last + tailPadding)
        // Only trim trailing audio when there is more than 1.0s of pure silence after padding
        if count - end < Int(sampleRate * 1.0) {
            end = count
        }

        let trimmedTail = Float(count - end) / sampleRate
        if trimmedTail > 0.5 {
            logger.info("AetherAudioConditioner: trimmed \(String(format: "%.2f", trimmedTail))s of trailing silence (boundary threshold \(String(format: "%.1f", boundaryThresholdDb)) dBFS, noise floor \(String(format: "%.1f", noiseFloorDb)) dBFS)")
        }

        return (start, end)
    }

    // MARK: - Adaptive Speech Loudness Normalization & Soft Limiting

    /// Normalizes active speech energy to optimal Whisper decoding level (-19 dBFS RMS) with soft-knee limiting
    /// without gating quiet syllables or unvoiced consonants inside phrases.
    private func normalizeLoudness(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData, buffer.frameLength > 0 else { return }
        let channelCount = Int(buffer.format.channelCount)
        let length = Int(buffer.frameLength)
        let sampleRate = Float(buffer.format.sampleRate)

        // 1. Calculate 20ms Window RMS across channels
        let windowSize = max(1, Int(sampleRate * 0.02)) // 20ms window
        let numWindows = length / windowSize
        var speechRmsSum: Float = 0
        var speechWindowCount = 0

        if numWindows > 0 {
            for w in 0..<numWindows {
                let offset = w * windowSize
                var loudest: Float = 0
                for ch in 0..<channelCount {
                    var wRms: Float = 0
                    vDSP_rmsqv(channelData[ch] + offset, 1, &wRms, vDSP_Length(windowSize))
                    loudest = max(loudest, wRms)
                }
                // Active speech frame threshold (-48 dBFS = 0.00398)
                if loudest > 0.00398 {
                    speechRmsSum += loudest
                    speechWindowCount += 1
                }
            }
        }

        let avgSpeechRms = speechWindowCount > 0 ? (speechRmsSum / Float(speechWindowCount)) : 0

        // 2. Target speech RMS for Whisper attention encoder is ~ -19 dBFS (0.112).
        // Cap boost gain at 12.0x (+21.5 dB) and only boost when genuine speech energy is present.
        let targetRms: Float = 0.112
        var gain: Float = 1.0
        if avgSpeechRms > 0.0035 {
            gain = min(targetRms / avgSpeechRms, 12.0)
        }

        if gain != 1.0 {
            var mutGain = gain
            for ch in 0..<channelCount {
                vDSP_vsmul(channelData[ch], 1, &mutGain, channelData[ch], 1, vDSP_Length(length))
            }
        }

        // 4. Soft-knee compression limiter on peaks > 0.88 to eliminate harsh digital clipping
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

    // MARK: - Streaming Long Audio Conditioning (Lectures / Long Meetings)

    private func conditionLongAudio(audioURL: URL, file: AVAudioFile, format: AVAudioFormat, frameCount: AVAudioFrameCount) -> URL {
        do {
            let sampleRate = Float(format.sampleRate)
            let channelCount = Int(format.channelCount)
            let chunkSize = AVAudioFrameCount(sampleRate * 15.0) // 15-second chunks
            guard let chunkBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: chunkSize) else {
                return audioURL
            }

            let outputURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("aether_conditioned_\(UUID().uuidString).wav")
            let outputFile = try AVAudioFile(forWriting: outputURL, settings: format.settings)

            var remainingFrames = frameCount
            file.framePosition = 0

            while remainingFrames > 0 {
                let framesToRead = min(remainingFrames, chunkSize)
                chunkBuffer.frameLength = framesToRead
                try file.read(into: chunkBuffer, frameCount: framesToRead)

                if let channelData = chunkBuffer.floatChannelData {
                    let count = Int(chunkBuffer.frameLength)
                    applyHighPassFilter(channelData: channelData, channelCount: channelCount, count: count, sampleRate: sampleRate)
                    normalizeLoudness(buffer: chunkBuffer)
                }

                try outputFile.write(from: chunkBuffer)
                remainingFrames -= framesToRead
            }

            logger.info("AetherAudioConditioner: Successfully stabilized microphone volume for long audio file.")
            return outputURL
        } catch {
            logger.warning("Long audio conditioning failed: \(error.localizedDescription). Using original audio.")
            return audioURL
        }
    }
}
