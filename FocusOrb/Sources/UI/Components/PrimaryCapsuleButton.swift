import SwiftUI

struct PrimaryCapsuleButton: View {
    enum Style {
        case focus
        case warm
    }

    let title: String
    let systemImage: String?
    let style: Style
    let action: () -> Void

    init(title: String, systemImage: String? = nil, style: Style = .warm, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.style = style
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 14, weight: .semibold))
                }
                Text(title)
                    .font(.system(.headline, design: .rounded))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(gradient)
            )
            .shadow(color: gradientShadow, radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }

    private var gradient: LinearGradient {
        switch style {
        case .focus:
            return LinearGradient(
                colors: [AppTheme.Colors.focusMint, .teal],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .warm:
            return LinearGradient(
                colors: [AppTheme.Colors.warmOrange, AppTheme.Colors.warmOrange.opacity(0.85)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var gradientShadow: Color {
        switch style {
        case .focus:
            return AppTheme.Colors.focusMint.opacity(0.4)
        case .warm:
            return AppTheme.Colors.warmOrange.opacity(0.35)
        }
    }
}

