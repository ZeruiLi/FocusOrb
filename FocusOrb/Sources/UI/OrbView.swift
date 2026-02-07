import SwiftUI

struct OrbView: View {
    @ObservedObject var stateMachine: OrbStateMachine

    @State private var isLongPressing = false
    @State private var glowPulse = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    let mintColor = Color(red: 0.0, green: 1.0, blue: 0.6)
    private let orbSize = CGSize(width: 160, height: 140)
    private let cloudSize = CGSize(width: 150, height: 96)

    var body: some View {
        ZStack {
            cloudGlow
            cloudBase
            cloudGlassHighlight

            if shouldShowFocusFace {
                focusFace
                    .frame(width: scaledCloudSize.width, height: scaledCloudSize.height, alignment: .center)
                    .offset(y: -18)
                    .allowsHitTesting(false)
            }

            if shouldShowRestFace {
                restFace
                    .frame(width: scaledCloudSize.width, height: scaledCloudSize.height, alignment: .center)
                    .offset(y: -20)
                    .allowsHitTesting(false)
            }

            if shouldShowIdleFill {
                WaveFillView(progress: stateMachine.idleFillProgress)
                    .frame(width: scaledCloudSize.width, height: scaledCloudSize.height)
                    .opacity(0.32)
                    .blendMode(.overlay)
                    .mask(cloudMask)
                    .allowsHitTesting(false)
            }

            if let pendingTone = pendingToneOverlay {
                Rectangle()
                    .fill(pendingTone)
                    .frame(width: scaledCloudSize.width, height: scaledCloudSize.height)
                    .blendMode(.overlay)
                    .mask(cloudMask)
                    .allowsHitTesting(false)
            }

            if shouldShowTimeText {
                timeContent
                    .frame(width: scaledCloudSize.width, height: scaledCloudSize.height, alignment: .center)
                    .offset(y: timeYOffset)
                    .allowsHitTesting(false)
            }

            if let badgeSymbol = badgeSymbolName {
                Image(systemName: badgeSymbol)
                    .font(.system(size: badgeSize, weight: .bold, design: .rounded))
                    .foregroundStyle(badgeColor)
                    .opacity(badgeOpacity)
                    .shadow(color: Color.black.opacity(0.12), radius: 2, x: 0, y: 1)
                    .shadow(color: badgeColor.opacity(0.30), radius: 5, x: 0, y: 0)
                    .frame(width: orbSize.width, height: orbSize.height, alignment: .bottomTrailing)
                    .padding(.trailing, badgeTrailingPadding)
                    .padding(.bottom, badgeBottomPadding)
                    .allowsHitTesting(false)
            }

            if shouldShowSleepZ {
                sleepZOverlay
                    .allowsHitTesting(false)
            }
        }
        .frame(width: orbSize.width, height: orbSize.height)
        .background(Color.clear)
        .contentShape(Rectangle())
        .scaleEffect(isLongPressing ? 0.94 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isLongPressing)
        .gesture(
            LongPressGesture(minimumDuration: 0.8)
                .onChanged { _ in
                    isLongPressing = true
                }
                .onEnded { _ in
                    isLongPressing = false
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                        stateMachine.endSession()
                    }
                }
        )
        .simultaneousGesture(
            TapGesture()
                .onEnded {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                        stateMachine.handleClick()
                    }
                }
        )
        .onAppear {
            updateGlowAnimation(animate: shouldAnimateGlow)
        }
        .onChange(of: shouldAnimateGlow) { _, newValue in
            updateGlowAnimation(animate: newValue)
        }
    }

    private var shouldShowIdleFill: Bool {
        guard case .green = stateMachine.currentState else { return false }
        return stateMachine.idleFillProgress > 0
    }

    private func updateGlowAnimation(animate: Bool) {
        if reduceMotion {
            glowPulse = false
            return
        }

        if animate {
            glowPulse = false
            withAnimation(.easeInOut(duration: 4.0).repeatForever(autoreverses: true)) {
                glowPulse = true
            }
        } else {
            withAnimation(.easeOut(duration: 0.25)) {
                glowPulse = false
            }
        }
    }
}

