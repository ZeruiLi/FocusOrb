import SwiftUI

struct GlassCard<Content: View>: View {
    enum Variant {
        case hero
        case standard
        case subtle
    }

    let padding: CGFloat
    let variant: Variant
    let content: Content

    init(padding: CGFloat = 16, variant: Variant = .standard, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.variant = variant
        self.content = content()
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        content
            .padding(padding)
            .background {
                ZStack {
                    shape.fill(AppTheme.Effects.cardMaterial)
                    shape
                        .fill(
                            LinearGradient(
                                colors: gradientColors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            }
            .clipShape(shape)
            .overlay(
                shape
                    .stroke(strokeColor, lineWidth: 1)
            )
            .overlay(
                shape
                    .stroke(highlightStrokeColor, lineWidth: 0.6)
                    .blur(radius: 0.2)
            )
            .shadow(
                color: shadowPrimary.color,
                radius: shadowPrimary.radius,
                x: shadowPrimary.x,
                y: shadowPrimary.y
            )
            .shadow(
                color: shadowSecondary.color,
                radius: shadowSecondary.radius,
                x: shadowSecondary.x,
                y: shadowSecondary.y
            )
    }

    private var cornerRadius: CGFloat {
        switch variant {
        case .hero:
            return AppTheme.Effects.heroCardRadius
        case .standard:
            return AppTheme.Effects.cardRadius
        case .subtle:
            return AppTheme.Effects.subtleCardRadius
        }
    }

    private var gradientColors: [Color] {
        switch variant {
        case .hero:
            return [
                AppTheme.Colors.dashboardSurfaceStrong,
                AppTheme.Colors.dashboardSurface.opacity(0.94)
            ]
        case .standard:
            return [
                Color.white.opacity(0.24),
                Color.white.opacity(0.08)
            ]
        case .subtle:
            return [
                AppTheme.Colors.dashboardSurface,
                Color.white.opacity(0.34)
            ]
        }
    }

    private var strokeColor: Color {
        switch variant {
        case .hero:
            return AppTheme.Colors.dashboardSurfaceStroke
        case .standard:
            return AppTheme.Colors.surfaceStroke
        case .subtle:
            return AppTheme.Colors.dashboardSurfaceStroke.opacity(0.82)
        }
    }

    private var highlightStrokeColor: Color {
        switch variant {
        case .hero:
            return Color.white.opacity(0.82)
        case .standard:
            return Color.white.opacity(0.24)
        case .subtle:
            return Color.white.opacity(0.58)
        }
    }

    private var shadowPrimary: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
        switch variant {
        case .hero:
            return AppTheme.Effects.cardShadowLifted
        case .standard:
            return AppTheme.Effects.cardShadow
        case .subtle:
            return AppTheme.Effects.cardShadowSoft
        }
    }

    private var shadowSecondary: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
        switch variant {
        case .hero:
            return (Color.white.opacity(0.28), 12, 0, -3)
        case .standard:
            return (Color.clear, 0, 0, 0)
        case .subtle:
            return (Color.white.opacity(0.18), 8, 0, -2)
        }
    }
}
