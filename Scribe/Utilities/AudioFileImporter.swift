import Foundation
import Cocoa
import AVFoundation
import UniformTypeIdentifiers
import OSLog

private let logger = Logger(subsystem: "com.aleksei.scribe", category: "AudioFileImporter")

/// Utilities for importing and preparing audio/video lecture files for offline transcription.
public enum AudioFileImporter {

    /// Prompts the user to select an audio or video file.
    @MainActor
    public static func pickFile() -> URL? {
        let openPanel = NSOpenPanel()
        openPanel.title = "Выберите аудио- или видеофайл лекции"
        openPanel.prompt = "Транскрибировать"
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canCreateDirectories = false
        openPanel.canChooseFiles = true

        let audioTypes: [UTType] = [
            .audio,
            .mp3,
            .wav,
            .aiff,
            .movie,
            .video,
            .quickTimeMovie,
            .mpeg4Movie,
            UTType(filenameExtension: "m4a") ?? .audio,
            UTType(filenameExtension: "aac") ?? .audio,
            UTType(filenameExtension: "caf") ?? .audio,
            UTType(filenameExtension: "flac") ?? .audio,
            UTType(filenameExtension: "ogg") ?? .audio
        ]
        openPanel.allowedContentTypes = audioTypes

        if openPanel.runModal() == .OK {
            return openPanel.url
        }
        return nil
    }

    /// Checks if a file URL is a supported audio or video file.
    public static func isSupportedFile(url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        let supportedExtensions: Set<String> = [
            "mp3", "m4a", "wav", "aac", "caf", "aiff", "flac", "ogg", "mp4", "mov", "m4v"
        ]
        return supportedExtensions.contains(ext)
    }

    /// Prepares an audio/video file for Whisper transcription.
    /// If the input is a video file, it extracts audio into a temporary M4A container.
    public static func prepareAudio(from fileURL: URL) async throws -> URL {
        let ext = fileURL.pathExtension.lowercased()
        let videoExtensions: Set<String> = ["mp4", "mov", "m4v", "avi", "mkv"]

        // If it's pure audio, CoreAudio can read it directly
        if !videoExtensions.contains(ext) {
            return fileURL
        }

        logger.info("Extracting audio track from video file: \(fileURL.lastPathComponent)")
        let asset = AVURLAsset(url: fileURL)
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("lecture_extracted_\(UUID().uuidString).m4a")

        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetAppleM4A
        ) else {
            logger.warning("Failed to initialize AVAssetExportSession, attempting raw file")
            return fileURL
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a

        await exportSession.export()

        if let error = exportSession.error {
            logger.error("Audio extraction failed: \(error.localizedDescription)")
            throw error
        }

        if exportSession.status == .completed && FileManager.default.fileExists(atPath: outputURL.path) {
            logger.info("Successfully extracted audio to: \(outputURL.path)")
            return outputURL
        }

        return fileURL
    }
}
