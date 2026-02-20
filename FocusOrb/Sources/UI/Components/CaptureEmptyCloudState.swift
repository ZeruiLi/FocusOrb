import SwiftUI

struct CaptureEmptyCloudState: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Image(systemName: "cloud")
                    .font(.system(size: 72, weight: .light))
                    .foregroundColor(AppTheme.Colors.captureCloudInk.opacity(0.80))

                Image(systemName: icon)
                    .font(.system(size: 34, weight: .regular))
                    .foregroundColor(AppTheme.Colors.captureCloudInk.opacity(0.92))
                    .offset(y: 2)
            }
            .frame(height: 92)

            Text(L10n.string(title))
                .font(.system(size: 22, weight: .medium, design: .rounded))
                .foregroundColor(AppTheme.Colors.captureTextSecondary)

            if !subtitle.isEmpty {
                Text(L10n.string(subtitle))
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundColor(AppTheme.Colors.captureTextMuted)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(maxWidth: 320)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 260)
        .accessibilityElement(children: .combine)
    }
}
