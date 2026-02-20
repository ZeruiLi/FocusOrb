import SwiftUI

struct DashboardHeroCard: View {
    let focusDuration: String
    let focusRatio: Double
    let dateRangeText: String
    let focusValue: String
    let breakValue: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let ringSize: CGFloat = 236
    private let ringLineWidth: CGFloat = 20

    private var clampedRatio: Double {
        min(max(focusRatio, 0), 1)
    }

    private var accentSegmentLength: Double {
        guard clampedRatio < 0.999 else { return 0 }
        return min(max((1 - clampedRatio) * 0.70, 0.018), 0.16)
    }

    private var durationFontSize: CGFloat {
        if focusDuration.count > 11 { return 40 }
        if focusDuration.count > 9 { return 46 }
        if focusDuration.count > 7 { return 52 }
        if focusDuration.count > 5 { return 58 }
        return 64
    }

    private var stackedDurationFontSize: CGFloat {
        if focusDuration.count > 11 { return 32 }
        if focusDuration.count > 9 { return 36 }
        if focusDuration.count > 7 { return 40 }
        if focusDuration.count > 5 { return 44 }
        return 48
    }

    private var hasCJKCharacters: Bool {
        focusDuration.unicodeScalars.contains { scalar in
            switch scalar.value {
            case 0x3400...0x4DBF, 0x4E00...0x9FFF, 0xF900...0xFAFF:
                return true
            default:
                return false
            }
        }
    }

    private var shouldStackDurationText: Bool {
        hasCJKCharacters && focusDuration.contains(" ") && focusDuration.count >= 8
    }

    private var durationDisplayText: String {
        guard shouldStackDurationText, let split = focusDuration.firstIndex(of: " ") else {
            return focusDuration
        }
        let firstLine = String(focusDuration[..<split])
        let secondLine = String(focusDuration[focusDuration.index(after: split)...])
        return "\(firstLine)\n\(secondLine)"
    }

    private var durationTextWidth: CGFloat {
        ringSize - ringLineWidth * 2 - 24
    }

