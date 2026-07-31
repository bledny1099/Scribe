import SwiftUI

// MARK: - Theme Definition

/// Available visual themes for the recording overlay and accent colors.
enum AppTheme: String, CaseIterable, Identifiable {
    case aurora    // Purple → Cyan  (original)
    case ember     // Orange → Rose
    case ocean     // Blue → Teal
    case whiteGlow // White → Silver
    case darkBlue  // Navy → Indigo
    case green     // Lime → Emerald

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .aurora: "Aurora"
        case .ember:  "Ember"
        case .ocean:  "Ocean"
        case .whiteGlow: "Lumina"
        case .darkBlue:  "Midnight"
        case .green:     "Emerald"
        }
    }

    var icon: String {
        switch self {
        case .aurora: "sparkles"
        case .ember:  "flame.fill"
        case .ocean:  "drop.fill"
        case .whiteGlow: "moon.stars.fill"
        case .darkBlue:  "moon.fill"
        case .green:     "leaf.fill"
        }
    }

    /// Icon shown during recording in the overlay.
    var micIcon: String {
        switch self {
        case .aurora: "mic.fill"
        case .ember:  "flame.fill"
        case .ocean:  "waveform"
        case .whiteGlow: "mic.fill"
        case .darkBlue:  "mic.fill"
        case .green:     "mic.fill"
        }
    }

    // MARK: - Gradient Colors

    /// Primary two-color gradient used in rings, icons, and accents.
    var gradientColors: [Color] {
        switch self {
        case .aurora:
            [
                Color(red: 0.545, green: 0.361, blue: 0.965),   // purple
                Color(red: 0.024, green: 0.714, blue: 0.831),   // cyan
            ]
        case .ember:
            [
                Color(red: 0.976, green: 0.412, blue: 0.224),   // orange
                Color(red: 0.894, green: 0.224, blue: 0.451),   // rose
            ]
        case .ocean:
            [
                Color(red: 0.165, green: 0.400, blue: 0.949),   // royal blue
                Color(red: 0.133, green: 0.773, blue: 0.702),   // teal
            ]
        case .whiteGlow:
            [
                Color.white,
                Color(white: 0.85)
            ]
        case .darkBlue:
            [
                Color(red: 0.02, green: 0.04, blue: 0.12),       // midnight black-blue
                Color(red: 0.06, green: 0.10, blue: 0.24)        // deep navy
            ]
        case .green:
            [
                Color(red: 0.196, green: 0.804, blue: 0.196),   // lime
                Color(red: 0.314, green: 0.784, blue: 0.471)    // emerald
            ]
        }
    }

    /// The accent `LinearGradient` for strokes, fills, and icons.
    var accentGradient: LinearGradient {
        LinearGradient(
            colors: gradientColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Color used for the radial glow behind the recording rings.
    var glowColor: Color {
        switch self {
        case .aurora: .purple
        case .ember:  Color(red: 0.976, green: 0.412, blue: 0.224)
        case .ocean:  .blue
        case .whiteGlow: .white
        case .darkBlue:  Color(red: 0.04, green: 0.08, blue: 0.20)
        case .green:     .green
        }
    }

    /// Preview swatch colors for the theme picker (first, second).
    var swatchColors: (Color, Color) {
        (gradientColors[0], gradientColors[1])
    }
}
