import SwiftUI

/// Recording overlay that switches between Classic and Waveform layouts.
struct RecordingOverlayView: View {

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var audioRecorder: AudioRecorder

    var body: some View {
        Group {
            switch appState.selectedOverlayStyle {
            case .classic:
                ClassicOverlay().environmentObject(appState).environmentObject(audioRecorder)
            case .waveform:
                WaveformOverlay().environmentObject(appState).environmentObject(audioRecorder)
            case .minimal:
                MinimalOverlay().environmentObject(appState).environmentObject(audioRecorder)
            case .ecg:
                ECGOverlay().environmentObject(appState).environmentObject(audioRecorder)
            case .orb:
                OrbOverlay().environmentObject(appState).environmentObject(audioRecorder)
            }
        }
        .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 6)
    }
}

// ============================================================================
// MARK: - Classic Overlay (Original square with concentric rings)
// ============================================================================

struct ClassicOverlay: View {

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var audioRecorder: AudioRecorder
    @State private var spinAngle: Double = 0
    @State private var orbitAngle: Double = 0

    private var theme: AppTheme { appState.selectedTheme }
    private var gradient: LinearGradient { theme.accentGradient }
    private var glow: Color { theme.glowColor }

    var body: some View {
        VStack(spacing: 12) {
            Spacer(minLength: 12)

            ZStack {
                // Radial glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                glow.opacity(0.15),
                                Color.clear,
                            ],
                            center: .center,
                            startRadius: 15,
                            endRadius: 85
                        )
                    )
                    .frame(width: 170, height: 170)
                    .blur(radius: 14)

                // Outer ring
                Circle()
                    .stroke(gradient, lineWidth: 1.5)
                    .frame(width: 100, height: 100)
                    .scaleEffect(1 + CGFloat(audioRecorder.audioLevel) * 0.25)
                    .opacity(0.25 + Double(audioRecorder.audioLevel) * 0.55)

                // Middle ring
                Circle()
                    .stroke(gradient, lineWidth: 2)
                    .frame(width: 72, height: 72)
                    .scaleEffect(1 + CGFloat(audioRecorder.audioLevel) * 0.18)
                    .opacity(0.35 + Double(audioRecorder.audioLevel) * 0.45)

                // Inner ring
                Circle()
                    .stroke(gradient, lineWidth: 2.5)
                    .frame(width: 50, height: 50)
                    .scaleEffect(1 + CGFloat(audioRecorder.audioLevel) * 0.1)
                    .opacity(0.45 + Double(audioRecorder.audioLevel) * 0.35)

                // Centre disc
                Circle()
                    .fill(gradient.opacity(0.12))
                    .frame(width: 42, height: 42)

                // Status icon
                classicStatusIcon
            }
            .animation(.linear(duration: 0.04), value: audioRecorder.audioLevel)

            HStack(spacing: 6) {
                if appState.durationVisible && (appState.recordingStatus == .recording || appState.isShowingPreview) {
                    Text(appState.isShowingPreview ? "0:05" : appState.formattedDuration)
                        .font(.system(size: 13 * appState.overlayTextCompensation, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                        .animation(.default, value: appState.recordingDuration)
                }

                Text(appState.isShowingPreview ? appState.l("Recording…") : statusLabel)
                    .font(.system(size: 11 * appState.overlayTextCompensation, weight: .medium, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.7))
            }

            Spacer(minLength: 12)
        }
        .frame(width: RecordingPanel.classicSize.width, height: RecordingPanel.classicSize.height)
        .overlay(alignment: .topTrailing) {
            Button(action: { appState.cancelRecording() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.primary.opacity(0.6))
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(Color.primary.opacity(0.15)))
            }
            .buttonStyle(.plain)
            .opacity((appState.recordingStatus == .recording || appState.isShowingPreview) ? 1 : 0)
            .padding(.top, 12)
            .padding(.trailing, 12)
        }
        .onAppear {
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                orbitAngle = 360
            }
        }
    }

    @ViewBuilder
    private var classicStatusIcon: some View {
        if appState.isShowingPreview || appState.recordingStatus == .recording {
            Image(systemName: "mic.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(gradient)
                .symbolEffect(.pulse, isActive: true)
        } else {
            switch appState.recordingStatus {
            case .loadingModel, .transcribing:
                ZStack {
                    Circle()
                        .trim(from: 0, to: 0.7)
                        .stroke(gradient, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: 30, height: 30)
                        .rotationEffect(.degrees(spinAngle))
                        .onAppear {
                            withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: false)) {
                                spinAngle = 360
                            }
                        }
                        .onDisappear { spinAngle = 0 }

                    Image(systemName: "brain")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(gradient)
                }

            case .done:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(.green.gradient)
                    .transition(.scale.combined(with: .opacity))

            case .error:
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.orange.gradient)

            case .idle, .recording:
                EmptyView()
            }
        }
    }

    private var statusLabel: String {
        switch appState.recordingStatus {
        case .idle:              ""
        case .recording:         "Recording"
        case .loadingModel:      "Loading model"
        case .transcribing:      appState.transcribingStatusText
        case .done:              "Done ✓"
        case .error(let msg):    msg
        }
    }
}

