# Scribe Project Context & Guidelines

## 1. Project Overview
**Scribe** is a high-performance, privacy-focused voice dictation ecosystem. It consists of two main components:
1. **Scribe Native App (`/Scribe`)**: A native macOS/iOS application built with Swift and SwiftUI. It handles system-wide audio capture, dual-engine transcription (Apple Speech + OpenAI), dynamic UI overlays, and complex state management.
2. **ScribeWeb (`/ScribeWeb`)**: A premium marketing landing page generated statically using the [Ignite](https://github.com/twostraws/Ignite) framework (Server-Side Swift).

---

## 2. Native App Architecture (`/Scribe`)

### Core Directories
- **`AppState.swift`**: The central nervous system. A massive `@Observable` / `ObservableObject` state store managing everything from API keys to UI theme states.
- **`/Audio` & `/Transcription`**: The core engines. Scribe uses a dual-engine approach: local Apple Speech for instant realtime feedback, and cloud-based models (like OpenAI Whisper/GPT) for highly accurate, context-aware final processing.
- **`/UI`**: Contains the SwiftUI views, including floating panels, settings windows, and visually rich overlays (Aurora, Liquid Glass).
- **`/Utilities`**: Helpers for system permissions, hotkeys (`LaunchAtLoginHelper.swift`, `Shortcuts.swift`), and formatting.

### Development History & Python Scripts
The root directory is filled with Python scripts (e.g., `fix_all.py`, `rewrite_stats.py`, `translate_all.py`). These were used for aggressive, programmatic AST/Regex refactoring of the SwiftUI codebase during rapid iteration phases. 
**Agent Rule**: Do NOT run these Python scripts automatically. They are historical tools. Prefer direct file editing for modern changes.

---

## 3. Web Architecture (`/ScribeWeb`)

### Tech Stack
- **Generator**: Ignite Framework v0.6.9 (Swift).
- **Command**: Run `swift run` inside `/ScribeWeb` to generate the HTML into the `build/` folder.
- **Assets**: CSS and JS are hand-rolled in `Assets/css/` and `Assets/js/`.

### The `aqua.css` Design System
The web frontend strictly follows a premium, minimalist design language (internally modeled after Scribe and "taste-skill" anti-slop guidelines):
- **Typography**: Geometric sans-serif (`Inter`). Heavy weights (`800`) for headers, tight letter-spacing (`-2px`), and tight line-heights (`1.05`). **Do not use Serif fonts.**
- **Bootstrap Suppression**: Ignite injects Bootstrap by default. `aqua.css` actively suppresses Bootstrap's `.container` and default `<p>` margins to allow full viewport control. **Do not use Bootstrap utility classes** (like `mb-3` or `row`) in the Swift code.
- **Layouts**: Heavy use of Bento Grids, asymmetrical 3-column splits, and clean feature lists.
- **Motion**: Premium animations only. Uses `cubic-bezier(0.16, 1, 0.3, 1)` to simulate spring physics, paired with `blur` reveals.

### Agent Rules for Web Development
1. **Cache Busting**: Browsers cache Ignite assets aggressively. If you edit `aqua.css` or `app.js`, you **MUST** increment the version number in `Site.swift` (e.g., `href: "/css/aqua.css?v=4"`).
2. **Component Structure**: Ignite's `Section` defaults to a generic `<div>`. Rely on `.class("your-class")` for all styling.
3. **Interactive Demos**: The page features a functional SwiftUI-rendered `SettingsPanel` embedded directly into the HTML to demonstrate the app's UI dynamically.

---

## 4. Core AI Interaction Rules

When assisting with this project, you must adhere to the following constraints:

1. **Verify Before Editing**: The SwiftUI application is complex. Always use `grep_search` or `view_file` on `AppState.swift` to understand the state shape before modifying UI components.
2. **MainActor Isolation**: Any changes to `AppState` properties that trigger UI updates must be executed on the Main thread (`@MainActor` or `DispatchQueue.main.async`).
3. **Maintain Aesthetic Integrity**: If asked to add a new section to the website, copy the exact DOM structure and classes of existing `.aqua-container` elements. Do not invent generic gray boxes or default AI-purple gradients.
4. **Tool Priority**: Use `multi_replace_file_content` for precise edits. Never use `cat` or `sed` via bash to edit code.
