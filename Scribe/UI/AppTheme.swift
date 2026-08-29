import SwiftUI

// MARK: - Theme Definition

/// Available visual themes for the recording overlay and accent colors.
enum AppTheme: String, CaseIterable, Identifiable {
    case aurora    // Purple → Cyan  (original)
    case ember     // Orange → Rose
    case ocean     // Blue → Teal
    case solar     // Amber → Sunset Coral
    case darkBlue  // Navy → Indigo
    case green     // Lime → Emerald

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .aurora: "Aurora"
        case .ember:  "Ember"
        case .ocean:  "Ocean"
        case .solar:  "Solar"
        case .darkBlue:  "Midnight"
        case .green:     "Emerald"
        }
    }

    var icon: String {
        switch self {
        case .aurora: "sparkles"
        case .ember:  "flame.fill"
        case .ocean:  "drop.fill"
        case .solar:  "sun.max.fill"
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
        case .solar:  "mic.fill"
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
        case .solar:
            [
                Color(red: 0.980, green: 0.650, blue: 0.150),   // warm amber
                Color(red: 0.940, green: 0.280, blue: 0.450)    // sunset coral
            ]
        case .darkBlue:
            [
                Color(red: 0.14, green: 0.20, blue: 0.52),   // deep sapphire
                Color(red: 0.28, green: 0.40, blue: 0.85)    // electric indigo
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
        case .solar:  Color(red: 0.980, green: 0.650, blue: 0.150)
        case .darkBlue:  Color(red: 0.28, green: 0.40, blue: 0.85)
        case .green:     .green
        }
    }

    /// High-contrast text color when rendered on top of this theme's accent gradient.
    var contrastTextColor: Color {
        return Color.white
    }

    /// Preview swatch colors for the theme picker (first, second).
    var swatchColors: (Color, Color) {
        (gradientColors[0], gradientColors[1])
    }
}
