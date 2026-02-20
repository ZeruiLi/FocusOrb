import SwiftUI

struct CaptureTaskComposerCard: View {
    @Binding var createText: String
    @Binding var searchText: String
    var onSubmit: () -> Void
    var onReset: () -> Void
    var createInputFocus: FocusState<Bool>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L10n.string("Tasks"))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(AppTheme.Colors.captureTextSecondary)

                Spacer()

                Button(L10n.string("Reset Default Order")) {
                    onReset()
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(AppTheme.Colors.captureTextSecondary)
                .accessibilityLabel(Text(L10n.string("Reset tasks to default order")))
            }

            HStack(spacing: 10) {
                TextField(L10n.string("Write your next action..."), text: $createText)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 16)
                    .frame(height: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(AppTheme.Colors.captureEditorSurface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(AppTheme.Colors.captureInsetStroke, lineWidth: 1)
                    )
                    .focused(createInputFocus)
                    .onSubmit(onSubmit)
                    .accessibilityLabel(Text(L10n.string("Task input")))

                Button {
                    onSubmit()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .medium))
                        .frame(width: 56, height: 56)
                        .foregroundColor(.white)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            AppTheme.Colors.captureActionTeal,
                                            AppTheme.Colors.captureMintDeep
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(L10n.string("Add task")))
            }

            CaptureSearchField(text: $searchText, placeholder: "Search in Tasks...")
                .frame(height: 52)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(AppTheme.Colors.captureSurfaceStrong.opacity(0.96))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(AppTheme.Colors.captureSurfaceStroke, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 12, x: 0, y: 6)
    }
}