private extension OrbView {
    enum VisualState: Equatable {
        case idle
        case focus
        case focusIdleGradient
        case redPending
        case `break`
    }

    var visualState: VisualState {
        switch stateMachine.currentState {
        case .idle:
            .idle
        case .green:
            shouldShowIdleFill ? .focusIdleGradient : .focus
        case .redPending:
            .redPending
        case .red:
            .break
        }
    }

    var badgeSymbolName: String? {
        switch visualState {
        case .idle:
            nil
        case .focus, .focusIdleGradient:
            "leaf.fill"
        case .redPending:
            "hourglass"
        case .break:
            "cup.and.saucer.fill"
        }
    }

    var badgeColor: Color {
        switch visualState {
        case .focus, .focusIdleGradient:
            Color(red: 0.07, green: 0.76, blue: 0.52)
        case .redPending:
            Color(red: 0.95, green: 0.62, blue: 0.24)
        case .break:
            Color(red: 245.0 / 255.0, green: 158.0 / 255.0, blue: 11.0 / 255.0)
        case .idle:
            Color.gray
        }
    }

    var badgeSize: CGFloat {
        switch visualState {
        case .focus, .focusIdleGradient:
            16
        case .redPending:
            14
        case .break:
            15
        default:
            16
        }
    }

    var badgeOpacity: Double {
        switch visualState {
        case .focus:
            0.98
        case .focusIdleGradient:
            0.9
        case .redPending:
            0.9
        default:
            0.92
        }
    }

    var badgeTrailingPadding: CGFloat {
        switch visualState {
        case .focus, .focusIdleGradient:
            22
        case .redPending:
            16
        case .break:
            10
        case .idle:
            12
        }
    }

    var badgeBottomPadding: CGFloat {
        switch visualState {
        case .focus, .focusIdleGradient:
            16
        case .redPending:
            12
        case .break:
            25
        case .idle:
            9
        }
    }

    var shouldShowFocusFace: Bool {
        visualState == .focus || visualState == .focusIdleGradient
    }

    var shouldShowRestFace: Bool {
        visualState == .break
    }

