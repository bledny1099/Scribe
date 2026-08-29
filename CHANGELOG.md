# Changelog

All notable changes to Scribe will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.5.3] - 2026-08-30

## Added
- Live Typing / Direct Window Insertion mode with real-time cursor streaming and final Whisper replacement.
- In-app 1-click update installation and seamless restart from downloaded DMG without manual drag-and-drop.
- In-app Bug and Crash reporting card in System settings with direct Telegram delivery and diagnostic logs.
- Acoustic phoneme time-stretch expansion in Aether conditioner for studio-grade Whisper phoneme accuracy.
- Explicit Panel Theme (Dark, Light, Liquid Glass) selector in Appearance settings alongside Overlay Theme swatches.

## Changed
- Moved App Theme selection to General settings while retaining Overlay Theme in Appearance settings.
- Switched live speech streaming to adaptive mode preventing stalled recognition on prolonged pauses.
- Background model pre-warming during recording for sub-150ms instant transcription.

## Fixed
- Fixed Pill overlay positioning to remain centered relative to active windows and multi-monitor setups.
- Fixed Live Preview freezing on initial spoken phrases during dictation.
- Fixed permission resetting across updates by enforcing stable code signing requirements.
- Fixed duplicate lines when exporting dictated notes to Apple Notes.
- Fixed GPU stuttering and "No speech" timeouts in Orb (Magic) and ECG (Voltage) overlay modes.

## [2.5.1] - 2026-08-28

## Added
- Intelligent Two-Pass Speech RMS Normalization with soft-knee limiting for consistent speech loudness on external and distant microphones.
- Real-time Russian grammatical agreement and declension rules (subject-verb agreement, preposition-case agreement, and ASR phonetic repairs).
- Anonymous Firestore install and launch telemetry tracking.
- Strict multi-script filtering to eliminate foreign language tokens when specific languages are active.

## Changed
- Menu bar popover "Start Dictation" button redesigned to cleanly match the user profile card.
- Swapped Software Updates and Audio Input sections in System Settings.
- Slower, more organic voice modulation physics for the recording preview waveform.

## Fixed
- Fixed stuttering repetition loops and duplicate word runs in Live Preview.
- Fixed UI lag and high CPU usage during recording and live preview by optimizing waveform spring animations.
- Fixed right padding and centering for the stop button on the recording pill overlay.

## [1.1.0] - 2026-08-02

### Added
- Support Scribe donation modal with Ko-fi integration (ko-fi.com/alekseit) and crypto wallet addresses (USDT TRC20/TON, BTC, ETH).
- Support Scribe button on the Welcome/Permissions onboarding screen.
- Whisper initial prompt with brand name hints for accurate transcription of social networks (TikTok, Instagram, YouTube, Snapchat, Telegram, Viber), AI platforms (ChatGPT, Gemini, Claude, Kimi, Perplexity, Midjourney, OpenAI), and crypto terms (Bybit, Binance, MetaMask, Solana).
- `--permissions` launch argument to force-show the onboarding permissions window for testing.

### Fixed
- Menu bar dropdown now renders correctly under the Scribe icon instead of offset to the side.
- Transcription performance: shortened Whisper initial prompt to ~30 tokens to prevent slow decoding caused by disabled prefill cache with large token counts.
- Prompt token count capped at 200 to prevent WhisperKit crashes when exceeding the 224-token limit.
- Permissions onboarding window sizing to properly fit all content including the Support button.

### Changed
- Support Scribe modal redesigned with Liquid Glass (ultraThinMaterial) background and full-height layout without scrolling.
- Ko-fi button displayed prominently above crypto addresses with "or Crypto" separator.

## [1.0.0] - 2026-07-31

### Added
- Initial release of Scribe voice dictation menu bar app for macOS.
- Local Whisper AI model integration (Small, Large V3 Turbo, Base).
- Global hotkey dictation trigger via Option + S.
- Automatic pasting of transcribed text into active focused applications.
- Multilingual dictation support for over 20 languages and auto-translation.
- Liquid Glass HUD user interface with translucent material blur.
- Audio-reactive visualizer overlays (Classic, Waveform, Minimal, Pulse).
- Customizable color palette themes (Aurora, Ember, Ocean, Lumina, Midnight, Emerald).
- Light and Dark panel appearance modes.
- Clipboard handling modes (Replace vs. Append).
V