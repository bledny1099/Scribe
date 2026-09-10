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
                        .font(.system(size: 13 * appState.overlayTextCompensation, weight: .semibold, design: .monospaced).monospacedDigit())
                        .foregroundStyle(.primary.opacity(0.85))
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
// MARK: - Waveform Visualizer State (Continuous 120/60 Hz Sub-Pixel Gliding)
// ============================================================================

final class WaveformVisualizerState {
    static let barCount = 52
    static let bufferCount = 56 // Extra bars to ensure seamless sub-pixel edge coverage
    static let barWidth: CGFloat = 3.2
    static let barSpacing: CGFloat = 2.4
    static var stride: CGFloat { barWidth + barSpacing } // 5.6 pt

    var levels: [Float] = Array(repeating: 0.025, count: 56)
    var scrollOffset: CGFloat = 0.0
    private var smoothedLevel: Float = 0.025
    private var lastFrameTime: CFTimeInterval = 0

    func reset() {
        levels = Array(repeating: 0.025, count: Self.bufferCount)
        scrollOffset = 0.0
        smoothedLevel = 0.025
        lastFrameTime = 0
    }

    func tick(currentLevel: Float, now: CFTimeInterval) {
        if lastFrameTime == 0 {
            lastFrameTime = now
            return
        }

        let dt = Float(min(0.05, max(0.001, now - lastFrameTime)))
        lastFrameTime = now

        let target = min(1.0, max(0.025, currentLevel))
        // Fast attack (instant responsiveness to speech onset), smooth exponential decay
        let rate: Float = target > smoothedLevel ? 32.0 : 12.0
        smoothedLevel += (target - smoothedLevel) * min(1.0, dt * rate)

        // Continuous sub-pixel scroll speed: 67.2 pt/s (12 bars/sec)
        let scrollSpeed: CGFloat = 67.2
        scrollOffset += CGFloat(dt) * scrollSpeed

        let barStride = Self.stride
        while scrollOffset >= barStride {
            scrollOffset -= barStride
            levels.removeFirst()
            // Organic micro-variation during vocalization gives life to the waveform
            let noise = (smoothedLevel > 0.06) ? Float.random(in: -0.025...0.025) * smoothedLevel : 0
            levels.append(min(1.0, max(0.025, smoothedLevel + noise)))
        }
    }
}

// ============================================================================
// MARK: - Transcribing Animation View (Neural Spinner + Shimmer + Liquid Wave Dots)
// ============================================================================

struct TranscribingAnimationView: View {
    @ObservedObject var appState: AppState
    let theme: AppTheme
    var fontSize: CGFloat = 13

    @State private var spinAngle: Double = 0
    @State private var sparkScale: CGFloat = 0.85
    @State private var pulseGlow: Bool = false

