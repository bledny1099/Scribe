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
        let cardHeight = RecordingPanel.size(
            for: .classic,
            overlaySize: appState.selectedOverlaySize
        ).height / appState.selectedOverlaySize.scale

        return VStack(spacing: 10) {
            Spacer(minLength: 8)

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

            Spacer(minLength: 8)
        }
        .frame(width: RecordingPanel.classicSize.width, height: cardHeight)
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

    private let barCount = 44
    @State private var levels: [Float] = Array(repeating: 0, count: 44)
    @State private var spinAngle: Double = 0

    private var theme: AppTheme { appState.selectedTheme }

    var body: some View {
        let isEmbeddedActive = false
        let isAIModeActive = appState.enableCloudAI && appState.selectedAIRefinementMode != .raw && (appState.recordingStatus == .recording || appState.recordingStatus == .transcribing)
        let isStatusMessage = appState.recordingStatus != .recording && !appState.isShowingPreview && !statusLabel.isEmpty
        let effectiveAppName = appState.showTargetAppInOverlay ? ((appState.recordingStatus == .recording || appState.recordingStatus == .transcribing) ? appState.targetAppName : (appState.isShowingPreview ? "Scribe" : "")) : ""
        let isTimerVisible = appState.durationVisible && (appState.recordingStatus == .recording || appState.isShowingPreview)

        let dynamicSize = RecordingPanel.size(
            for: .waveform,
            overlaySize: appState.selectedOverlaySize,
            isEmbeddedPreviewActive: isEmbeddedActive,
            previewTextLength: appState.livePreviewText.count,
            targetAppName: effectiveAppName,
            isTimerVisible: isTimerVisible,
            hasAIMode: isAIModeActive,
            isStatusMessage: isStatusMessage,
            statusTextLength: statusLabel.count
        )
        let cardWidth = dynamicSize.width / appState.selectedOverlaySize.scale
        let cardHeight = dynamicSize.height / appState.selectedOverlaySize.scale

        return VStack(spacing: 8) {
            if isStatusMessage {
                HStack(spacing: 8) {
                    statusIndicator

                    Text(statusLabel)
                        .font(.system(size: 13 * appState.overlayTextCompensation, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary.opacity(0.85))
                        .lineLimit(1)
                }
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity, maxHeight: cardHeight, alignment: .center)
            } else {
                HStack(alignment: .center, spacing: 6) {
                    // Left: status indicator centered in the left cap area
                    ZStack(alignment: .center) {
                        statusIndicator
                    }
                    .frame(width: 36, height: RecordingPanel.waveformSize.height)
                    .padding(.leading, 12)

                    // Center: dynamically expanding waveform bars
                    waveformBars
                        .frame(maxWidth: .infinity, maxHeight: RecordingPanel.waveformSize.height)

                    // Right: status label + target app badge + timer + stop button
                    HStack(spacing: 10) {
                        if isAIModeActive {
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

                        if !effectiveAppName.isEmpty {
                            TargetAppBadgeView(
                                name: effectiveAppName,
                                icon: (appState.recordingStatus == .recording || appState.recordingStatus == .transcribing) ? appState.targetAppIcon : NSApp.applicationIconImage
                            )
                            .padding(.leading, 6)
                            .padding(.trailing, isTimerVisible ? 2 : 4)
                        }

                        if isTimerVisible {
                            Text(appState.isShowingPreview ? "0:05" : appState.formattedDuration)
                                .font(.system(size: 14, weight: .medium, design: .rounded).monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(minWidth: 42, alignment: .center)
                                .animation(.default, value: appState.recordingDuration)
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
                    .fixedSize(horizontal: true, vertical: false)
                    .frame(height: RecordingPanel.waveformSize.height)
                    .padding(.trailing, 12)
                    .animation(.easeInOut(duration: 0.2), value: appState.recordingStatus == .recording)
                }
                .frame(height: RecordingPanel.waveformSize.height)
            }
        }
        .padding(.horizontal, 6)
        .frame(
            width: cardWidth,
            height: cardHeight
        )
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: cardWidth)
        .onReceive(Timer.publish(every: 0.045, on: .main, in: .common).autoconnect()) { _ in
            if appState.isShowingPreview {
                let t = Date().timeIntervalSinceReferenceDate
                let simulated = Float(max(0.03, 0.38 + 0.32 * sin(t * 4.2) * cos(t * 2.1)))
                levels.removeFirst()
                levels.append(simulated)
            }
        }
        .onChange(of: audioRecorder.audioLevel) { _, newLevel in
            if !appState.isShowingPreview {
                levels.removeFirst()
                let amplified = min(1.0, max(0.0, newLevel * 1.3))
                levels.append(amplified)
            }
        }
    }

    // MARK: - Waveform Bars

    private var waveformBars: some View {
        HStack(alignment: .center, spacing: 2.2) {
            ForEach(0..<barCount, id: \.self) { i in
                let level = CGFloat(levels[i])
                let maxBarHeight: CGFloat = 44
                let minBarHeight: CGFloat = 3.5
                let barHeight = minBarHeight + level * (maxBarHeight - minBarHeight)

                RoundedRectangle(cornerRadius: 1.6)
                    .fill(barGradient(for: level))
                    .frame(width: 3.2, height: barHeight)
                    .animation(.spring(response: 0.12, dampingFraction: 0.72), value: levels[i])
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
        let cardHeight = RecordingPanel.size(
            for: .minimal,
            overlaySize: appState.selectedOverlaySize
        ).height / appState.selectedOverlaySize.scale

        return VStack(spacing: 4) {
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
            .frame(height: RecordingPanel.minimalSize.height)
        }
        .padding(.horizontal, 12)
        .frame(width: RecordingPanel.minimalSize.width, height: cardHeight)
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
        let cardHeight = RecordingPanel.size(
            for: .ecg,
            overlaySize: appState.selectedOverlaySize
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
        let cardHeight = RecordingPanel.size(
            for: .orb,
            overlaySize: appState.selectedOverlaySize
        ).height / appState.selectedOverlaySize.scale

        return VStack(spacing: 0) {
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
        .frame(width: RecordingPanel.orbSize.width, height: cardHeight)
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
                    .foregroundStyle(appState.livePreviewBackground == .dark ? Color.white : Color.primary)
                    .lineLimit(4)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 7)
                    .background {
                        if appState.livePreviewBackground == .dark {
                            Capsule()
                                .fill(Color.black.opacity(0.75))
                                .overlay(Capsule().strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5))
                        } else {
                            Capsule()
                                .fill(.ultraThinMaterial)
                                .overlay(Capsule().fill(Color.white.opacity(0.12)))
                                .overlay(Capsule().strokeBorder(Color.white.opacity(0.25), lineWidth: 0.5))
                        }
                    }
                    .clipShape(Capsule())
                    .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 3)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: appState.livePreviewText)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}

// MARK: - Target App Badge (Displays icon and name of application receiving transcription)
struct TargetAppBadgeView: View {
    let name: String
    let icon: NSImage?

    var body: some View {
        HStack(spacing: 6) {
            if let icon = icon {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 15, height: 15)
                    .cornerRadius(3.5)
            }
            Text(name)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.primary.opacity(0.9))
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(Color.primary.opacity(0.09))
        )
        .overlay(
            Capsule()
                .strokeBorder(Color.primary.opacity(0.16), lineWidth: 0.8)
        )
        .frame(maxWidth: 220)
    }
}
