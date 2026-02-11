import SwiftUI

struct StartView: View {
    var onStart: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            StickerHeader(
                imageName: "focus",
                title: "FocusOrb",
                subtitle: "Find your flow.",
                style: .centered,
                iconSize: 48
            )

            GlassCard(padding: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Label("点击切换状态", systemImage: "hand.tap")
                        .font(AppTheme.Typography.body)
                    Label("长按结束本次", systemImage: "hand.press")
                        .font(AppTheme.Typography.body)
                    Label("绿色→橙色 3秒内可回滚", systemImage: "arrow.uturn.backward")
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                .foregroundColor(AppTheme.Colors.textPrimary)
            }

            PrimaryCapsuleButton(title: "Start Flow", systemImage: "play.fill", style: .focus) {
                onStart()
            }
        }
        .padding(24)
        .frame(width: 320, height: 300)
        .background(Material.regular)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Effects.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Effects.cardRadius, style: .continuous)
                .stroke(AppTheme.Colors.surfaceStroke, lineWidth: 1)
        )
    }
}
