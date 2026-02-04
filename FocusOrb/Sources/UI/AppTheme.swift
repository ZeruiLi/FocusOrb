import SwiftUI

enum AppTheme {
    enum Colors {
        static let focusMint = Color(red: 0.0, green: 1.0, blue: 0.6)
        static let focusMintSoft = Color(red: 0.18, green: 0.86, blue: 0.70)
        static let warmOrange = Color(red: 0.98, green: 0.67, blue: 0.32)
        static let surfaceStroke = Color.white.opacity(0.12)
        static let textPrimary = Color.primary
        static let textSecondary = Color.secondary.opacity(0.8)
    }

    enum Typography {
        static let title = Font.system(.title2, design: .rounded).weight(.semibold)
        static let body = Font.system(.body, design: .rounded)
        static let caption = Font.system(.caption, design: .rounded)
        static let monospaced = Font.system(.title2, design: .rounded).monospacedDigit()
    }

    enum Effects {
        static let cardMaterial: Material = .thin
        static let cardRadius: CGFloat = 18
        static let cardShadow = (color: Color.black.opacity(0.08), radius: CGFloat(10), x: CGFloat(0), y: CGFloat(5))
    }
}
