import re

with open("Scribe/UI/SettingsView.swift", "r") as f:
    text = f.read()

# Fix HStack alignment for the sidebar
text = text.replace("HStack(spacing: 0) {", "HStack(alignment: .top, spacing: 0) {")

with open("Scribe/UI/SettingsView.swift", "w") as f:
    f.write(text)

with open("Scribe/UI/RecordingOverlayView.swift", "r") as f:
    overlay = f.read()

# Fix ClassicOverlay glow to be static
old_glow = """                // Radial glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                glow.opacity(0.35 * Double(audioRecorder.audioLevel)),
                                Color.clear,
                            ],"""
new_glow = """                // Radial glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                glow.opacity(0.15),
                                Color.clear,
                            ],"""
overlay = overlay.replace(old_glow, new_glow)

# Change animations to be faster and less CPU intensive
overlay = overlay.replace(".animation(.easeOut(duration: 0.1), value: audioRecorder.audioLevel)", ".animation(.linear(duration: 0.04), value: audioRecorder.audioLevel)")

with open("Scribe/UI/RecordingOverlayView.swift", "w") as f:
    f.write(overlay)

print("UI fixes applied.")
