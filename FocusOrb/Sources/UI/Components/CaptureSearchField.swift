import SwiftUI

struct CaptureSearchField: View {
    @Binding var text: String
    let placeholder: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 21, weight: .regular))
                .foregroundColor(AppTheme.Colors.captureTextMuted)
                .frame(width: 24, height: 24)

            TextField(L10n.string(placeholder), text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 17, weight: .regular, design: .rounded))
                .foregroundColor(AppTheme.Colors.captureTextPrimary)
                .accessibilityLabel(Text(L10n.string("搜索输入")))
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppTheme.Colors.captureInset)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.Colors.captureInsetStroke, lineWidth: 1)
        )
    }
}