    var faceFeatureColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.55) : Color.black.opacity(0.34)
    }

    var focusFace: some View {
        VStack(spacing: 2) {
            HStack(spacing: 10) {
                Circle()
                    .fill(faceFeatureColor)
                    .frame(width: 4, height: 4)

                Circle()
                    .fill(faceFeatureColor)
                    .frame(width: 4, height: 4)
            }

            SmileShape()
                .stroke(
                    faceFeatureColor.opacity(colorScheme == .dark ? 0.92 : 0.75),
                    style: StrokeStyle(lineWidth: 1.7, lineCap: .round, lineJoin: .round)
                )
                .frame(width: 12, height: 6)
        }
    }

    var restFace: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(red: 71.0 / 255.0, green: 85.0 / 255.0, blue: 105.0 / 255.0).opacity(0.60))
                .frame(width: 14, height: 2.5)

            RoundedRectangle(cornerRadius: 2)
                .fill(Color(red: 71.0 / 255.0, green: 85.0 / 255.0, blue: 105.0 / 255.0).opacity(0.60))
                .frame(width: 14, height: 2.5)
        }
    }

    var pendingToneOverlay: Color? {
        guard visualState == .redPending else { return nil }
        return Color.orange.opacity(0.18)
    }

    var cloudMask: some View {
        CloudSilhouetteShape()
            .fill(Color.white)
            .frame(width: scaledCloudSize.width, height: scaledCloudSize.height)
    }

    var cloudBase: some View {
        ZStack {
            // Use union silhouette for a single material fill so overlaps do not form seams.
            CloudSilhouetteShape()
                .fill(.ultraThinMaterial)
                .frame(width: scaledCloudSize.width, height: scaledCloudSize.height)
                .opacity(colorScheme == .dark ? 0.86 : 0.98)

            CloudSilhouetteShape()
                .fill(
                    LinearGradient(
                        colors: [
                            cloudGlassTopColor.opacity(cloudBaseOpacity),
                            cloudGlassBottomColor.opacity(cloudBaseOpacity)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: scaledCloudSize.width, height: scaledCloudSize.height)

            CloudSilhouetteShape()
                .fill(
                    LinearGradient(
                        colors: [
                            cloudTintColor.opacity(cloudTintTopOpacity),
                            cloudTintColor.opacity(cloudTintMidOpacity),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: scaledCloudSize.width, height: scaledCloudSize.height)
                .blendMode(.overlay)

            if visualState == .break {
                CloudSilhouetteShape()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 251.0 / 255.0, green: 191.0 / 255.0, blue: 36.0 / 255.0).opacity(0.30),
                                Color(red: 251.0 / 255.0, green: 191.0 / 255.0, blue: 36.0 / 255.0).opacity(0.16),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 2,
                            endRadius: scaledCloudSize.width * 0.62
                        )
                    )
                    .frame(width: scaledCloudSize.width, height: scaledCloudSize.height)
                    .blendMode(.softLight)
            }

            // No geometry stroke here: avoid exposing internal construction outlines.
        }
        .frame(width: scaledCloudSize.width, height: scaledCloudSize.height)
        .compositingGroup()
        .frame(width: orbSize.width, height: orbSize.height)
        .allowsHitTesting(false)
    }

    var cloudGlassTopColor: Color {
        switch colorScheme {
        case .dark:
            return Color(red: 0.20, green: 0.28, blue: 0.35)
        default:
            if visualState == .break {
                return Color.white
            }
            return Color(red: 0.98, green: 1.00, blue: 0.99)
        }
    }

    var cloudGlassBottomColor: Color {
        switch colorScheme {
        case .dark:
            return Color(red: 0.14, green: 0.20, blue: 0.26)
        default:
            if visualState == .break {
                return Color(red: 0.98, green: 0.99, blue: 0.98)
            }
            return Color(red: 0.93, green: 0.99, blue: 0.97)
        }
    }

    var cloudTintColor: Color {
        switch visualState {
        case .focus, .focusIdleGradient:
            return mintColor
        case .redPending:
            return Color.orange
        case .break:
            return Color(red: 251.0 / 255.0, green: 191.0 / 255.0, blue: 36.0 / 255.0)
        case .idle:
            return Color.gray
        }
    }

    var cloudTintTopOpacity: Double {
        switch visualState {
        case .focus:
            0.12
        case .focusIdleGradient:
            0.14
        case .redPending:
            0.16
        case .break:
            0.26
        case .idle:
            0.08
        }
    }

    var cloudTintMidOpacity: Double {
        switch visualState {
        case .focus:
            0.05
        case .focusIdleGradient:
            0.07
        case .redPending:
            0.08
        case .break:
            0.16
        case .idle:
            0.03
        }
    }

    var cloudBaseOpacity: Double {
        switch visualState {
        case .focusIdleGradient:
            1.0
        case .redPending:
            0.98
        default:
            1.0
        }
    }

    var cloudGlassHighlight: some View {
        let topHighlightOpacity: Double
        let edgeHighlightOpacity: Double

        switch visualState {
        case .focus:
            topHighlightOpacity = 0.18
            edgeHighlightOpacity = 0.07
        case .focusIdleGradient:
            topHighlightOpacity = 0.22
            edgeHighlightOpacity = 0.09
        case .redPending:
            topHighlightOpacity = 0.12
            edgeHighlightOpacity = 0.06
        case .break:
            topHighlightOpacity = 0.16
            edgeHighlightOpacity = 0.08
        case .idle:
            topHighlightOpacity = 0
            edgeHighlightOpacity = 0
        }

        return ZStack {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(topHighlightOpacity),
                            Color.white.opacity(topHighlightOpacity * 0.38),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: scaledCloudSize.width, height: scaledCloudSize.height)
                .mask(cloudMask)

            Rectangle()
                .fill(Color.white.opacity(edgeHighlightOpacity))
                .frame(width: scaledCloudSize.width, height: scaledCloudSize.height)
                .mask(cloudMask)
                .blur(radius: 0.8)
                .offset(x: -1.4, y: -1.2)
                .blendMode(.screen)

            Ellipse()
                .fill(Color.white.opacity(topHighlightOpacity * 0.55))
                .frame(width: scaledCloudSize.width * 0.42, height: scaledCloudSize.height * 0.22)
                .offset(x: -scaledCloudSize.width * 0.12, y: -scaledCloudSize.height * 0.20)
                .blur(radius: 1.2)
                .mask(cloudMask)
        }
        .frame(width: orbSize.width, height: orbSize.height)
        .allowsHitTesting(false)
    }

    @ViewBuilder
    var cloudGlow: some View {
        let scale = scaledCloudSize.width / 280.0

        if visualState == .focus || visualState == .focusIdleGradient {
            // Match HTML glow rhythm:
            // light: rgba(16,185,129,0.3~0.6), radius 15~35
            // dark:  rgba(52,211,153,0.15~0.35), radius 15~35
            let baseColor = colorScheme == .dark
                ? Color(red: 52.0 / 255.0, green: 211.0 / 255.0, blue: 153.0 / 255.0)
                : Color(red: 16.0 / 255.0, green: 185.0 / 255.0, blue: 129.0 / 255.0)
            // Increase pulse intensity so it remains visible on bright backgrounds.
            let minOpacity = colorScheme == .dark ? 0.24 : 0.48
            let maxOpacity = colorScheme == .dark ? 0.52 : 0.92
            let pulseOpacity = shouldAnimateGlow ? (glowPulse ? maxOpacity : minOpacity) : minOpacity
            let pulseRadius = shouldAnimateGlow ? (glowPulse ? 48.0 : 22.0) * scale : 22.0 * scale

            ZStack {
                CloudSilhouetteShape()
                    .fill(Color.white.opacity(0.012))
                    .frame(width: scaledCloudSize.width, height: scaledCloudSize.height)
                    .shadow(color: baseColor.opacity(pulseOpacity), radius: pulseRadius, x: 0, y: 0)
                    .shadow(color: baseColor.opacity(pulseOpacity * 0.62), radius: pulseRadius * 1.45, x: 0, y: 0)
                    .shadow(color: baseColor.opacity(pulseOpacity * 0.30), radius: pulseRadius * 2.10, x: 0, y: 0)
                    .blendMode(.plusLighter)
            }
            .frame(width: orbSize.width, height: orbSize.height)
            .allowsHitTesting(false)
        } else if visualState == .break {
            let warm = Color(red: 251.0 / 255.0, green: 191.0 / 255.0, blue: 36.0 / 255.0)
            let minOpacity = colorScheme == .dark ? 0.32 : 0.45
            let maxOpacity = colorScheme == .dark ? 0.60 : 0.86
            let pulseOpacity = shouldAnimateGlow ? (glowPulse ? maxOpacity : minOpacity) : minOpacity
            let minRadius = 24.0 * scale
            let maxRadius = 68.0 * scale
            let pulseRadius = shouldAnimateGlow ? (glowPulse ? maxRadius : minRadius) : minRadius
            let phase: CGFloat = shouldAnimateGlow ? (glowPulse ? 1.0 : 0.0) : 0.0
            let auraScale = 1.0 + (0.08 * phase)

            ZStack {
                // Strong, cloud-shaped breathing glow visible on white backgrounds.
                CloudSilhouetteShape()
                    .fill(warm.opacity(0.14 + (0.14 * phase)))
                    .frame(width: scaledCloudSize.width, height: scaledCloudSize.height)
                    .scaleEffect(auraScale)
                    .blur(radius: 4.0 + (4.0 * phase))
                    .shadow(color: warm.opacity(pulseOpacity), radius: pulseRadius, x: 0, y: 18 * scale)
                    .shadow(color: warm.opacity(pulseOpacity * 0.62), radius: pulseRadius * 0.68, x: 0, y: 10 * scale)
                    .shadow(color: warm.opacity(pulseOpacity * 0.34), radius: pulseRadius * 0.38, x: 0, y: 4 * scale)

                CloudSilhouetteShape()
                    .fill(warm.opacity(0.10 + (0.12 * phase)))
                    .frame(width: scaledCloudSize.width * 1.06, height: scaledCloudSize.height * 1.06)
                    .blur(radius: 12.0 + (8.0 * phase))
                    .shadow(color: warm.opacity(pulseOpacity * 0.56), radius: pulseRadius * 1.25, x: 0, y: 0)
            }
            .frame(width: orbSize.width, height: orbSize.height)
            .allowsHitTesting(false)
        } else {
            let base = staticGlowOpacity
            let innerOpacity = shouldAnimateGlow ? (glowPulse ? 0.18 : 0.12) : base.inner
            let outerOpacity = shouldAnimateGlow ? (glowPulse ? 0.10 : 0.05) : base.outer

            ZStack {
                Rectangle()
                    .fill(glowColor)
                    .frame(width: scaledCloudSize.width, height: scaledCloudSize.height)
                    .mask(cloudMask)
                    .blur(radius: 10)
                    .opacity(innerOpacity)

                Rectangle()
                    .fill(glowColor)
                    .frame(width: scaledCloudSize.width, height: scaledCloudSize.height)
                    .mask(cloudMask)
                    .blur(radius: 18)
                    .opacity(outerOpacity)
            }
            .frame(width: orbSize.width, height: orbSize.height)
            .allowsHitTesting(false)
        }
    }

    var shouldShowTimeText: Bool {
        switch visualState {
        case .idle:
            false
        case .focus, .focusIdleGradient, .break, .redPending:
            true
        }
    }

    var shouldShowSleepZ: Bool {
        visualState == .idle
    }

    var sleepZOverlay: some View {
        ZStack {
            Text("Z")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.84))
                .offset(x: 12, y: -10)

            Text("z")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.70))
                .offset(x: 1, y: -2)

            Text("z")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.52))
                .offset(x: -10, y: 4)
        }
        .frame(width: orbSize.width, height: orbSize.height, alignment: .topTrailing)
        .padding(.trailing, 7)
        .padding(.top, 6)
    }

    var timeText: String {
        switch stateMachine.currentState {
        case .redPending(_, let remaining):
            String(format: "%.0f", ceil(remaining))
        case .green, .red:
            formatTime(stateMachine.currentSessionDuration)
        case .idle:
            ""
        }
    }

    var timeFont: Font {
        switch stateMachine.currentState {
        case .redPending:
            .system(size: 32, weight: .bold, design: .rounded)
        case .green, .red:
            .system(
                size: visualState == .break ? 34 : (visualState == .focus || visualState == .focusIdleGradient) ? 34 : 34,
                weight: .bold,
                design: .rounded
            )
        case .idle:
            .system(size: 20, weight: .bold, design: .rounded)
        }
    }

    var timeContent: some View {
        Group {
            if visualState == .break {
                Text(timeText)
                    .font(timeFont)
                    .monospacedDigit()
                    .tracking(-0.4)
                    .foregroundStyle(Color(red: 51.0 / 255.0, green: 65.0 / 255.0, blue: 85.0 / 255.0))
            } else if visualState == .focus || visualState == .focusIdleGradient {
                if shouldUseMonospacedDigits {
                    Text(timeText)
                        .font(timeFont)
                        .monospacedDigit()
                        .tracking(-0.4)
                        .foregroundStyle(
                            colorScheme == .dark
                                ? Color.white.opacity(0.94)
                                : Color(red: 0.10, green: 0.17, blue: 0.32)
                        )
                } else {
                    Text(timeText)
                        .font(timeFont)
                        .tracking(-0.4)
                        .foregroundStyle(
                            colorScheme == .dark
                                ? Color.white.opacity(0.94)
                                : Color(red: 0.10, green: 0.17, blue: 0.32)
                        )
                }
            } else if visualState == .redPending {
                SoftTimerText(
                    text: timeText,
                    font: timeFont,
                    topColor: Color(red: 0.98, green: 0.76, blue: 0.52),
                    bottomColor: Color(red: 0.93, green: 0.56, blue: 0.22),
                    shadowColor: Color.black.opacity(0.24),
                    monospacedDigits: shouldUseMonospacedDigits
                )
            } else {
                StrokedText(
                    text: timeText,
                    font: timeFont,
                    strokeColor: Color.black.opacity(0.38),
                    strokeWidth: 1.4,
                    fillColor: Color.white.opacity(0.95),
                    monospacedDigits: shouldUseMonospacedDigits
                )
            }
        }
    }

    var timeYOffset: CGFloat {
        switch visualState {
        case .focus, .focusIdleGradient:
            14
        case .break:
            12
        case .redPending:
            8
        default:
            2
        }
    }

    var cloudScale: CGFloat {
        switch visualState {
        case .redPending:
            1.02
        default:
            1.0
        }
    }

    var scaledCloudSize: CGSize {
        CGSize(width: cloudSize.width * cloudScale, height: cloudSize.height * cloudScale)
    }

    var shouldUseMonospacedDigits: Bool {
        switch stateMachine.currentState {
        case .idle:
            false
        case .green, .red, .redPending:
            true
        }
    }

    func formatTime(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var warmOrange: Color {
        Color(red: 0.98, green: 0.67, blue: 0.32)
    }

    var glowColor: Color {
        switch visualState {
        case .focus, .focusIdleGradient:
            mintColor
        case .break, .redPending:
            warmOrange
        case .idle:
            Color.clear
        }
    }

    var shouldAnimateGlow: Bool {
        switch visualState {
        case .focus, .focusIdleGradient, .redPending, .break:
            true
        default:
            false
        }
    }

    var staticGlowOpacity: (inner: Double, outer: Double) {
        switch visualState {
        case .idle:
            (0, 0)
        case .break:
            (0.12, 0.07)
        case .focus:
            (0.11, 0.05)
        case .focusIdleGradient:
            (0.13, 0.06)
        case .redPending:
            (0.12, 0.07)
        }
    }

}

