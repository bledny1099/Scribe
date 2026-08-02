# Changelog

All notable changes to Scribe will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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