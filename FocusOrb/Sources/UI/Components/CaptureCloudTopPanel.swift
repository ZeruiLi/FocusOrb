import SwiftUI

enum CaptureCloudTopMode {
    case notes
    case tasks
    case clips
}

struct CaptureCloudTopPanel: View {
    @Binding var selectedTab: CaptureTab
    @Binding var searchText: String
    var mode: CaptureCloudTopMode
    var showsTitle: Bool
    var onTabChanged: ((CaptureTab) -> Void)?
    private let cloudShape = CaptureCloudTopShape()

    init(
        mode: CaptureCloudTopMode = .notes,
        selectedTab: Binding<CaptureTab>,
        searchText: Binding<String>,
        showsTitle: Bool = false,
        onTabChanged: ((CaptureTab) -> Void)? = nil
    ) {
        self.mode = mode
        _selectedTab = selectedTab
        _searchText = searchText
        self.showsTitle = showsTitle
        self.onTabChanged = onTabChanged
    }

    private var panelMinHeight: CGFloat {
        switch mode {
        case .notes:
            return 178
        case .tasks, .clips:
            return 156
        }
    }

    var body: some View {
        VStack(alignment: .center, spacing: mode == .notes ? 16 : 0) {
            if showsTitle {
                Text(L10n.string("Capture"))
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.Colors.captureTextPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .accessibilityAddTraits(.isHeader)
            }

            CaptureSegmentedControl(
                selection: $selectedTab,
                maxTrackWidth: 560,
                trackHeight: 52,
                segmentHeight: 50,
                titleSize: 22
            )
            .frame(maxWidth: .infinity, alignment: .center)

            if mode == .notes {
                CaptureSearchField(
                    text: $searchText,
                    placeholder: L10n.string("Search in %@...", selectedTab.title)
                )
                .frame(maxWidth: 620)
                .frame(height: 44)
            }
        }
        .padding(.horizontal, 26)
        .padding(.top, mode == .notes ? 46 : 40)
        .padding(.bottom, mode == .notes ? 24 : 20)
        .frame(minHeight: panelMinHeight)
        .frame(maxWidth: .infinity, alignment: .center)
        .background { cloudBackground }
        .clipShape(cloudShape)
        .overlay(cloudStroke)
        .overlay(cloudHighlightStroke)
        .shadow(color: Color.black.opacity(0.08), radius: 18, x: 0, y: 10)
        .shadow(color: Color.white.opacity(0.32), radius: 12, x: 0, y: -2)
        .onChange(of: selectedTab) { _, newValue in
            onTabChanged?(newValue)
        }
    }

    private var cloudBackground: some View {
        ZStack {
            cloudShape.fill(AppTheme.Effects.cardMaterial)
            cloudShape.fill(
                LinearGradient(
                    colors: [
                        AppTheme.Colors.captureSurfaceStrong,
                        AppTheme.Colors.captureSurface
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
    }

    private var cloudStroke: some View {
        cloudShape.stroke(AppTheme.Colors.captureSurfaceStroke, lineWidth: 1)
    }

    private var cloudHighlightStroke: some View {
        cloudShape
            .stroke(Color.white.opacity(0.68), lineWidth: 0.5)
            .blur(radius: 0.1)
    }
}

private struct CaptureCloudTopShape: Shape {
    func path(in rect: CGRect) -> Path {
        let minX = rect.minX
        let maxX = rect.maxX
        let minY = rect.minY
        let maxY = rect.maxY
        let width = rect.width
        let midX = rect.midX

        let cornerRadius = min(28, width * 0.05)
        // Keep cloud crest clearly above segmented track to avoid clipping/mask artifacts.
        let cloudBaseY = minY + min(max(rect.height * 0.16, 34), 44)

        let x1 = minX + width * 0.08
        let x2 = minX + width * 0.23
        let x3 = minX + width * 0.40
        let x4 = minX + width * 0.60
        let x5 = minX + width * 0.77
        let x6 = minX + width * 0.92

        var path = Path()
        path.move(to: CGPoint(x: minX + cornerRadius, y: cloudBaseY))
        path.addLine(to: CGPoint(x: x1, y: cloudBaseY))

        path.addQuadCurve(
            to: CGPoint(x: x2, y: cloudBaseY),
            control: CGPoint(x: (x1 + x2) * 0.5, y: cloudBaseY - 8)
        )
        path.addQuadCurve(
            to: CGPoint(x: x3, y: cloudBaseY),
            control: CGPoint(x: (x2 + x3) * 0.5, y: cloudBaseY - 13)
        )
        path.addQuadCurve(
            to: CGPoint(x: x4, y: cloudBaseY),
            control: CGPoint(x: midX, y: cloudBaseY - 18)
        )
        path.addQuadCurve(
            to: CGPoint(x: x5, y: cloudBaseY),
            control: CGPoint(x: (x4 + x5) * 0.5, y: cloudBaseY - 13)
        )
        path.addQuadCurve(
            to: CGPoint(x: x6, y: cloudBaseY),
            control: CGPoint(x: (x5 + x6) * 0.5, y: cloudBaseY - 8)
        )

        path.addLine(to: CGPoint(x: maxX - cornerRadius, y: cloudBaseY))
        path.addQuadCurve(
            to: CGPoint(x: maxX, y: cloudBaseY + cornerRadius),
            control: CGPoint(x: maxX, y: cloudBaseY)
        )
        path.addLine(to: CGPoint(x: maxX, y: maxY - cornerRadius))
        path.addQuadCurve(
            to: CGPoint(x: maxX - cornerRadius, y: maxY),
            control: CGPoint(x: maxX, y: maxY)
        )
        path.addLine(to: CGPoint(x: minX + cornerRadius, y: maxY))
        path.addQuadCurve(
            to: CGPoint(x: minX, y: maxY - cornerRadius),
            control: CGPoint(x: minX, y: maxY)
        )
        path.addLine(to: CGPoint(x: minX, y: cloudBaseY + cornerRadius))
        path.addQuadCurve(
            to: CGPoint(x: minX + cornerRadius, y: cloudBaseY),
            control: CGPoint(x: minX, y: cloudBaseY)
        )
        path.closeSubpath()
        return path
    }
}