private struct CloudSilhouetteShape: Shape {
    func path(in rect: CGRect) -> Path {
        // Geometry mapped 1:1 from the provided HTML:
        // container: 280x180
        // puff1: left 40, top 20, size 110x110
        // puff2: right 40, top 10, size 130x130 (=> x 110)
        // base:  bottom 0, size 280x100, radius 50
        var path = Path()
        let width = rect.width
        let height = rect.height

        let baseY = height * (80.0 / 180.0)
        let baseHeight = height - baseY
        let baseCorner = min(baseHeight * 0.5, width * (50.0 / 280.0))
        path.addRoundedRect(
            in: CGRect(x: 0, y: baseY, width: width, height: baseHeight),
            cornerSize: CGSize(width: baseCorner, height: baseCorner)
        )

        path.addEllipse(in: CGRect(
            x: width * (40.0 / 280.0),
            y: height * (20.0 / 180.0),
            width: width * (110.0 / 280.0),
            height: height * (110.0 / 180.0)
        ))

        path.addEllipse(in: CGRect(
            x: width * (110.0 / 280.0),
            y: height * (10.0 / 180.0),
            width: width * (130.0 / 280.0),
            height: height * (130.0 / 180.0)
        ))

        return path
    }
}

private struct SmileShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + 1))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + 1),
            control: CGPoint(x: rect.midX, y: rect.maxY)
        )
        return path
    }
}

