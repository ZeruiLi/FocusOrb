import SwiftUI

struct CaptureSegmentedControl: View {
    @Binding var selection: CaptureTab
    var minTrackWidth: CGFloat = 460
    var maxTrackWidth: CGFloat = 560
    var trackHeight: CGFloat = 52
    var segmentHeight: CGFloat = 50
    var titleSize: CGFloat = 22
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var indicatorNamespace

    var body: some View {
        HStack(spacing: 0) {
            ForEach(CaptureTab.allCases, id: \.id) { tab in
                segmentButton(for: tab)
            }
        }
        .padding(1)
        .background {
            ZStack {
                Capsule(style: .continuous)
                    .fill(AppTheme.Colors.captureInset)

                HStack(spacing: 0) {
                    Spacer()
                    separator
                    Spacer()
                    separator
                    Spacer()
                }
                .padding(.horizontal, 28)
            }
        }
        .frame(minWidth: minTrackWidth, maxWidth: maxTrackWidth)
        .frame(height: trackHeight)
        .overlay(
            Capsule(style: .continuous)
                .stroke(AppTheme.Colors.captureInsetStroke, lineWidth: 1)
        )
    }

    private func segmentButton(for tab: CaptureTab) -> some View {
        Button {
            withAnimation(reduceMotion ? .none : .easeInOut(duration: 0.22)) {
                selection = tab
            }
        } label: {
            ZStack {
                if selection == tab {
                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    AppTheme.Colors.captureMintActive,
                                    AppTheme.Colors.captureMintActive.opacity(0.88)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(Color.white.opacity(0.85), lineWidth: 1)
                        )
                        .shadow(color: AppTheme.Colors.captureMintGlow, radius: 16, x: 0, y: 6)
                        .matchedGeometryEffect(id: "capture-segment-indicator", in: indicatorNamespace)
                }

                Text(tab.title)
                    .font(.system(size: titleSize, weight: .medium, design: .rounded))
                    .foregroundColor(selection == tab ? AppTheme.Colors.captureMintDeep : AppTheme.Colors.captureTextPrimary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: segmentHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(L10n.string("切换到%@", tab.title)))
    }

    private var separator: some View {
        Rectangle()
            .fill(AppTheme.Colors.captureDivider.opacity(0.72))
            .frame(width: 1, height: 26)
    }
}
