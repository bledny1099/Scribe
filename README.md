# Scribe

Privacy-focused, native voice dictation for macOS. Dictate anywhere with a single hotkey, transcribe locally using WhisperKit, and insert formatted text directly into your active application.

[**Download Scribe.dmg**](https://github.com/bledny1099/Scribe/releases/latest/download/Scribe.dmg) · [**View Releases**](https://github.com/bledny1099/Scribe/releases) · [**Report Issue**](https://github.com/bledny1099/Scribe/issues)

---

## Features

- **Global Dictation (`⌥S`)**: Press `Option + S` anywhere on macOS to record and automatically paste transcriptions into your focused text field (Slack, Telegram, Xcode, VS Code, Notes, Browser, etc.).
- **100% On-Device & Private**: Runs OpenAI Whisper locally via Apple Silicon Neural Engine (`WhisperKit`). Voice data never leaves your machine unless you enable optional cloud refinement.
- **Audio-Reactive HUD**: Interactive Liquid Glass overlay with dynamic waveform visualization, recording timer, and compact status indicators.
- **AI Refinement Modes**: Optional cloud post-processing (Clean Up, Grammar & Punctuation, Structured Notes, Executive Summary, or custom instructions).
- **Multilingual Support**: Real-time speech recognition across 20+ languages with automatic language detection and optional English translation.
- **Customizable Interface**: 5 HUD overlay styles (*Waveform*, *Classic*, *Minimal*, *ECG*, *Orb*) with curated color themes and light/dark appearance modes.
- **Single-Key Control**: Cancel recordings instantly with `Escape` or the overlay stop button.

---

## Installation

### Direct Download (Recommended)

1. Download the latest **[Scribe.dmg](https://github.com/bledny1099/Scribe/releases/latest/download/Scribe.dmg)**.
2. Open the disk image and drag **Scribe** into your **Applications** folder.
3. Launch Scribe and grant the required permissions (Microphone and Accessibility for auto-pasting).

### Building from Source

Requirements:
- macOS 14.0 (Sonoma) or newer
- Xcode 15+ / 16+
- Apple Silicon (M1/M2/M3/M4) recommended

```bash
# Clone the repository
git clone https://github.com/bledny1099/Scribe.git
cd Scribe

# Build Release DMG
./scripts/build_dmg.sh
```

The compiled application and installer disk image will be available in `dist/Scribe.dmg`.

---

## System Requirements

| Requirement | Specification |
|:---|:---|
| Operating System | macOS 14.0 (Sonoma) or higher |
| Architecture | Apple Silicon (M1, M2, M3, M4) / Intel |
| Storage | ~500 MB for recommended Whisper base models |

---

## License

This project is licensed under the [MIT License](LICENSE).