    var body: some View {
        HStack(spacing: 10) {
            // Neural Dual-Ring Glowing Spinner
            ZStack {
                Circle()
                    .fill(theme.glowColor.opacity(pulseGlow ? 0.35 : 0.12))
                    .frame(width: 24, height: 24)
                    .blur(radius: 5)

                // Outer clockwise orbit
                Circle()
                    .trim(from: 0.06, to: 0.82)
                    .stroke(
                        theme.accentGradient,
                        style: StrokeStyle(lineWidth: 2.2, lineCap: .round)
                    )
                    .frame(width: 20, height: 20)
                    .rotationEffect(.degrees(spinAngle))

                // Inner counter-clockwise orbit
                Circle()
                    .trim(from: 0.15, to: 0.68)
                    .stroke(
                        theme.gradientColors.last ?? .accentColor,
                        style: StrokeStyle(lineWidth: 1.6, lineCap: .round)
                    )
                    .frame(width: 12, height: 12)
                    .rotationEffect(.degrees(-spinAngle * 1.35))

                // Central pulsating energy core
                Circle()
                    .fill(theme.gradientColors.first ?? .accentColor)
                    .frame(width: 4, height: 4)
                    .scaleEffect(sparkScale)
            }
            .onAppear {
                withAnimation(.linear(duration: 1.3).repeatForever(autoreverses: false)) {
                    spinAngle = 360
                }
                withAnimation(.easeInOut(duration: 0.75).repeatForever(autoreverses: true)) {
                    sparkScale = 1.3
                    pulseGlow = true
                }
            }
            .onDisappear {
                spinAngle = 0
                sparkScale = 0.85
                pulseGlow = false
            }

            // Shimmering Liquid Label + Wave Bouncing Dots
            TimelineView(.animation) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let cycle = 1.8
                let normalized = (t.truncatingRemainder(dividingBy: cycle)) / cycle
                let shimmerPhase = CGFloat(normalized)

                let titleText = (appState.recordingStatus == .loadingModel)
                    ? appState.l("Loading model")
                    : appState.l("Transcribing")

                HStack(spacing: 5) {
                    Text(titleText)
                        .font(.system(size: fontSize, weight: .semibold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                stops: [
                                    .init(color: .primary.opacity(0.68), location: max(0, shimmerPhase - 0.25)),
                                    .init(color: theme.gradientColors.first ?? .white, location: shimmerPhase),
                                    .init(color: .primary.opacity(0.68), location: min(1, shimmerPhase + 0.25))
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .lineLimit(1)

                    // 3 Liquid wave-bouncing dots
                    HStack(spacing: 3.2) {
                        ForEach(0..<3) { i in
                            let phase = t * 4.8 - Double(i) * 0.7
                            let wave = sin(phase)
                            let yOffset = CGFloat(wave * 2.5)
                            let alpha = 0.35 + (wave + 1.0) * 0.325
                            let scale = 0.8 + (wave + 1.0) * 0.15

                            Circle()
                                .fill(theme.gradientColors[min(i, theme.gradientColors.count - 1)])
                                .frame(width: 3.6, height: 3.6)
                                .scaleEffect(scale)
                                .offset(y: -yOffset)
                                .opacity(alpha)
                        }
                    }
                }
            }
        }
    }
}


// ============================================================================
// MARK: - Waveform Overlay (Horizontal bar with audio bars)
// ============================================================================

struct WaveformOverlay: View {

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var audioRecorder: AudioRecorder

    @State private var visualizer = WaveformVisualizerState()
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
                if appState.recordingStatus == .transcribing || appState.recordingStatus == .loadingModel {
                    TranscribingAnimationView(appState: appState, theme: theme, fontSize: 13 * appState.overlayTextCompensation)
                        .padding(.horizontal, 14)
                        .frame(maxWidth: .infinity, maxHeight: cardHeight, alignment: .center)
                } else {
                    HStack(spacing: 8) {
                        statusIndicator

                        Text(statusLabel)
                            .font(.system(size: 13 * appState.overlayTextCompensation, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary.opacity(0.85))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 14)
                    .frame(maxWidth: .infinity, maxHeight: cardHeight, alignment: .center)
                }
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
                                .font(.system(size: 14, weight: .semibold, design: .rounded).monospacedDigit())
                                .foregroundStyle(.primary.opacity(0.85))
                                .frame(minWidth: 42, alignment: .center)
                        }

                        if appState.recordingStatus == .recording || appState.isShowingPreview {
                            Button(action: { appState.cancelRecording() }) {
                                Image(systemName: "stop.fill")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.primary.opacity(0.65))
                                    .frame(width: 28, height: 28)
                                    .background(Circle().fill(Color.primary.opacity(0.12)))
                            }
                            .buttonStyle(.plain)
                            .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .fixedSize(horizontal: true, vertical: false)
                    .frame(height: RecordingPanel.waveformSize.height)
                    .padding(.trailing, 20)
                    .animation(.easeInOut(duration: 0.2), value: appState.recordingStatus == .recording)
                }
                .frame(height: RecordingPanel.waveformSize.height)
            }
        }
        .padding(.leading, 6)
        .padding(.trailing, 10)
        .frame(
            width: cardWidth,
            height: cardHeight
        )
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: cardWidth)
        .onChange(of: appState.recordingStatus) { _, status in
            if status != .recording {
                visualizer.reset()
            }
        }
    }

    // MARK: - Waveform Bars

    private var waveformBars: some View {
        let isRunning = appState.recordingStatus == .recording || appState.isShowingPreview
        return TimelineView(.animation(paused: !isRunning)) { _ in
            Canvas { context, size in
                let now = CACurrentMediaTime()
                let currentLevel: Float
                if appState.isShowingPreview {
                    let t = Date().timeIntervalSinceReferenceDate
                    let sentenceCycle = t.truncatingRemainder(dividingBy: 4.8)
                    let isSpeaking = sentenceCycle < 3.4
                    let syllable = sin(t * 5.2) * cos(t * 2.6)
                    let modulation = 0.5 + 0.5 * sin(t * 1.6)

                    if isSpeaking {
                        let base = 0.18 + Float(modulation * 0.28)
                        let syllabicBurst = Float(max(0.0, syllable * 0.24))
                        currentLevel = min(0.78, base + syllabicBurst)
                    } else {
                        currentLevel = Float(max(0.02, 0.03 + 0.012 * sin(t * 2.0)))
                    }
                } else {
                    currentLevel = audioRecorder.audioLevel
                }

                visualizer.tick(currentLevel: currentLevel, now: now)

                let barWidth = WaveformVisualizerState.barWidth
                let barSpacing = WaveformVisualizerState.barSpacing
                let stride = WaveformVisualizerState.stride
                let minBarHeight: CGFloat = 3.6
                let maxBarHeight: CGFloat = min(44.0, size.height - 4.0)

                let totalBarsWidth = CGFloat(WaveformVisualizerState.barCount) * stride - barSpacing
                let startX = max(0, (size.width - totalBarsWidth) / 2)

                let colors = theme.gradientColors
                let baseColor1 = colors.first ?? Color.accentColor
                let baseColor2 = colors.count > 1 ? colors[1] : baseColor1

                // Clip drawing to avoid visual spill outside waveform bounds
                let clipRect = CGRect(x: startX, y: 0, width: totalBarsWidth, height: size.height)
                context.clip(to: Path(clipRect))

                let fadeDist: CGFloat = 16.0

                for i in 0..<visualizer.levels.count {
                    let x = startX + CGFloat(i) * stride - visualizer.scrollOffset
                    if x + barWidth < startX || x > startX + totalBarsWidth { continue }

                    let level = CGFloat(visualizer.levels[i])
                    let barHeight = minBarHeight + level * (maxBarHeight - minBarHeight)
                    let y = (size.height - barHeight) / 2
                    let barRect = CGRect(x: x, y: y, width: barWidth, height: barHeight)
                    let path = Path(roundedRect: barRect, cornerRadius: 1.6)

                    // Edge alpha fade for seamless entrance on right and exit on left
                    var edgeFade: CGFloat = 1.0
                    let distFromLeft = x - startX
                    let distFromRight = (startX + totalBarsWidth) - (x + barWidth)
                    if distFromLeft < fadeDist {
                        edgeFade = min(edgeFade, max(0.0, distFromLeft / fadeDist))
                    }
                    if distFromRight < fadeDist {
                        edgeFade = min(edgeFade, max(0.0, distFromRight / fadeDist))
                    }

                    let opacity = Double((0.35 + level * 0.65) * edgeFade)
                    let gradient = Gradient(colors: [
                        baseColor1.opacity(opacity),
                        baseColor2.opacity(opacity)
                    ])
                    context.fill(
                        path,
                        with: .linearGradient(
                            gradient,
                            startPoint: CGPoint(x: barRect.midX, y: barRect.maxY),
                            endPoint: CGPoint(x: barRect.midX, y: barRect.minY)
                        )
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: RecordingPanel.waveformSize.height)
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
                if appState.recordingStatus == .transcribing || appState.recordingStatus == .loadingModel {
                    TranscribingAnimationView(appState: appState, theme: theme, fontSize: 11 * appState.overlayTextCompensation)
                } else {
                    Circle()
                        .fill(theme.glowColor)
                        .frame(width: 10, height: 10)
                        .scaleEffect((appState.recordingStatus == .recording || appState.isShowingPreview) ? (1 + CGFloat(audioRecorder.audioLevel) * 0.4) : 1.0)
                        .opacity((appState.recordingStatus == .recording || appState.isShowingPreview) ? (0.6 + Double(audioRecorder.audioLevel) * 0.4) : 0.3)
                        .animation(.linear(duration: 0.04), value: audioRecorder.audioLevel)
                        
                    if appState.recordingStatus == .recording || appState.isShowingPreview {
                        if appState.durationVisible {
                            Text(appState.isShowingPreview ? "0:05" : appState.formattedDuration)
                                .font(.system(size: 13 * appState.overlayTextCompensation, weight: .semibold, design: .monospaced).monospacedDigit())
                                .foregroundStyle(.primary.opacity(0.85))
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
    @State private var spinAngle: Double = 0
    private var theme: AppTheme { appState.selectedTheme }

    var body: some View {
        let isStatusMessage = appState.recordingStatus != .recording && !appState.isShowingPreview && !statusLabel.isEmpty
        let dynamicSize = RecordingPanel.size(
            for: .ecg,
            overlaySize: appState.selectedOverlaySize,
            isStatusMessage: isStatusMessage,
            statusTextLength: statusLabel.count
        )
        let cardWidth = dynamicSize.width / appState.selectedOverlaySize.scale
        let cardHeight = dynamicSize.height / appState.selectedOverlaySize.scale

        return VStack(spacing: 8) {
            if isStatusMessage {
                if appState.recordingStatus == .transcribing || appState.recordingStatus == .loadingModel {
                    TranscribingAnimationView(appState: appState, theme: theme, fontSize: 13 * appState.overlayTextCompensation)
                        .padding(.horizontal, 14)
                        .frame(maxWidth: .infinity, maxHeight: cardHeight, alignment: .center)
                } else {
                    HStack(spacing: 8) {
                        statusIndicator

                        Text(statusLabel)
                            .font(.system(size: 13 * appState.overlayTextCompensation, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary.opacity(0.85))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 14)
                    .frame(maxWidth: .infinity, maxHeight: cardHeight, alignment: .center)
                }
            } else {
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
                                let isSpeaking = audioRecorder.audioLevel > 0.04
                                let amplitude: CGFloat = isSpeaking ? (isCenter ? (CGFloat(audioRecorder.audioLevel) * midY) : CGFloat.random(in: 0...2)) : 0
                                let y = midY + (i % 2 == 0 ? amplitude : -amplitude)
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                        .stroke(theme.accentGradient, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                        .animation(.linear(duration: 0.1), value: audioRecorder.audioLevel)
                    }
                    .frame(height: 30)
                    
                    if appState.durationVisible && (appState.recordingStatus == .recording || appState.isShowingPreview) {
                        Text(appState.isShowingPreview ? "0:05" : appState.formattedDuration)
                            .font(.system(size: 13 * appState.overlayTextCompensation, weight: .semibold, design: .monospaced).monospacedDigit())
                            .foregroundStyle(.primary.opacity(0.85))
                    }

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
        }
        .padding(.horizontal, 16)
        .frame(width: cardWidth, height: cardHeight)
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: cardWidth)
    }

    @ViewBuilder
    private var statusIndicator: some View {
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

    private var statusLabel: String {
        switch appState.recordingStatus {
        case .idle:              ""
        case .recording:         "Recording"
        case .loadingModel:      "Loading…"
        case .transcribing:      appState.transcribingStatusText
        case .done:              "Done ✓"
        case .error(let msg):    msg
        }
    }
}



// ============================================================================
// MARK: - Orb Overlay (Fluid Siri-style Bouncy Liquid Sphere)
// ============================================================================

struct OrbOverlay: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var audioRecorder: AudioRecorder
    @State private var spinAngle: Double = 0

    private var theme: AppTheme { appState.selectedTheme }
    private var gradient: LinearGradient { theme.accentGradient }

    var body: some View {
        let isStatusMessage = appState.recordingStatus != .recording && !appState.isShowingPreview && !statusLabel.isEmpty
        let dynamicSize = RecordingPanel.size(
            for: .orb,
            overlaySize: appState.selectedOverlaySize,
            isStatusMessage: isStatusMessage,
            statusTextLength: statusLabel.count
        )
        let cardWidth = dynamicSize.width / appState.selectedOverlaySize.scale
        let cardHeight = dynamicSize.height / appState.selectedOverlaySize.scale

        return VStack(spacing: 0) {
            if isStatusMessage {
                if appState.recordingStatus == .transcribing || appState.recordingStatus == .loadingModel {
                    TranscribingAnimationView(appState: appState, theme: theme, fontSize: 13 * appState.overlayTextCompensation)
                        .padding(.horizontal, 14)
                        .frame(maxWidth: .infinity, maxHeight: cardHeight, alignment: .center)
                } else {
                    HStack(spacing: 8) {
                        statusIndicator

                        Text(statusLabel)
                            .font(.system(size: 13 * appState.overlayTextCompensation, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary.opacity(0.85))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 14)
                    .frame(maxWidth: .infinity, maxHeight: cardHeight, alignment: .center)
                }
            } else {
                Spacer()

                // Fluid Liquid Orb Sphere with smooth GPU scaling
                ZStack {
                    // Outer fluid aura glow
                    Circle()
                        .fill(theme.glowColor.opacity(0.25 + Double(audioRecorder.audioLevel) * 0.35))
                        .frame(width: 88, height: 88)
                        .scaleEffect(1.0 + CGFloat(audioRecorder.audioLevel) * 0.25)

                    // Layer 1: Gradient Outer Ring
                    Circle()
                        .stroke(gradient, lineWidth: 3.5)
                        .frame(width: 76, height: 76)
                        .scaleEffect(1.0 + CGFloat(audioRecorder.audioLevel) * 0.15)
                        .opacity(0.9)

                    // Layer 2: Inner Fluid Sphere
                    Circle()
                        .fill(gradient.opacity(0.75))
                        .frame(width: 58, height: 58)
                        .scaleEffect(1.0 + CGFloat(audioRecorder.audioLevel) * 0.18)

                    // Center Mic Icon
                    Image(systemName: "mic.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.25), radius: 3)
                        .scaleEffect(1.0 + CGFloat(audioRecorder.audioLevel) * 0.1)
                }
                .animation(.linear(duration: 0.04), value: audioRecorder.audioLevel)
                .frame(width: 96, height: 96)

                Spacer()
                
                // Timer & Status Text
                HStack(spacing: 6) {
                    if appState.durationVisible && (appState.recordingStatus == .recording || appState.isShowingPreview) {
                        Text(appState.isShowingPreview ? "0:05" : appState.formattedDuration)
                            .font(.system(size: 13 * appState.overlayTextCompensation, weight: .semibold, design: .monospaced).monospacedDigit())
                            .foregroundStyle(.primary.opacity(0.85))
                    }

                    Text(appState.isShowingPreview ? appState.l("Recording…") : statusLabel)
                        .font(.system(size: 11 * appState.overlayTextCompensation, weight: .medium, design: .rounded))
                        .foregroundStyle(.primary.opacity(0.7))
                }
                .padding(.bottom, 12)
            }
        }
        .frame(width: cardWidth, height: cardHeight)
        .overlay(alignment: .topTrailing) {
            if !isStatusMessage {
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
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: cardWidth)
    }

    @ViewBuilder
    private var statusIndicator: some View {
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

struct SubtitleOverlayView: View {
    @EnvironmentObject var appState: AppState

    private var cornerRadius: CGFloat {
        max(22, round(24 * appState.selectedOverlaySize.scale))
    }

    var body: some View {
        VStack(spacing: 0) {
            if !appState.livePreviewText.isEmpty && (appState.recordingStatus == .recording || appState.recordingStatus == .transcribing || appState.isShowingPreview) {
                Text(appState.livePreviewText)
                    .font(.system(size: 13.5, weight: .medium, design: .rounded))
                    .foregroundStyle(appState.livePreviewBackground == .glass ? Color.primary : Color.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .shadow(color: appState.livePreviewBackground == .transparent ? Color.black.opacity(0.85) : Color.clear, radius: 3, x: 0, y: 1)
                    .background {
                        switch appState.livePreviewBackground {
                        case .dark:
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .fill(Color.black.opacity(0.82))
                                .overlay(
                                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                        .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.8)
                                )
                        case .glass:
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                        .fill(Color.white.opacity(0.15))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                        .strokeBorder(Color.white.opacity(0.3), lineWidth: 0.8)
                                )
                        case .transparent:
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .fill(Color.clear)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    .frame(maxWidth: 680)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    .animation(.easeInOut(duration: 0.2), value: appState.livePreviewText.isEmpty)
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
