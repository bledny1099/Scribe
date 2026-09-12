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

    /// Directory URL for macOS Voice Memos (Диктофон) recordings
    public static var voiceMemosDirectoryURL: URL? {
        let path = ("~/Library/Group Containers/group.com.apple.VoiceMemos.shared/Recordings" as NSString).expandingTildeInPath
        if FileManager.default.fileExists(atPath: path) {
            return URL(fileURLWithPath: path)
        }
        return nil
    }

    /// Prompts the user to pick a recording directly from Voice Memos.
    @MainActor
    public static func pickVoiceMemoFile() -> URL? {
        let openPanel = NSOpenPanel()
        openPanel.title = "Выберите запись из Диктофона"
        openPanel.prompt = "Импортировать"
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canCreateDirectories = false
        openPanel.canChooseFiles = true
        if let dir = voiceMemosDirectoryURL {
            openPanel.directoryURL = dir
        }

        let audioTypes: [UTType] = [
            UTType(filenameExtension: "m4a") ?? .audio,
            .audio,
            .mp3,
            .wav
        ]
        openPanel.allowedContentTypes = audioTypes

        if openPanel.runModal() == .OK {
            return openPanel.url
        }
        return nil
    }

    /// Robust helper to extract a file URL from an NSItemProvider dropped from Finder or Voice Memos app
    public static func extractDroppedFileURL(from provider: NSItemProvider) async -> URL? {
        // 1. Try URL representation
        if provider.canLoadObject(ofClass: URL.self) {
            let url: URL? = await withCheckedContinuation { continuation in
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    continuation.resume(returning: url)
                }
            }
            if let url = url, isSupportedFile(url: url) {
                return url
            }
        }
        // 2. Try file-url type identifier
        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            let url: URL? = await withCheckedContinuation { continuation in
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    if let url = item as? URL {
                        continuation.resume(returning: url)
                    } else if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                        continuation.resume(returning: url)
                    } else if let str = item as? String, let url = URL(string: str) {
                        continuation.resume(returning: url)
                    } else {
                        continuation.resume(returning: nil)
                    }
                }
            }
            if let url = url, isSupportedFile(url: url) {
                return url
            }
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
