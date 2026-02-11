import SwiftUI

struct OrbView: View {
    @ObservedObject var stateMachine: OrbStateMachine
    @ObservedObject var interactionState: OrbInteractionState
    @State private var glowPhase: CGFloat = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    private let orbSize = CGSize(width: 200, height: 170)
    private let cloudSize = CGSize(width: 150, height: 96)
    private let viewScale: CGFloat = 2.0 / 3.0

    var body: some View {
        ZStack {
            cloudGlow
            cloudBase
            cloudGlassHighlight

            if shouldShowFace {
                faceContent
                    .frame(width: scaledCloudSize.width, height: scaledCloudSize.height, alignment: .center)
                    .offset(y: faceYOffset)
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
                    .frame(width: scaledCloudSize.width, height: scaledCloudSize.height, alignment: .bottomTrailing)
                    .padding(.trailing, badgeTrailingPadding)
                    .padding(.bottom, badgeBottomPadding)
                    .allowsHitTesting(false)
            }

        }
        .frame(width: orbSize.width, height: orbSize.height)
        .background(Color.clear)
        .contentShape(Rectangle())
        .scaleEffect((interactionState.isPressed ? 0.94 : 1.0) * viewScale)
        .animation(.easeInOut(duration: 0.2), value: interactionState.isPressed)
        .frame(width: orbSize.width * viewScale, height: orbSize.height * viewScale)
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
            glowPhase = 0
            return
        }

