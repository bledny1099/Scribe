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
        // Use 20th percentile as ambient noise floor so Gaussian room noise fluctuations are not mistaken for speech
        let p20Index = max(0, min(totalFrames - 1, totalFrames / 5))
        let noiseFloorRMS = sortedRMS[p20Index]
        let noiseFloorDb = 20 * log10(max(noiseFloorRMS, 1e-5))

        let maxRMS = sortedRMS.last ?? 0
        let maxDb = 20 * log10(max(maxRMS, 1e-5))
        let dynamicRange = maxDb - noiseFloorDb

        // Reject quiet non-speech sounds (breaths, sighs, keyboard taps, rustling) where peak energy is below -44 dBFS
        // or below -37 dBFS without clear dynamic range above ambient noise.
        if maxDb < -44.0 || (maxDb < -37.0 && dynamicRange < 5.5) {
            logger.info("AetherAudioConditioner: Audio is silence or quiet non-speech sound (maxDb: \(maxDb) dBFS, noiseFloor: \(noiseFloorDb) dBFS, dynamicRange: \(dynamicRange) dB).")
            return nil
        }

        // Speech threshold: at least 6.0 dB above ambient noise floor, clamped between -46.0 dBFS and -35.0 dBFS
        let speechThresholdDb = min(-35.0, max(-46.0, noiseFloorDb + 6.0))
        let speechThresholdRMS = pow(10.0, speechThresholdDb / 20.0)

        var firstSpeechFrame: Int?
        var lastSpeechFrame: Int?
        var totalSpeechFrames = 0

        for f in 0..<totalFrames {
            guard frameRMSValues[f] > speechThresholdRMS else { continue }
            // Ignore isolated 1-2 frame mechanical clicks (e.g. Shift/hotkey press or mouse click):
            // require at least 2 neighboring frames in a 5-frame (100ms) window to carry sustained energy.
            let lo = max(0, f - 2), hi = min(totalFrames - 1, f + 2)
            var neighbors = 0
            for k in lo...hi where k != f && frameRMSValues[k] > speechThresholdRMS * 0.72 {
                neighbors += 1
            }
            guard neighbors >= 2 else { continue }

            let offset = f * frameSize
            if firstSpeechFrame == nil {
                firstSpeechFrame = offset
            }
            lastSpeechFrame = offset + frameSize
            totalSpeechFrames += 1
        }

        // Must have at least 5 sustained speech frames (~100ms of voiced speech) to reject breaths and key clicks
        guard var first = firstSpeechFrame, var last = lastSpeechFrame, totalSpeechFrames >= 5 else {
            logger.info("AetherAudioConditioner: Only \(totalSpeechFrames) sustained speech frames found (<5). Audio is silence, breath, or key clicks.")
            return nil
        }

        // Trim boundaries with a softer sustained threshold so quiet syllables at the start/end of a phrase are preserved,
        // while isolated pre-speech/post-speech breaths and key taps are trimmed away.
        let boundaryThresholdDb = min(-38.0, max(-48.0, noiseFloorDb + 4.5))
        let boundaryThresholdRMS = pow(10.0, boundaryThresholdDb / 20.0)
        func isSustained(_ f: Int) -> Bool {
            let lo = max(0, f - 2), hi = min(totalFrames - 1, f + 2)
            var active = 0
            for k in lo...hi where frameRMSValues[k] > boundaryThresholdRMS { active += 1 }
            return active >= 3
        }
        if let f = (0..<totalFrames).first(where: isSustained) {
            first = min(first, f * frameSize)
        }
        if let f = (0..<totalFrames).reversed().first(where: isSustained) {
            last = max(last, (f + 1) * frameSize)
        }

        // Preserve 280ms before speech onset (captures soft unvoiced initial consonants in English/Russian)
        // and 320ms after speech offset (cuts out trailing hotkey release and breath sounds).
        let leadPadding = Int(sampleRate * 0.28)
        let tailPadding = Int(sampleRate * 0.32)
        let start = max(0, first - leadPadding)
        let end = min(count, last + tailPadding)

        let trimmedTail = Float(count - end) / sampleRate
        if trimmedTail > 0.5 {
            logger.info("AetherAudioConditioner: trimmed \(String(format: "%.2f", trimmedTail))s of trailing silence (boundary threshold \(String(format: "%.1f", boundaryThresholdDb)) dBFS, noise floor \(String(format: "%.1f", noiseFloorDb)) dBFS)")
        }

        return (start, end)
    }

    // MARK: - Adaptive Speech Loudness Normalization, Downward Expander & Soft Limiting

    /// Attenuates quiet non-speech sounds (breaths, sighs, keyboard taps in pauses) via a smooth downward expander
    /// and normalizes active speech energy to optimal Whisper decoding level (-19 dBFS RMS) with soft-knee limiting.
    private func normalizeLoudness(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData, buffer.frameLength > 0 else { return }
        let channelCount = Int(buffer.format.channelCount)
        let length = Int(buffer.frameLength)
        let sampleRate = Float(buffer.format.sampleRate)

        // 1. Calculate 20ms Window RMS across channels
        let windowSize = max(1, Int(sampleRate * 0.02)) // 20ms window
        let numWindows = length / windowSize
        var windowRMS = [Float](repeating: 0, count: max(1, numWindows))
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
                windowRMS[w] = loudest
                // Active speech frame threshold (-45 dBFS = 0.00562)
                if loudest > 0.00562 {
                    speechRmsSum += loudest
                    speechWindowCount += 1
                }
            }
        }

        let avgSpeechRms = speechWindowCount > 0 ? (speechRmsSum / Float(speechWindowCount)) : 0

        // 2. Smooth Downward Expander (Noise Gate for quiet breaths / keyboard taps during pauses):
        // Any window more than ~16 dB quieter than the speaker's voice (or below -51 dBFS) and not adjacent to
        // sustained speech is attenuated so Whisper never hallucinates words like "shift" on quiet breaths/taps.
        if numWindows >= 5 && avgSpeechRms > 0.0045 {
            let gateThreshold = max(0.0028, avgSpeechRms * 0.16)
            var isSustainedVoice = [Bool](repeating: false, count: numWindows)
            for w in 0..<numWindows {
                guard windowRMS[w] >= gateThreshold else { continue }
                let lo = max(0, w - 1), hi = min(numWindows - 1, w + 1)
                var activeNeighbors = 0
                for k in lo...hi where k != w && windowRMS[k] >= gateThreshold * 0.68 {
                    activeNeighbors += 1
                }
                // Reject solitary 20ms mechanical key/mouse clicks surrounded by silence
                if activeNeighbors >= 1 {
                    isSustainedVoice[w] = true
                }
            }

            // Dilate active speech mask by 3 windows (60ms) on each side to preserve soft initial/final consonants
            var rawGain = [Float](repeating: 0.06, count: numWindows)
            for w in 0..<numWindows where isSustainedVoice[w] {
                let lo = max(0, w - 3), hi = min(numWindows - 1, w + 3)
                for k in lo...hi {
                    rawGain[k] = 1.0
                }
            }

            // Smooth window gains to prevent any envelope clicks
            var smoothedGain = rawGain
            for w in 0..<numWindows {
                let lo = max(0, w - 1), hi = min(numWindows - 1, w + 1)
                var sum: Float = 0
                for k in lo...hi { sum += rawGain[k] }
                smoothedGain[w] = sum / Float(hi - lo + 1)
            }

            for ch in 0..<channelCount {
                let ptr = channelData[ch]
                for w in 0..<numWindows {
                    let g0 = smoothedGain[w]
                    let g1 = (w + 1 < numWindows) ? smoothedGain[w + 1] : g0
                    let offset = w * windowSize
                    if g0 == 1.0 && g1 == 1.0 { continue }
                    for i in 0..<windowSize {
                        let frac = Float(i) / Float(windowSize)
                        ptr[offset + i] *= (g0 + (g1 - g0) * frac)
                    }
                }
                let remStart = numWindows * windowSize
                let lastG = smoothedGain.last ?? 1.0
                if remStart < length && lastG < 1.0 {
                    for i in remStart..<length {
                        ptr[i] *= lastG
                    }
                }
            }
        }

        // 3. Target speech RMS for Whisper attention encoder is ~ -19 dBFS (0.112).
        // Cap boost gain at 8.0x (+18 dB) and only boost when genuine speech energy is present.
        let targetRms: Float = 0.112
        var gain: Float = 1.0
        if avgSpeechRms > 0.0045 {
            gain = min(targetRms / avgSpeechRms, 8.0)
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
