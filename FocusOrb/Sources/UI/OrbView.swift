import SwiftUI

struct OrbView: View {
    @ObservedObject var stateMachine: OrbStateMachine

    @State private var isLongPressing = false
    @State private var glowPulse = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    let mintColor = Color(red: 0.0, green: 1.0, blue: 0.6)
    let coralColor = Color(red: 1.0, green: 0.5, blue: 0.5)

    private let orbSize = CGSize(width: 160, height: 140)
    private let cloudSize = CGSize(width: 150, height: 130)

    var body: some View {
        ZStack {
            if hasCloudAssets && visualState != .idle {
                cloudGlow
                cloudBase
                cloudGlassHighlight

                if shouldShowFocusFace {
                    focusFace
                        .frame(width: scaledCloudSize.width, height: scaledCloudSize.height, alignment: .center)
                        .offset(y: -3)
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
                        .shadow(color: Color.black.opacity(0.18), radius: 3, x: 0, y: 2)
                        .offset(y: timeYOffset)
                        .allowsHitTesting(false)
                }

                if let badgeName = badgeAssetName,
                   let badgeImage = BundledImage.swiftUIImage(named: badgeName, subdirectory: "Orb") {
                    badgeImage
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: badgeSize, height: badgeSize)
                        .opacity(badgeOpacity)
                        .shadow(color: Color.black.opacity(0.15), radius: 2, x: 0, y: 1)
                        .frame(width: orbSize.width, height: orbSize.height, alignment: .bottomTrailing)
                        .padding(.trailing, 10)
                        .padding(.bottom, 8)
                        .allowsHitTesting(false)
                }
            } else if hasCloudAssets == false {
                fallbackOrb
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

    private var coreColor: Color {
        switch stateMachine.currentState {
        case .green:
            mintColor
        case .redPending:
            Color.orange
        case .red:
            coralColor
        case .idle:
            Color.gray
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

    var hasCloudAssets: Bool {
        BundledImage.nsImage(named: cloudAssetName, subdirectory: "Orb") != nil
    }

    var cloudAssetName: String {
        switch visualState {
        case .idle:
            "sleep"
        case .break:
            "break"
        case .focus, .focusIdleGradient, .redPending:
            "focus"
        }
    }

    var badgeAssetName: String? {
        switch visualState {
        case .idle:
            nil
        case .focus, .focusIdleGradient:
            "tree"
        case .redPending:
            "cup"
        case .break:
            nil
        }
    }

    var badgeSize: CGFloat {
        switch visualState {
        case .focus, .focusIdleGradient:
            20
        case .redPending:
            24
        default:
            28
        }
    }

    var badgeOpacity: Double {
        switch visualState {
        case .focus:
            0.95
        case .focusIdleGradient:
            0.78
        case .redPending:
            0.55
        default:
            0.95
        }
    }

    var pendingToneOverlay: Color? {
        guard visualState == .redPending else { return nil }
        return Color.orange.opacity(0.18)
    }

    var cloudMask: some View {
        Group {
            if let image = BundledImage.swiftUIImage(named: cloudAssetName, subdirectory: "Orb") {
                image
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: scaledCloudSize.width, height: scaledCloudSize.height)
            } else {
                Rectangle().opacity(0)
            }
        }
    }

    var cloudBase: some View {
        ZStack {
            if let image = BundledImage.swiftUIImage(named: cloudAssetName, subdirectory: "Orb") {
                image
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: scaledCloudSize.width, height: scaledCloudSize.height)
                    .opacity(cloudBaseOpacity)
                    .compositingGroup()
                    .mask(cloudMask.scaleEffect(maskShrinkScale))
            }
        }
        .frame(width: orbSize.width, height: orbSize.height)
        .allowsHitTesting(false)
    }

    var cloudBaseOpacity: Double {
        switch visualState {
        case .focusIdleGradient:
            0.96
        case .redPending:
            0.9
        default:
            1.0
        }
    }

    var cloudGlassHighlight: some View {
        let topHighlightOpacity: Double
        let edgeHighlightOpacity: Double

        switch visualState {
        case .focus:
            topHighlightOpacity = 0.14
            edgeHighlightOpacity = 0.09
        case .focusIdleGradient:
            topHighlightOpacity = 0.17
            edgeHighlightOpacity = 0.11
        case .redPending:
            topHighlightOpacity = 0.08
            edgeHighlightOpacity = 0.05
        case .break:
            topHighlightOpacity = 0.06
            edgeHighlightOpacity = 0.04
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
        }
        .frame(width: orbSize.width, height: orbSize.height)
        .allowsHitTesting(false)
    }

    var cloudGlow: some View {
        let base = staticGlowOpacity
        let innerOpacity = shouldAnimateGlow ? (glowPulse ? 0.28 : 0.18) : base.inner
        let outerOpacity = shouldAnimateGlow ? (glowPulse ? 0.18 : 0.10) : base.outer

        return ZStack {
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

    var shouldShowFocusFace: Bool {
        visualState == .focus || visualState == .focusIdleGradient
    }

    var faceFeatureColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.56) : Color.black.opacity(0.42)
    }

    var focusFace: some View {
        VStack(spacing: 2) {
            HStack(spacing: 12) {
                Circle()
                    .fill(faceFeatureColor)
                    .frame(width: 4, height: 4)

                Circle()
                    .fill(faceFeatureColor)
                    .frame(width: 4, height: 4)
            }

            SmileShape()
                .stroke(
                    faceFeatureColor.opacity(colorScheme == .dark ? 0.95 : 0.82),
                    style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round)
                )
                .frame(width: 12, height: 6)
        }
        .padding(.top, 6)
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
        Group {
            if let zImage = BundledImage.swiftUIImage(named: "sleep", subdirectory: "Orb") {
                ZStack {
                    zImage
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 32, height: 32)
                        .offset(x: 10, y: -10)

                    zImage
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 26, height: 26)
                        .offset(x: -2, y: -2)

                    zImage
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 20, height: 20)
                        .offset(x: -12, y: 4)
                }
                .frame(width: orbSize.width, height: orbSize.height, alignment: .topTrailing)
                .padding(.trailing, 6)
                .padding(.top, 5)
            }
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
        switch stateMachine.currentState {
        case .redPending:
            .system(size: 36, weight: .heavy, design: .rounded)
        case .green, .red:
            .system(
                size: visualState == .break ? 32 : (visualState == .focus || visualState == .focusIdleGradient) ? 30 : 38,
                weight: .heavy,
                design: .rounded
            )
        case .idle:
            .system(size: 20, weight: .bold, design: .rounded)
        }
    }

    var timeContent: some View {
        Group {
            if visualState == .break, let cupImage = BundledImage.swiftUIImage(named: "cup", subdirectory: "Orb") {
                ZStack {
                    StrokedText(
                        text: timeText,
                        font: timeFont,
                        strokeColor: Color(red: 0.22, green: 0.12, blue: 0.05).opacity(0.7),
                        strokeWidth: 1.6,
                        fillColor: Color(red: 0.98, green: 0.67, blue: 0.32),
                        monospacedDigits: shouldUseMonospacedDigits
                    )
                    .padding(.trailing, 26)
                    .overlay(alignment: .trailing) {
                        cupImage
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 22, height: 22)
                            .offset(x: 0, y: 7)
                    }
                }
            } else if visualState == .focus || visualState == .focusIdleGradient {
                StrokedText(
                    text: timeText,
                    font: timeFont,
                    strokeColor: Color.black.opacity(0.35),
                    strokeWidth: 1.6,
                    fillColor: Color.white.opacity(0.98),
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
            8
        case .break, .redPending:
            0
        default:
            2
        }
    }

    var cloudScale: CGFloat {
        switch visualState {
        case .focus, .focusIdleGradient, .redPending:
            1.06
        default:
            1.0
        }
    }

    var scaledCloudSize: CGSize {
        CGSize(width: cloudSize.width * cloudScale, height: cloudSize.height * cloudScale)
    }

    var maskShrinkScale: CGFloat {
        switch visualState {
        case .focus, .focusIdleGradient, .redPending:
            0.992
        default:
            1.0
        }
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
        case .focus, .focusIdleGradient, .redPending:
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
            (0.16, 0.10)
        case .focus:
            (0.16, 0.10)
        case .focusIdleGradient:
            (0.18, 0.11)
        case .redPending:
            (0.14, 0.08)
        }
    }

    var fallbackOrb: some View {
        ZStack {
            Circle()
                .fill(coreColor)
                .frame(width: 58, height: 58)
                .blur(radius: 10)
                .opacity(0.35)

            Circle()
                .fill(coreColor.opacity(0.5))
                .frame(width: 54, height: 54)

            if shouldShowTimeText {
                StrokedText(
                    text: timeText,
                    font: timeFont,
                    strokeColor: Color.black.opacity(0.38),
                    strokeWidth: 1.4,
                    fillColor: Color.white.opacity(0.95),
                    monospacedDigits: shouldUseMonospacedDigits
                )
                .shadow(radius: 2)
            }
        }
        .frame(width: orbSize.width, height: orbSize.height)
        .allowsHitTesting(false)
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