        if animate {
            glowPhase = 0
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                glowPhase = 1
            }
        } else {
            withAnimation(.easeOut(duration: 0.25)) {
                glowPhase = 0
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

    enum FaceStyle {
        case smileEyes
        case slitEyes
        case none
    }

    struct ModeVisualToken {
        let hueColor: Color
        let textColor: Color
        let iconName: String
        let iconColor: Color
        let faceStyle: FaceStyle
        let glowMin: Double
        let glowMax: Double
        let glowRadiusMin: Double
        let glowRadiusMax: Double
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

    var focusToken: ModeVisualToken {
        let isDark = colorScheme == .dark
        return ModeVisualToken(
            hueColor: isDark
                ? Color(red: 52.0 / 255.0, green: 211.0 / 255.0, blue: 153.0 / 255.0)
                : Color(red: 16.0 / 255.0, green: 185.0 / 255.0, blue: 129.0 / 255.0),
            textColor: isDark
                ? Color.white.opacity(0.94)
                : Color(red: 0.10, green: 0.17, blue: 0.32),
            iconName: "leaf.fill",
            iconColor: Color(red: 0.07, green: 0.76, blue: 0.52),
            faceStyle: .smileEyes,
            glowMin: isDark ? 0.28 : 0.36,
            glowMax: isDark ? 0.58 : 0.82,
            glowRadiusMin: 14,
            glowRadiusMax: 30
        )
    }

    var breakToken: ModeVisualToken {
        let isDark = colorScheme == .dark
        return ModeVisualToken(
            hueColor: isDark
                ? Color(red: 251.0 / 255.0, green: 191.0 / 255.0, blue: 36.0 / 255.0)
                : AppTheme.Colors.warmOrange,
            textColor: Color.white.opacity(0.96),
            iconName: "cup.and.saucer.fill",
            iconColor: isDark
                ? Color(red: 253.0 / 255.0, green: 230.0 / 255.0, blue: 138.0 / 255.0)
                : Color(red: 146.0 / 255.0, green: 64.0 / 255.0, blue: 14.0 / 255.0),
            faceStyle: .slitEyes,
            glowMin: isDark ? 0.34 : 0.40,
            glowMax: isDark ? 0.70 : 0.88,
            glowRadiusMin: 16,
            glowRadiusMax: 34
        )
    }

    var sleepToken: ModeVisualToken {
        let isDark = colorScheme == .dark
        return ModeVisualToken(
            hueColor: isDark
                ? Color(red: 107.0 / 255.0, green: 114.0 / 255.0, blue: 128.0 / 255.0)
                : Color(red: 148.0 / 255.0, green: 163.0 / 255.0, blue: 184.0 / 255.0),
            textColor: isDark
                ? Color.white.opacity(0.94)
                : Color(red: 0.10, green: 0.17, blue: 0.32),
            iconName: "bed.double.fill",
            iconColor: isDark
                ? Color.white.opacity(0.56)
                : Color(red: 100.0 / 255.0, green: 116.0 / 255.0, blue: 139.0 / 255.0).opacity(0.72),
            faceStyle: .slitEyes,
            glowMin: isDark ? 0.14 : 0.18,
            glowMax: isDark ? 0.34 : 0.42,
            glowRadiusMin: 10,
            glowRadiusMax: 22
        )
    }

    var redPendingToken: ModeVisualToken {
        ModeVisualToken(
            hueColor: Color.orange,
            textColor: Color(red: 0.96, green: 0.72, blue: 0.46),
            iconName: "hourglass",
            iconColor: Color(red: 0.95, green: 0.62, blue: 0.24),
            faceStyle: .none,
            glowMin: 0.22,
            glowMax: 0.52,
            glowRadiusMin: 10,
            glowRadiusMax: 20
        )
    }

    var activeToken: ModeVisualToken? {
        switch visualState {
        case .focus, .focusIdleGradient:
            focusToken
        case .break:
            breakToken
        case .idle:
            sleepToken
        case .redPending:
            redPendingToken
        }
    }

    var badgeSymbolName: String? {
        activeToken?.iconName
    }

    var badgeColor: Color {
        activeToken?.iconColor ?? Color.gray
    }

    var badgeSize: CGFloat {
        visualState == .redPending ? 14 : 16
    }

    var badgeOpacity: Double {
        visualState == .redPending ? 0.90 : 0.96
    }

    var badgeTrailingPadding: CGFloat {
        scaledCloudSize.width * 0.053
    }

    var badgeBottomPadding: CGFloat {
        scaledCloudSize.height * 0.073
    }

    var shouldShowFace: Bool {
        guard let token = activeToken else { return false }
        return token.faceStyle != .none
    }

    var faceFeatureColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.55) : Color.black.opacity(0.34)
    }

    var faceYOffset: CGFloat {
        switch activeToken?.faceStyle {
        case .smileEyes:
            -scaledCloudSize.height * 0.19
        case .slitEyes:
            -scaledCloudSize.height * 0.17
        default:
            0
        }
    }

    @ViewBuilder
    var faceContent: some View {
        switch activeToken?.faceStyle {
        case .smileEyes:
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
        case .slitEyes:
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(red: 71.0 / 255.0, green: 85.0 / 255.0, blue: 105.0 / 255.0).opacity(0.60))
                    .frame(width: 14, height: 2.5)

                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(red: 71.0 / 255.0, green: 85.0 / 255.0, blue: 105.0 / 255.0).opacity(0.60))
                    .frame(width: 14, height: 2.5)
            }
        default:
            EmptyView()
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
            CloudSilhouetteShape()
                .fill(.ultraThinMaterial)
                .frame(width: scaledCloudSize.width, height: scaledCloudSize.height)
                .opacity(colorScheme == .dark ? 0.86 : 0.98)

            CloudSilhouetteShape()
                .fill(
                    LinearGradient(
                        colors: [
                            cloudGlassTopColor,
                            cloudGlassBottomColor
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
        }
        .frame(width: scaledCloudSize.width, height: scaledCloudSize.height)
        .compositingGroup()
        .frame(width: orbSize.width, height: orbSize.height)
        .allowsHitTesting(false)
    }

    var cloudGlassTopColor: Color {
        switch visualState {
        case .focus, .focusIdleGradient:
            return colorScheme == .dark
                ? Color(red: 0.20, green: 0.28, blue: 0.35)
                : Color(red: 0.98, green: 1.00, blue: 0.99)
        case .break:
            return colorScheme == .dark
                ? Color(red: 0.34, green: 0.24, blue: 0.12)
                : Color(red: 1.00, green: 0.97, blue: 0.90)
        case .idle:
            return colorScheme == .dark
                ? Color(red: 0.19, green: 0.21, blue: 0.25)
                : Color(red: 0.96, green: 0.97, blue: 0.98)
        case .redPending:
            return colorScheme == .dark
                ? Color(red: 0.30, green: 0.23, blue: 0.16)
                : Color(red: 1.00, green: 0.96, blue: 0.90)
        }
    }

    var cloudGlassBottomColor: Color {
        switch visualState {
        case .focus, .focusIdleGradient:
            return colorScheme == .dark
                ? Color(red: 0.14, green: 0.20, blue: 0.26)
                : Color(red: 0.94, green: 0.98, blue: 0.97)
        case .break:
            return colorScheme == .dark
                ? Color(red: 0.24, green: 0.16, blue: 0.08)
                : Color(red: 1.00, green: 0.90, blue: 0.74)
        case .idle:
            return colorScheme == .dark
                ? Color(red: 0.13, green: 0.15, blue: 0.18)
                : Color(red: 0.89, green: 0.92, blue: 0.95)
        case .redPending:
            return colorScheme == .dark
                ? Color(red: 0.22, green: 0.16, blue: 0.10)
                : Color(red: 0.99, green: 0.88, blue: 0.72)
        }
    }

    var cloudTintColor: Color {
        switch visualState {
        case .redPending:
            redPendingToken.hueColor
        default:
            activeToken?.hueColor ?? Color.gray
        }
    }

    var cloudTintTopOpacity: Double {
        switch visualState {
        case .focusIdleGradient:
            0.17
        case .focus:
            0.13
        case .break:
            0.38
        case .idle:
            0.16
        case .redPending:
            0.16
        }
    }

    var cloudTintMidOpacity: Double {
        switch visualState {
        case .focusIdleGradient:
            0.10
        case .focus:
            0.06
        case .break:
            0.24
        case .idle:
            0.10
        case .redPending:
            0.08
        }
    }

    var cloudGlassHighlight: some View {
        let topHighlightOpacity: Double
        let edgeHighlightOpacity: Double

        switch visualState {
        case .focusIdleGradient:
            topHighlightOpacity = 0.22
            edgeHighlightOpacity = 0.09
        case .focus:
            topHighlightOpacity = 0.20
            edgeHighlightOpacity = 0.08
        case .break:
            topHighlightOpacity = 0.14
            edgeHighlightOpacity = 0.05
        case .idle:
            topHighlightOpacity = 0.17
            edgeHighlightOpacity = 0.07
        case .redPending:
            topHighlightOpacity = 0.12
            edgeHighlightOpacity = 0.06
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
        if let token = activeToken {
            let progress = Double(max(0, min(1, glowPhase)))
            let opacity = shouldAnimateGlow ? lerp(token.glowMin, token.glowMax, progress) : token.glowMin
            let radius = (shouldAnimateGlow ? lerp(token.glowRadiusMin, token.glowRadiusMax, progress) : token.glowRadiusMin) * Double(glowScale)
            let innerOpacity = 0.08 + (opacity * 0.22)
            let edgeSoftness = 0.7 + (progress * 0.8)

            ZStack {
                CloudSilhouetteShape()
                    .fill(token.hueColor.opacity(innerOpacity))
                    .frame(width: scaledCloudSize.width, height: scaledCloudSize.height)
                    .blur(radius: edgeSoftness)
                    .mask(cloudMask)
                    .blendMode(.screen)

                CloudSilhouetteShape()
                    .fill(Color.white.opacity(0.012))
                    .frame(width: scaledCloudSize.width, height: scaledCloudSize.height)
                    .shadow(color: token.hueColor.opacity(opacity), radius: radius, x: 0, y: 0)
                    .shadow(color: token.hueColor.opacity(opacity * 0.58), radius: radius * 1.30, x: 0, y: 0)
                    .shadow(color: token.hueColor.opacity(opacity * 0.24), radius: radius * 1.75, x: 0, y: 0)
                    .blendMode(.plusLighter)
            }
            .frame(width: orbSize.width, height: orbSize.height)
            .allowsHitTesting(false)
        }
    }

    func lerp(_ minValue: Double, _ maxValue: Double, _ progress: Double) -> Double {
        minValue + ((maxValue - minValue) * progress)
    }

    var shouldShowTimeText: Bool {
        switch visualState {
        case .idle:
            false
        case .focus, .focusIdleGradient, .break, .redPending:
            true
        }
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
        switch visualState {
        case .redPending:
            .system(size: 32, weight: .bold, design: .rounded)
        case .focus, .focusIdleGradient, .break:
            .system(size: 34, weight: .bold, design: .rounded)
        case .idle:
            .system(size: 20, weight: .bold, design: .rounded)
        }
    }

    @ViewBuilder
    var timeContent: some View {
        if visualState == .redPending {
            SoftTimerText(
                text: timeText,
                font: timeFont,
                topColor: Color(red: 0.98, green: 0.76, blue: 0.52),
                bottomColor: Color(red: 0.93, green: 0.56, blue: 0.22),
                shadowColor: Color.black.opacity(0.24),
                monospacedDigits: true
            )
        } else if let token = activeToken {
            Text(timeText)
                .font(timeFont)
                .monospacedDigit()
                .tracking(-0.4)
                .foregroundStyle(token.textColor)
        }
    }

    var timeYOffset: CGFloat {
        switch visualState {
        case .redPending:
            scaledCloudSize.height * 0.085
        case .focus, .focusIdleGradient, .break:
            scaledCloudSize.height * 0.145
        case .idle:
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

    var glowScale: CGFloat {
        scaledCloudSize.width / cloudSize.width
    }

    func formatTime(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var shouldAnimateGlow: Bool {
        switch visualState {
        case .focus, .focusIdleGradient, .redPending, .break, .idle:
            true
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