// ============================================================================
// MARK: - Waveform Overlay (Horizontal bar with audio bars)
// ============================================================================

struct WaveformOverlay: View {

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var audioRecorder: AudioRecorder

    private let barCount = 48
    @State private var levels: [Float] = Array(repeating: 0, count: 48)
    @State private var spinAngle: Double = 0

    private var theme: AppTheme { appState.selectedTheme }

    var body: some View {
        let isEmbeddedActive = false
        let cardHeight = RecordingPanel.size(
            for: .waveform,
            overlaySize: appState.selectedOverlaySize,
            isEmbeddedPreviewActive: isEmbeddedActive,
            previewTextLength: appState.livePreviewText.count
        ).height / appState.selectedOverlaySize.scale

        return VStack(spacing: 8) {
            HStack(alignment: .center, spacing: 0) {
                // Left: status indicator
                statusIndicator
                    .frame(width: 48, height: RecordingPanel.waveformSize.height)

                // Center: waveform bars
                waveformBars
                    .frame(maxWidth: .infinity, maxHeight: RecordingPanel.waveformSize.height)

                // Right: status label + target app badge + stop button
                HStack(spacing: 8) {
                    if appState.enableCloudAI && appState.selectedAIRefinementMode != .raw && (appState.recordingStatus == .recording || appState.recordingStatus == .transcribing) {
                        HStack(spacing: 4) {
                            Image(systemName: appState.selectedAIRefinementMode.icon)
                                .font(.system(size: 10, weight: .bold))
                            Text(appState.selectedAIRefinementMode.displayName)
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(appState.selectedTheme.gradientColors.first!)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(appState.selectedTheme.gradientColors.first!.opacity(0.12))
                        .cornerRadius(6)
                    }

                    if !appState.targetAppName.isEmpty && (appState.recordingStatus == .recording || appState.recordingStatus == .transcribing) {
                        TargetAppBadgeView(name: appState.targetAppName, icon: appState.targetAppIcon)
                    }

                    if appState.durationVisible && (appState.recordingStatus == .recording || appState.isShowingPreview) {
                        Text(appState.isShowingPreview ? "0:05" : appState.formattedDuration)
                            .font(.system(size: 14, weight: .medium, design: .rounded).monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 42, alignment: .leading)
                            .animation(.default, value: appState.recordingDuration)
                    }

                    if appState.recordingStatus != .recording && !appState.isShowingPreview {
                        Text(statusLabel)
                            .font(.system(size: 11 * appState.overlayTextCompensation, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary.opacity(0.6))
                            .lineLimit(1)
                    }

                    if appState.recordingStatus == .recording || appState.isShowingPreview {
                        Button(action: { appState.cancelRecording() }) {
                            Image(systemName: "stop.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.primary.opacity(0.6))
                                .frame(width: 28, height: 28)
                                .background(Circle().fill(Color.primary.opacity(0.1)))
                        }
                        .buttonStyle(.plain)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .frame(width: 120, height: RecordingPanel.waveformSize.height)
                .animation(.easeInOut(duration: 0.2), value: appState.recordingStatus == .recording)
            }
            .frame(height: RecordingPanel.waveformSize.height)

            if isEmbeddedActive {
                Divider()
                    .background(Color.primary.opacity(0.15))
                    .padding(.horizontal, 14)

                Text(appState.livePreviewText)
                    .font(.system(size: 12 * appState.overlayTextCompensation, weight: .medium, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .padding(.horizontal, 12)
        .frame(
            width: RecordingPanel.waveformSize.width,
            height: cardHeight
        )
        .onChange(of: audioRecorder.audioLevel) { _, newLevel in
            levels.removeFirst()
            levels.append(newLevel)
        }
    }

    // MARK: - Waveform Bars

    private var waveformBars: some View {
        HStack(alignment: .center, spacing: 2) {
            ForEach(0..<barCount, id: \.self) { i in
                let level = CGFloat(levels[i])
                let maxBarHeight: CGFloat = 44
                let minBarHeight: CGFloat = 3
                let barHeight = minBarHeight + level * (maxBarHeight - minBarHeight)

                RoundedRectangle(cornerRadius: 1.5)
                    .fill(barGradient(for: level))
                    .frame(width: 3.5, height: barHeight)
                    .animation(.spring(response: 0.12, dampingFraction: 0.7), value: levels[i])
            }
        }
    }

    private func barGradient(for level: CGFloat) -> some ShapeStyle {
        let colors = theme.gradientColors
        let opacity = 0.3 + level * 0.7
        return LinearGradient(
            colors: [colors[0].opacity(opacity), colors[1].opacity(opacity)],
            startPoint: .bottom,
            endPoint: .top
        )
    }

    // MARK: - Status Indicator

    @ViewBuilder
    private var statusIndicator: some View {
        if appState.isShowingPreview || appState.recordingStatus == .recording {
            Circle()
                .fill(theme.gradientColors[1])
                .frame(width: 10, height: 10)
                .shadow(color: theme.gradientColors[1].opacity(0.6), radius: 6)
        } else {
            switch appState.recordingStatus {
            case .loadingModel, .transcribing:
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(
                        theme.accentGradient,
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                    )
                    .frame(width: 22, height: 22)
                    .rotationEffect(.degrees(spinAngle))
                    .onAppear {
                        withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: false)) {
                            spinAngle = 360
                        }
                    }
                    .onDisappear { spinAngle = 0 }

            case .done:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.green.gradient)

            case .error:
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.orange.gradient)

            case .idle, .recording:
                EmptyView()
            }
        }
    }

    private var statusLabel: String {
        switch appState.recordingStatus {
        case .idle:              ""
        case .recording:         "Recording…"
        case .loadingModel:      "Loading…"
        case .transcribing:      appState.transcribingStatusText
        case .done:              "Done ✓"
        case .error(let msg):    msg
        }
    }
}

// ============================================================================
// MARK: - New Overlays
// ============================================================================

struct MinimalOverlay: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var audioRecorder: AudioRecorder
    private var theme: AppTheme { appState.selectedTheme }
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(theme.glowColor)
                .frame(width: 10, height: 10)
                .scaleEffect((appState.recordingStatus == .recording || appState.isShowingPreview) ? (1 + CGFloat(audioRecorder.audioLevel) * 0.4) : 1.0)
                .opacity((appState.recordingStatus == .recording || appState.isShowingPreview) ? (0.6 + Double(audioRecorder.audioLevel) * 0.4) : 0.3)
                .animation(.linear(duration: 0.04), value: audioRecorder.audioLevel)
                
            if appState.recordingStatus == .recording || appState.isShowingPreview {
                if appState.durationVisible {
                    Text(appState.isShowingPreview ? "0:05" : appState.formattedDuration)
                        .font(.system(size: 13 * appState.overlayTextCompensation, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                } else {
                    Text(appState.isShowingPreview ? appState.l("Recording…") : statusLabel)
                        .font(.system(size: 11 * appState.overlayTextCompensation, weight: .medium, design: .rounded))
                        .foregroundStyle(.primary.opacity(0.7))
                }
            } else {
                Text(statusLabel)
                    .font(.system(size: 11 * appState.overlayTextCompensation, weight: .medium, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.7))
            }
            
            if appState.recordingStatus == .recording || appState.isShowingPreview {
                Button(action: { appState.cancelRecording() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.primary.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var statusLabel: String {
        switch appState.recordingStatus {
        case .idle: return ""
        case .loadingModel: return "Loading…"
        case .transcribing: return appState.transcribingStatusText
        case .done: return "Done ✓"
        case .error(let msg): return msg
        default: return ""
        }
    }
}


struct ECGOverlay: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var audioRecorder: AudioRecorder
    private var theme: AppTheme { appState.selectedTheme }
    
    var body: some View {
        let isEmbeddedActive = false
        let cardHeight = RecordingPanel.size(
            for: .ecg,
            overlaySize: appState.selectedOverlaySize,
            isEmbeddedPreviewActive: isEmbeddedActive,
            previewTextLength: appState.livePreviewText.count
        ).height / appState.selectedOverlaySize.scale

        return VStack(spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: "waveform.path.ecg")
                    .foregroundStyle(theme.accentGradient)
                    .font(.system(size: 16, weight: .semibold))
                    
                GeometryReader { geo in
                    Path { path in
                        let midY = geo.size.height / 2
                        path.move(to: CGPoint(x: 0, y: midY))
                        
                        let width = geo.size.width
                        let segments = 40
                        let step = width / CGFloat(segments)
                        
                        for i in 1...segments {
                            let x = CGFloat(i) * step
                            let isCenter = (i > 10 && i < 30)
                            let amplitude = isCenter ? (CGFloat(audioRecorder.audioLevel) * midY) : (CGFloat.random(in: 0...2))
                            let y = midY + (i % 2 == 0 ? amplitude : -amplitude)
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                    .stroke(theme.accentGradient, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    .animation(.linear(duration: 0.1), value: audioRecorder.audioLevel)
                }
                .frame(height: 30)
                
                if appState.recordingStatus == .recording || appState.isShowingPreview {
                    Button(action: { appState.cancelRecording() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 16))
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(height: RecordingPanel.ecgSize.height)

            if isEmbeddedActive {
                Divider()
                    .background(Color.primary.opacity(0.15))
                    .padding(.horizontal, 12)

                Text(appState.livePreviewText)
                    .font(.system(size: 11 * appState.overlayTextCompensation, weight: .medium, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .padding(.horizontal, 16)
        .frame(width: RecordingPanel.ecgSize.width, height: cardHeight)
    }
}



// ============================================================================
// MARK: - Orb Overlay (Fluid Siri-style Bouncy Liquid Sphere)
// ============================================================================

struct OrbOverlay: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var audioRecorder: AudioRecorder
    @State private var rotationAngle: Double = 0

    private var theme: AppTheme { appState.selectedTheme }
    private var gradient: LinearGradient { theme.accentGradient }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Bouncy Fluid Liquid Orb Sphere
            ZStack {
                // Outer fluid aura glow
                Circle()
                    .fill(theme.glowColor.opacity(0.3 + Double(audioRecorder.audioLevel) * 0.45))
                    .blur(radius: 16)
                    .scaleEffect(1.0 + CGFloat(audioRecorder.audioLevel) * 0.35)

                // Layer 1: Rotating Gradient Ring
                Circle()
                    .stroke(gradient, lineWidth: 5)
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(rotationAngle))
                    .scaleEffect(1.0 + CGFloat(audioRecorder.audioLevel) * 0.2)
                    .opacity(0.85)

                // Layer 2: Inner Fluid Blob Sphere
                Circle()
                    .fill(gradient.opacity(0.75))
                    .frame(width: 64, height: 64)
                    .scaleEffect(1.0 + CGFloat(audioRecorder.audioLevel) * 0.25)

                // Center Mic Icon
                Image(systemName: "mic.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.3), radius: 4)
                    .scaleEffect(1.0 + CGFloat(audioRecorder.audioLevel) * 0.15)
            }
            .animation(.linear(duration: 0.04), value: audioRecorder.audioLevel)
            .frame(width: 96, height: 96)

            Spacer()
            
            // Timer & Status Text
            HStack(spacing: 6) {
                if appState.durationVisible && (appState.recordingStatus == .recording || appState.isShowingPreview) {
                    Text(appState.isShowingPreview ? "0:05" : appState.formattedDuration)
                        .font(.system(size: 13 * appState.overlayTextCompensation, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                        .animation(.default, value: appState.recordingDuration)
                }

                Text(appState.isShowingPreview ? appState.l("Recording…") : statusLabel)
                    .font(.system(size: 11 * appState.overlayTextCompensation, weight: .medium, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.7))
            }
            .padding(.bottom, 12)
        }
        .frame(width: RecordingPanel.orbSize.width, height: RecordingPanel.orbSize.height)
        .overlay(alignment: .topTrailing) {
            Button(action: { appState.cancelRecording() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.primary.opacity(0.6))
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(Color.primary.opacity(0.15)))
            }
            .buttonStyle(.plain)
            .opacity((appState.recordingStatus == .recording || appState.isShowingPreview) ? 1 : 0)
            .padding(.top, 12)
            .padding(.trailing, 12)
        }
        .onAppear {
            withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) {
                rotationAngle = 360
            }
        }
    }

    private var statusLabel: String {
        switch appState.recordingStatus {
        case .idle:              ""
        case .recording:         "Recording"
        case .loadingModel:      "Loading model"
        case .transcribing:      appState.transcribingStatusText
        case .done:              "Done ✓"
        case .error(let msg):    msg
        }
    }
}

/// A floating view to display live transcription preview below the main recording panel.
struct SubtitleOverlayView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack {
            if !appState.livePreviewText.isEmpty && (appState.recordingStatus == .recording || appState.isShowingPreview) {
                Text(appState.livePreviewText)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(4)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        ZStack {
                            Capsule()
                                .fill(Color.black.opacity(0.4))
                                .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1))
                                .opacity(appState.livePreviewBackground == .dark ? 1 : 0)

                            Capsule()
                                .fill(Color.primary.opacity(0.1))
                                .background(.ultraThinMaterial, in: Capsule())
                                .overlay(Capsule().stroke(Color.primary.opacity(0.15), lineWidth: 1))
                                .opacity(appState.livePreviewBackground == .glass ? 1 : 0)
                        }
                    )
                    .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: appState.livePreviewText)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

// MARK: - Target App Badge (Displays icon and name of application receiving transcription)
struct TargetAppBadgeView: View {
    let name: String
    let icon: NSImage?

    var body: some View {
        HStack(spacing: 5) {
            if let icon = icon {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 14, height: 14)
                    .cornerRadius(3)
            }
            Text(name)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary.opacity(0.85))
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color.primary.opacity(0.08))
        )
        .overlay(
            Capsule()
                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5)
        )
    }
}
