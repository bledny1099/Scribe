import AppKit
import os.log

private let logger = Logger(subsystem: "com.aleksei.scribe", category: "SoundFeedback")

/// Plays short system sounds for recording events.
enum SoundFeedback {

    enum Event {
        case recordingStarted
        case recordingStopped
        case transcriptionDone
        case error
    }

    /// Play the appropriate system sound for the event.
    static func play(_ event: Event) {
        let soundName: String?
        switch event {
        case .recordingStarted:  soundName = nil // User requested to remove start sound
        case .recordingStopped:  soundName = "Pop"
        case .transcriptionDone: soundName = "Glass"
        case .error:             soundName = "Basso"
        }

        if let name = soundName {
            if let sound = NSSound(named: NSSound.Name(name)) {
                sound.play()
            } else {
                logger.warning("System sound '\(name)' not found")
            }
        }
    }
}
