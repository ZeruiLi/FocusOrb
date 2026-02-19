import SwiftUI

enum AppTheme {
    enum Colors {
        static let focusMint = Color(red: 0.0, green: 1.0, blue: 0.6)
        static let focusMintSoft = Color(red: 0.18, green: 0.86, blue: 0.70)
        static let focusTeal = Color(red: 0.12, green: 0.70, blue: 0.57)
        static let warmOrange = Color(red: 0.98, green: 0.67, blue: 0.32)
        static let warmAmber = Color(red: 0.93, green: 0.54, blue: 0.24)
        static let surfaceStroke = Color.white.opacity(0.16)
        static let panelStroke = Color.white.opacity(0.28)
        static let panelTop = Color(red: 0.95, green: 0.99, blue: 0.98)
        static let panelBottom = Color(red: 0.98, green: 0.95, blue: 0.91)
        static let panelGlowMint = focusMintSoft.opacity(0.26)
        static let panelGlowWarm = warmOrange.opacity(0.24)
        static let exportSurface = Color.white.opacity(0.62)
        static let exportSurfaceStrong = Color.white.opacity(0.72)
        static let exportSurfaceStroke = Color.white.opacity(0.42)
        static let textPrimary = Color.primary
        static let textSecondary = Color.secondary.opacity(0.84)
        static let textMuted = Color.secondary.opacity(0.68)
        static let exportTextPrimary = Color(red: 0.11, green: 0.16, blue: 0.23)
        static let exportTextSecondary = Color(red: 0.29, green: 0.36, blue: 0.43)
    }

    enum Typography {
        static let title = Font.system(.title2, design: .rounded).weight(.semibold)
        static let body = Font.system(.body, design: .rounded)
        static let caption = Font.system(.caption, design: .rounded)
        static let monospaced = Font.system(.title2, design: .rounded).monospacedDigit()
    }

    enum Effects {
        static let cardMaterial: Material = .regular
        static let cardRadius: CGFloat = 18
        static let panelRadius: CGFloat = 24
        static let exportRadius: CGFloat = 26
        static let cardShadow = (color: Color.black.opacity(0.10), radius: CGFloat(12), x: CGFloat(0), y: CGFloat(6))
        static let panelShadow = (color: Color.black.opacity(0.16), radius: CGFloat(22), x: CGFloat(0), y: CGFloat(14))
    }
}
