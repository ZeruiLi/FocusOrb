import SwiftUI

struct GlassCard<Content: View>: View {
    let padding: CGFloat
    let content: Content

    init(padding: CGFloat = 16, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: AppTheme.Effects.cardRadius, style: .continuous)

        content
            .padding(padding)
            .background {
                ZStack {
                    shape.fill(AppTheme.Effects.cardMaterial)
                    shape
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.24),
                                    Color.white.opacity(0.08)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            }
            .clipShape(shape)
            .overlay(
                shape
                    .stroke(AppTheme.Colors.surfaceStroke, lineWidth: 1)
            )
            .overlay(
                shape
                    .stroke(Color.white.opacity(0.24), lineWidth: 0.5)
                    .blur(radius: 0.2)
            )
            .shadow(
                color: AppTheme.Effects.cardShadow.color,
                radius: AppTheme.Effects.cardShadow.radius,
                x: AppTheme.Effects.cardShadow.x,
                y: AppTheme.Effects.cardShadow.y
            )
    }
}
