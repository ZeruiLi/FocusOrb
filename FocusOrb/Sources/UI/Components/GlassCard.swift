import SwiftUI

struct GlassCard<Content: View>: View {
    let padding: CGFloat
    let content: Content

    init(padding: CGFloat = 16, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background(AppTheme.Effects.cardMaterial)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Effects.cardRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Effects.cardRadius, style: .continuous)
                    .stroke(AppTheme.Colors.surfaceStroke, lineWidth: 1)
            )
            .shadow(
                color: AppTheme.Effects.cardShadow.color,
                radius: AppTheme.Effects.cardShadow.radius,
                x: AppTheme.Effects.cardShadow.x,
                y: AppTheme.Effects.cardShadow.y
            )
    }
}