private struct SoftTimerText: View {
    let text: String
    let font: Font
    let topColor: Color
    let bottomColor: Color
    let shadowColor: Color
    let monospacedDigits: Bool

    var body: some View {
        ZStack {
            textLayer(shadowColor)
                .blur(radius: 1.0)
                .offset(y: 1.0)
                .opacity(0.65)

            textLayer(Color.white.opacity(0.56))
                .blur(radius: 0.2)
                .offset(y: -0.5)

            textLayer(
                LinearGradient(
                    colors: [topColor, bottomColor],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }

    @ViewBuilder
    private func textLayer(_ color: Color) -> some View {
        if monospacedDigits {
            Text(text)
                .font(font)
                .monospacedDigit()
                .foregroundColor(color)
        } else {
            Text(text)
                .font(font)
                .foregroundColor(color)
        }
    }

    @ViewBuilder
    private func textLayer(_ gradient: LinearGradient) -> some View {
        if monospacedDigits {
            Text(text)
                .font(font)
                .monospacedDigit()
                .foregroundStyle(gradient)
        } else {
            Text(text)
                .font(font)
                .foregroundStyle(gradient)
        }
    }
}

private struct StrokedText: View {
    let text: String
    let font: Font
    let strokeColor: Color
    let strokeWidth: CGFloat
    let fillColor: Color
    let monospacedDigits: Bool

    var body: some View {
        ZStack {
            ForEach(offsets.indices, id: \.self) { index in
                let offset = offsets[index]
                if monospacedDigits {
                    Text(text)
                        .font(font)
                        .monospacedDigit()
                        .foregroundColor(strokeColor)
                        .offset(x: offset.x, y: offset.y)
                } else {
                    Text(text)
                        .font(font)
                        .foregroundColor(strokeColor)
                        .offset(x: offset.x, y: offset.y)
                }
            }
            if monospacedDigits {
                Text(text)
                    .font(font)
                    .monospacedDigit()
                    .foregroundColor(fillColor)
            } else {
                Text(text)
                    .font(font)
                    .foregroundColor(fillColor)
            }
        }
    }

    private var offsets: [CGPoint] {
        let w = strokeWidth
        return [
            CGPoint(x: -w, y: 0),
            CGPoint(x: w, y: 0),
            CGPoint(x: 0, y: -w),
            CGPoint(x: 0, y: w),
            CGPoint(x: -w, y: -w),
            CGPoint(x: w, y: -w),
            CGPoint(x: -w, y: w),
            CGPoint(x: w, y: w)
        ]
    }
}

private struct WaveFillView: View {
    let progress: Double

    @State private var phase: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let amplitude: CGFloat = 6
    private let wavelength: CGFloat = 44

    var body: some View {
        ZStack {
            WaveShape(progress: progress, phase: phase, amplitude: amplitude, wavelength: wavelength)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.22, green: 0.92, blue: 1.0).opacity(0.32),
                            Color(red: 0.18, green: 0.70, blue: 0.98).opacity(0.28),
                            Color(red: 0.12, green: 0.45, blue: 0.95).opacity(0.22)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            WaveShape(progress: progress, phase: phase + 0.45, amplitude: amplitude * 0.55, wavelength: wavelength * 0.8)
                .fill(Color.white.opacity(0.12))
                .blendMode(.screen)

            WaveLineShape(progress: progress, phase: phase + 0.1, amplitude: amplitude * 0.8, wavelength: wavelength)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.75),
                            Color(red: 0.65, green: 0.95, blue: 1.0).opacity(0.35),
                            Color.white.opacity(0.05)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round)
                )
                .blur(radius: 0.4)
                .opacity(0.7)
                .blendMode(.screen)
        }
        .animation(reduceMotion ? .none : .easeInOut(duration: 0.35), value: progress)
        .onAppear {
            phase = 0
            if reduceMotion {
                phase = 0.2
            } else {
                withAnimation(.linear(duration: 1.6).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
        }
    }
}

private struct WaveShape: Shape {
    var progress: Double
    var phase: CGFloat
    var amplitude: CGFloat
    var wavelength: CGFloat

    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let clamped = min(max(progress, 0), 1)
        let waterlineY = rect.maxY - (CGFloat(clamped) * rect.height)
        let angular = phase * 2 * .pi

        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: waterlineY))

        let step: CGFloat = 1.5
        var x: CGFloat = rect.minX
        while x <= rect.maxX + step {
            let relativeX = (x - rect.minX) / wavelength
            let y = waterlineY + sin((relativeX * 2 * .pi) + angular) * amplitude
            path.addLine(to: CGPoint(x: x, y: y))
            x += step
        }

        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct WaveLineShape: Shape {
    var progress: Double
    var phase: CGFloat
    var amplitude: CGFloat
    var wavelength: CGFloat

    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let clamped = min(max(progress, 0), 1)
        let waterlineY = rect.maxY - (CGFloat(clamped) * rect.height)
        let angular = phase * 2 * .pi

        var path = Path()
        let step: CGFloat = 1.5
        var x: CGFloat = rect.minX
        var isFirst = true

        while x <= rect.maxX + step {
            let relativeX = (x - rect.minX) / wavelength
            let y = waterlineY + sin((relativeX * 2 * .pi) + angular) * amplitude
            if isFirst {
                path.move(to: CGPoint(x: x, y: y))
                isFirst = false
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
            x += step
        }

        return path
    }
}
