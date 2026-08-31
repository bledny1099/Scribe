# Changelog

All notable changes to Scribe will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.6.0] - 2026-08-31

## Added
- Multilingual grammar and orthographic engines in Aether Linguistic Validator for German (Komposita & capitalization), French (elisions & liaisons), Spanish (inverted punctuation & clitics), Italian (preposition fusions), Chinese (CJK punctuation & alphanumeric spacing), and Hindi (Devanagari NFC normalization & Nukta corrections).
- Systematic Russian subject-predicate past tense gender agreement engine for neuter, masculine, and feminine proper names, sports clubs, and compound entities.
- Streamlined 3-tier ASR model selector: Ultra (Large V3 Turbo), Standard (Balanced), and Eco (Fast & Lightweight).

## Changed
- Expanded Aether Context Engine language dispatch and domain prompts across 10 specialized app environments.
- Optimized spell checker resolution with native CJK and Devanagari script detection.

## Fixed
- Fixed timer digit flickering and color shifting between black and gray across overlay styles.
- Fixed unstressed past tense verb mishearings and gender mismatches across speech models.
- Fixed elision token splitting in French, Italian, and Spanish transcriptions.

## [2.5.5] - 2026-08-30

## Added
- Automatic game and match score formatting into digit:digit notation (e.g., "3:0", "2:1", "score of 3:0").
- Native IDE & Vibe Coding domain detection and acoustic rules for AI coding editors (Antigravity IDE, Windsurf, Trae, Fleet, Zed, Cursor, VS Code, Xcode).

## Changed
- Streamlined Live Preview into the floating overlay card and eliminated destructive active window backspacing.
- Injected domain vocabulary and imperative directives for vibe coding into Whisper and Aether context engine.

## Fixed
- Fixed acoustic misrecognitions and phoneme variations of "vibe coding" across speech models.
- Fixed duplicate clipboard paste triggers when completing dictation with active live preview.

## [2.5.4] - 2026-08-30

## Added
- New Solar (Amber → Sunset Coral) overlay theme replacing Lumina for enhanced contrast.
- Full-width Preview Mode responsive layout picker preventing vertical text squishing in General settings.
- Automatic Russian language streaming fallback in Live Preview when preferred languages match Russian.

## Changed
- Decoupled floating overlay appearance completely from panel window theme to preserve high-contrast dark frosted glass.
- Multi-phrase live speech accumulator preventing recognition stalls during pauses in dictation.

## Fixed
- Fixed acoustic phonetic errors and accusative case agreement for target goals.
- Fixed squashed segmented buttons and labels in General settings card.
- Fixed overlay themes turning white when Light Panel appearance is selected.

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