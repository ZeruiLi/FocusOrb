import SwiftUI

enum AppTheme {
    enum Colors {
        // Existing palette (shared across non-dashboard surfaces)
        static let focusMint = Color(red: 0.0, green: 1.0, blue: 0.6)
        static let focusMintSoft = Color(red: 0.18, green: 0.86, blue: 0.70)
        static let focusTeal = Color(red: 0.12, green: 0.70, blue: 0.57)
        static let warmOrange = Color(red: 0.98, green: 0.67, blue: 0.32)
        static let warmAmber = Color(red: 0.93, green: 0.54, blue: 0.24)

        // Dashboard vNext palette (soft neumorphism + calm minimal)
        static let dashboardFocus = Color(red: 0.27, green: 0.84, blue: 0.55)      // #45D78C
        static let dashboardFocusDeep = Color(red: 0.18, green: 0.56, blue: 0.58)  // #2F8E95
        static let dashboardBreak = Color(red: 0.95, green: 0.60, blue: 0.29)      // #F39A4A
        static let dashboardBackgroundTop = Color(red: 0.96, green: 0.97, blue: 0.95)   // #F5F6F3
        static let dashboardBackgroundBottom = Color.white
        static let dashboardTextPrimary = Color(red: 0.12, green: 0.17, blue: 0.16)     // #1E2C2A
        static let dashboardTextSecondary = Color(red: 0.33, green: 0.42, blue: 0.41)   // #536C69
        static let dashboardSurface = Color.white.opacity(0.74)
        static let dashboardSurfaceStrong = Color.white.opacity(0.88)
        static let dashboardSurfaceStroke = Color.white.opacity(0.68)
        static let dashboardDivider = Color(red: 0.86, green: 0.89, blue: 0.87)
        static let dashboardHeroGlow = dashboardFocus.opacity(0.22)
        static let dashboardHeroGlowWarm = dashboardBreak.opacity(0.20)

        // Capture vNext palette (desktop high-fidelity)
        static let captureBackgroundTop = Color(red: 0.96, green: 0.97, blue: 0.95)
        static let captureBackgroundBottom = Color.white
        static let captureSurface = Color.white.opacity(0.74)
        static let captureSurfaceStrong = Color.white.opacity(0.90)
        static let captureSurfaceStroke = Color.white.opacity(0.72)
        static let captureInset = Color(red: 0.93, green: 0.94, blue: 0.92)
        static let captureInsetStroke = Color.white.opacity(0.82)
        static let captureTextPrimary = Color(red: 0.16, green: 0.17, blue: 0.17)
        static let captureTextSecondary = Color(red: 0.53, green: 0.54, blue: 0.52)
        static let captureTextMuted = Color(red: 0.66, green: 0.67, blue: 0.65)
        static let captureMintActive = Color(red: 0.70, green: 0.95, blue: 0.86)
        static let captureMintDeep = Color(red: 0.15, green: 0.54, blue: 0.50)
        static let captureMintGlow = Color(red: 0.56, green: 0.92, blue: 0.80).opacity(0.56)
        static let captureDivider = Color(red: 0.84, green: 0.85, blue: 0.83)
        static let captureDanger = Color(red: 0.87, green: 0.37, blue: 0.36)
        static let captureCloudInk = Color(red: 0.80, green: 0.80, blue: 0.78)
        static let captureRowSeparator = Color(red: 0.84, green: 0.84, blue: 0.82).opacity(0.78)
        static let captureIconMuted = Color(red: 0.65, green: 0.66, blue: 0.64)
        static let captureEditorSurface = Color.white.opacity(0.92)
        static let captureEditorLine = Color(red: 0.78, green: 0.79, blue: 0.77)
        static let captureActionTeal = Color(red: 0.25, green: 0.61, blue: 0.61)

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
        static let subtleCardRadius: CGFloat = 16
        static let heroCardRadius: CGFloat = 24
        static let panelRadius: CGFloat = 24
        static let exportRadius: CGFloat = 26
        static let cardShadow = (color: Color.black.opacity(0.10), radius: CGFloat(12), x: CGFloat(0), y: CGFloat(6))
        static let cardShadowSoft = (color: Color.black.opacity(0.06), radius: CGFloat(10), x: CGFloat(0), y: CGFloat(4))
        static let cardShadowLifted = (color: Color.black.opacity(0.10), radius: CGFloat(20), x: CGFloat(0), y: CGFloat(10))
        static let panelShadow = (color: Color.black.opacity(0.16), radius: CGFloat(22), x: CGFloat(0), y: CGFloat(14))
    }
}
