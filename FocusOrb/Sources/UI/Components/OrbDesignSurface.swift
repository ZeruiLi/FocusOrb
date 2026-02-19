import SwiftUI

struct OrbAmbientCanvas: View {
    var body: some View {
        LinearGradient(
            colors: [AppTheme.Colors.panelTop, AppTheme.Colors.panelBottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(alignment: .topLeading) {
            Circle()
                .fill(AppTheme.Colors.panelGlowMint)
                .frame(width: 180, height: 180)
                .blur(radius: 24)
                .offset(x: -54, y: -58)
        }
        .overlay(alignment: .bottomTrailing) {
            Circle()
                .fill(AppTheme.Colors.panelGlowWarm)
                .frame(width: 220, height: 220)
                .blur(radius: 30)
                .offset(x: 66, y: 62)
        }
    }
}

struct OrbPanelContainer<Content: View>: View {
    let padding: CGFloat
    let content: Content

    init(padding: CGFloat = 20, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: AppTheme.Effects.panelRadius, style: .continuous)
                        .fill(AppTheme.Effects.cardMaterial)
                    OrbAmbientCanvas()
                        .opacity(0.84)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Effects.panelRadius, style: .continuous))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Effects.panelRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Effects.panelRadius, style: .continuous)
                    .stroke(AppTheme.Colors.panelStroke, lineWidth: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Effects.panelRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.34), lineWidth: 0.6)
                    .blur(radius: 0.2)
            )
            .shadow(
                color: AppTheme.Effects.panelShadow.color,
                radius: AppTheme.Effects.panelShadow.radius,
                x: AppTheme.Effects.panelShadow.x,
                y: AppTheme.Effects.panelShadow.y
            )
    }
}

struct OrbExportBackground: View {
    let cornerRadius: CGFloat

    init(cornerRadius: CGFloat = AppTheme.Effects.exportRadius) {
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        AppTheme.Colors.panelTop,
                        AppTheme.Colors.panelTop.opacity(0.96),
                        AppTheme.Colors.panelBottom
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                ZStack {
                    Circle()
                        .fill(AppTheme.Colors.panelGlowMint)
                        .frame(width: 240, height: 240)
                        .blur(radius: 34)
                        .offset(x: -176, y: -134)

                    Circle()
                        .fill(AppTheme.Colors.panelGlowWarm.opacity(0.92))
                        .frame(width: 280, height: 280)
                        .blur(radius: 40)
                        .offset(x: 178, y: 150)
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            }
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(AppTheme.Colors.exportSurfaceStroke, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.10), radius: 18, x: 0, y: 11)
    }
}

struct OrbExportSurface<Content: View>: View {
    let padding: CGFloat
    let cornerRadius: CGFloat
    let emphasized: Bool
    let content: Content

    init(
        padding: CGFloat = 12,
        cornerRadius: CGFloat = 16,
        emphasized: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.emphasized = emphasized
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(emphasized ? AppTheme.Colors.exportSurfaceStrong : AppTheme.Colors.exportSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(AppTheme.Colors.exportSurfaceStroke, lineWidth: 1)
            )
    }
}
