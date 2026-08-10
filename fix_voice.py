import re

with open('/Users/aleksei/Documents/Scribe/Scribe/UI/PermissionView.swift', 'r') as f:
    content = f.read()

# 1. Add imports
if 'import Speech' not in content:
    content = content.replace('import SwiftUI', 'import SwiftUI\nimport Speech\nimport AVFoundation')

# 2. Add state variables for audio engine
state_vars = """    @State private var isTestingVoice = false
    @State private var voiceTestText = "Click 'Start Test' and say \\"Testing microphone for Scribe\\""
    @State private var voiceTestSuccess = false
    
    @State private var engine = AVAudioEngine()
    @State private var request = SFSpeechAudioBufferRecognitionRequest()
    @State private var task: SFSpeechRecognitionTask?
"""

content = re.sub(r'    @State private var isTestingVoice = false\n    @State private var voiceTestText = "Click \'Start Test\' and say \\"Testing microphone for Scribe\\""\n    @State private var voiceTestSuccess = false', state_vars, content)

# 3. Replace startVoiceTest
new_func = """    private func startVoiceTest() {
        isTestingVoice = true
        voiceTestText = "Listening..."
        
        let recognizer = SFSpeechRecognizer()
        request = SFSpeechAudioBufferRecognitionRequest()
        let node = engine.inputNode
        let recordingFormat = node.outputFormat(forBus: 0)
        
        node.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.request.append(buffer)
        }
        
        engine.prepare()
        do {
            try engine.start()
            task = recognizer?.recognitionTask(with: request) { result, error in
                if let result = result {
                    let text = result.bestTranscription.formattedString
                    DispatchQueue.main.async {
                        if !text.isEmpty {
                            self.voiceTestText = text
                        }
                        if text.count > 10 {
                            self.voiceTestSuccess = true
                            self.isTestingVoice = false
                            self.voiceTestText = "Perfect! Your mic is working."
                            self.stopVoiceTest()
                        }
                    }
                }
                
                if let error = error {
                    DispatchQueue.main.async {
                        if !self.voiceTestSuccess {
                            self.isTestingVoice = false
                            self.voiceTestText = "Testing failed: \\(error.localizedDescription)"
                            self.stopVoiceTest()
                        }
                    }
                }
            }
        } catch {
            isTestingVoice = false
            voiceTestText = "Failed to start audio engine."
        }
    }
    
    private func stopVoiceTest() {
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        request.endAudio()
        task?.cancel()
        task = nil
    }"""

old_func_regex = re.compile(r'    private func startVoiceTest\(\) \{[\s\S]*?(?=\n\}\n\n// MARK: - Permission Window Manager)', re.DOTALL)
content = old_func_regex.sub(new_func, content)

# 4. Update the Stop button action to call stopVoiceTest() instead of SpeechRecognizer.shared.stopRecording()
content = content.replace("SpeechRecognizer.shared.stopRecording()", "stopVoiceTest()")

with open('/Users/aleksei/Documents/Scribe/Scribe/UI/PermissionView.swift', 'w') as f:
    f.write(content)
