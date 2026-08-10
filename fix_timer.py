with open('/Users/aleksei/Documents/Scribe/Scribe/AppState.swift', 'r') as f:
    content = f.read()

timer_creation = """            settingsPreviewAnimTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in"""
timer_replacement = """            let timer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
                guard let self = self, !self.isRecording && !self.isTranscribing else { return }
                let level = Float.random(in: 0.25...0.65)
                withAnimation(.linear(duration: 0.08)) {
                    self.audioLevel = level
                }
            }
            RunLoop.main.add(timer, forMode: .common)
            settingsPreviewAnimTimer = timer"""

# We need to replace the exact block in AppState.swift
import re
pattern = r'settingsPreviewAnimTimer = Timer\.scheduledTimer\(withTimeInterval: 0\.08, repeats: true\) \{ \[weak self\] _ in.*?self\.audioLevel = level\n\s*\}\n\s*\}'
content = re.sub(pattern, timer_replacement, content, flags=re.DOTALL)

# For previewDismissTimer
dismiss_timer_creation = """        previewDismissTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in"""
dismiss_timer_replacement = """        let dTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.hideSettingsPreviewPanel()
            }
        }
        RunLoop.main.add(dTimer, forMode: .common)
        previewDismissTimer = dTimer"""

pattern2 = r'previewDismissTimer = Timer\.scheduledTimer\(withTimeInterval: 5\.0, repeats: false\) \{ \[weak self\] _ in\n\s*Task \{ @MainActor \[weak self\] in\n\s*self\?\.hideSettingsPreviewPanel\(\)\n\s*\}\n\s*\}'
content = re.sub(pattern2, dismiss_timer_replacement, content, flags=re.DOTALL)

with open('/Users/aleksei/Documents/Scribe/Scribe/AppState.swift', 'w') as f:
    f.write(content)
