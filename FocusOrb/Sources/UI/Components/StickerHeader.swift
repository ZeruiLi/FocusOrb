import SwiftUI

struct StickerHeader: View {
    enum Style {
        case leading
        case centered
    }

    let imageName: String
    let title: String
    let subtitle: String?
    let style: Style
    let iconSize: CGFloat

    init(imageName: String, title: String, subtitle: String? = nil, style: Style = .leading, iconSize: CGFloat = 44) {
        self.imageName = imageName
        self.title = title
        self.subtitle = subtitle
        self.style = style
        self.iconSize = iconSize
    }

    var body: some View {
        switch style {
        case .leading:
            HStack(spacing: 12) {
                stickerIcon
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(AppTheme.Typography.title)
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                }
            }
        case .centered:
            VStack(spacing: 8) {
                stickerIcon
                Text(title)
                    .font(AppTheme.Typography.title)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
            }
        }
    }

    private var stickerIcon: some View {
        ZStack {
            Circle()
                .fill(AppTheme.Colors.warmOrange.opacity(0.18))
                .frame(width: iconSize + 16, height: iconSize + 16)
                .blur(radius: 10)
            if let image = BundledImage.swiftUIImage(named: imageName, subdirectory: "Orb") {
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: iconSize, height: iconSize)
                    .shadow(color: AppTheme.Colors.warmOrange.opacity(0.3), radius: 8, x: 0, y: 4)
            } else {
                Image(systemName: "sparkles")
                    .font(.system(size: iconSize * 0.6, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.warmOrange)
            }
        }
    }
}