    var body: some View {
        let cloudShape = DashboardHeroCloudShape()

        VStack(spacing: 16) {
            heroRing

            VStack(spacing: 4) {
                Text(L10n.string("看见节奏，而不是评判"))
                    .font(.headline)
                    .foregroundColor(AppTheme.Colors.dashboardTextPrimary)

                Text(dateRangeText)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(AppTheme.Colors.dashboardTextSecondary)
            }
            .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                summaryChip(
                    title: "专注",
                    value: focusValue,
                    tint: AppTheme.Colors.dashboardFocusDeep,
                    systemImage: "leaf.fill"
                )
                .frame(minWidth: 164)

                summaryChip(
                    title: "休息",
                    value: breakValue,
                    tint: AppTheme.Colors.dashboardBreak,
                    systemImage: "cup.and.saucer.fill"
                )
                .frame(minWidth: 164)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.top, 72)
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, minHeight: 448)
        .background {
            ZStack {
                cloudShape
                    .fill(AppTheme.Effects.cardMaterial)

                cloudShape
                    .fill(
                        LinearGradient(
                            colors: [
                                AppTheme.Colors.dashboardSurfaceStrong,
                                AppTheme.Colors.dashboardSurface.opacity(0.94)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        }
        .clipShape(cloudShape)
        .overlay(
            cloudShape
                .stroke(AppTheme.Colors.dashboardSurfaceStroke, lineWidth: 1)
        )
        .overlay(
            cloudShape
                .stroke(Color.white.opacity(0.82), lineWidth: 0.6)
                .blur(radius: 0.2)
        )
        .shadow(
            color: AppTheme.Effects.cardShadowLifted.color,
            radius: AppTheme.Effects.cardShadowLifted.radius,
            x: AppTheme.Effects.cardShadowLifted.x,
            y: AppTheme.Effects.cardShadowLifted.y
        )
        .shadow(
            color: Color.white.opacity(0.26),
            radius: 12,
            x: 0,
            y: -3
        )
    }

    private var heroRing: some View {
        let orangeEnd = 0.985
        let orangeStart = max(orangeEnd - accentSegmentLength, 0)

        return ZStack {
            Circle()
                .stroke(AppTheme.Colors.dashboardFocus.opacity(0.32), lineWidth: ringLineWidth + 2)
                .blur(radius: 10)

            Circle()
                .stroke(
                    AppTheme.Colors.dashboardSurfaceStroke.opacity(0.80),
                    style: StrokeStyle(lineWidth: ringLineWidth, lineCap: .round)
                )

            Circle()
                .stroke(
                    AngularGradient(
                        colors: [
                            AppTheme.Colors.dashboardFocusDeep,
                            AppTheme.Colors.dashboardFocus,
                            AppTheme.Colors.dashboardFocusDeep
                        ],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: ringLineWidth, lineCap: .round, lineJoin: .round)
                )

            if accentSegmentLength > 0 {
                Circle()
                    .trim(from: orangeStart, to: orangeEnd)
                    .stroke(
                        AngularGradient(
                            colors: [
                                AppTheme.Colors.dashboardBreak.opacity(0.97),
                                AppTheme.Colors.dashboardBreak.opacity(0.72)
                            ],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: ringLineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(
                        reduceMotion ? .none : .easeInOut(duration: 0.22),
                        value: accentSegmentLength
                    )
            }

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.88, green: 0.92, blue: 0.80).opacity(0.58),
                            Color.white.opacity(0.97)
                        ],
                        center: .center,
                        startRadius: 8,
                        endRadius: 110
                    )
                )
                .frame(width: ringSize - ringLineWidth * 2 - 8, height: ringSize - ringLineWidth * 2 - 8)

            VStack(spacing: 2) {
                Text(durationDisplayText)
                    .font(.system(size: shouldStackDurationText ? stackedDurationFontSize : durationFontSize, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundColor(AppTheme.Colors.dashboardFocusDeep)
                    .lineLimit(shouldStackDurationText ? 2 : 1)
                    .minimumScaleFactor(shouldStackDurationText ? 0.8 : 0.55)
                    .allowsTightening(true)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: durationTextWidth)
                    .fixedSize(horizontal: false, vertical: true)

                Text(L10n.string("专注时长"))
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(AppTheme.Colors.dashboardTextSecondary)
            }
        }
        .frame(width: ringSize, height: ringSize)
    }

    private func summaryChip(title: String, value: String, tint: Color, systemImage: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundColor(tint)

            Text(L10n.string(title))
                .font(.subheadline.weight(.medium))
                .foregroundColor(AppTheme.Colors.dashboardTextSecondary)

            Text(value)
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundColor(AppTheme.Colors.dashboardTextPrimary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(minHeight: 44)
        .background(AppTheme.Colors.dashboardSurfaceStrong)
        .clipShape(Capsule(style: .continuous))
        .overlay(
            Capsule(style: .continuous)
                .stroke(AppTheme.Colors.dashboardSurfaceStroke, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 3)
    }
}

private struct DashboardHeroCloudShape: Shape {
    func path(in rect: CGRect) -> Path {
        let minX = rect.minX
        let maxX = rect.maxX
        let minY = rect.minY
        let maxY = rect.maxY
        let width = rect.width
        let midX = rect.midX

        let cornerRadius = min(28, width * 0.06)
        let cloudBaseY = minY + min(max(rect.height * 0.14, 54), 70)

        let x1 = minX + width * 0.10
        let x2 = minX + width * 0.23
        let x3 = midX - width * 0.10
        let x4 = midX + width * 0.10
        let x5 = maxX - width * 0.23
        let x6 = maxX - width * 0.10

        var path = Path()
        path.move(to: CGPoint(x: minX + cornerRadius, y: cloudBaseY))
        path.addLine(to: CGPoint(x: x1, y: cloudBaseY))

        path.addQuadCurve(
            to: CGPoint(x: x2, y: cloudBaseY),
            control: CGPoint(x: (x1 + x2) * 0.5, y: cloudBaseY - 18)
        )
        path.addQuadCurve(
            to: CGPoint(x: x3, y: cloudBaseY),
            control: CGPoint(x: (x2 + x3) * 0.5, y: cloudBaseY - 28)
        )
        path.addQuadCurve(
            to: CGPoint(x: x4, y: cloudBaseY),
            control: CGPoint(x: midX, y: cloudBaseY - 36)
        )
        path.addQuadCurve(
            to: CGPoint(x: x5, y: cloudBaseY),
            control: CGPoint(x: (x4 + x5) * 0.5, y: cloudBaseY - 28)
        )
        path.addQuadCurve(
            to: CGPoint(x: x6, y: cloudBaseY),
            control: CGPoint(x: (x5 + x6) * 0.5, y: cloudBaseY - 18)
        )

        path.addLine(to: CGPoint(x: maxX - cornerRadius, y: cloudBaseY))
        path.addQuadCurve(
            to: CGPoint(x: maxX, y: cloudBaseY + cornerRadius),
            control: CGPoint(x: maxX, y: cloudBaseY)
        )
        path.addLine(to: CGPoint(x: maxX, y: maxY - cornerRadius))
        path.addQuadCurve(
            to: CGPoint(x: maxX - cornerRadius, y: maxY),
            control: CGPoint(x: maxX, y: maxY)
        )
        path.addLine(to: CGPoint(x: minX + cornerRadius, y: maxY))
        path.addQuadCurve(
            to: CGPoint(x: minX, y: maxY - cornerRadius),
            control: CGPoint(x: minX, y: maxY)
        )
        path.addLine(to: CGPoint(x: minX, y: cloudBaseY + cornerRadius))
        path.addQuadCurve(
            to: CGPoint(x: minX + cornerRadius, y: cloudBaseY),
            control: CGPoint(x: minX, y: cloudBaseY)
        )
        path.closeSubpath()
        return path
    }
}
