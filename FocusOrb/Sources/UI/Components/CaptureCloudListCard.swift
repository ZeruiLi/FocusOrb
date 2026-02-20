import SwiftUI

struct CaptureCloudListCard<Content: View>: View {
    @Binding var searchText: String
    let placeholder: String
    @ViewBuilder let content: () -> Content

    private let cloudShape = CaptureCloudListShape()

    var body: some View {
        VStack(spacing: 0) {
            CaptureSearchField(text: $searchText, placeholder: placeholder)
                .frame(height: 52)
                .padding(.horizontal, 22)
                .padding(.top, 54)
                .padding(.bottom, 14)

            Rectangle()
                .fill(AppTheme.Colors.captureRowSeparator.opacity(0.9))
                .frame(height: 1)
                .padding(.horizontal, 22)

            content()
                .padding(.horizontal, 22)
                .padding(.top, 14)
                .padding(.bottom, 20)
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity)
        .background {
            ZStack {
                cloudShape
                    .fill(AppTheme.Effects.cardMaterial)
                cloudShape
                    .fill(
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
        .clipShape(cloudShape)
        .overlay(
            cloudShape
                .stroke(AppTheme.Colors.captureSurfaceStroke, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.07), radius: 16, x: 0, y: 8)
    }
}

private struct CaptureCloudListShape: Shape {
    func path(in rect: CGRect) -> Path {
        let minX = rect.minX
        let maxX = rect.maxX
        let minY = rect.minY
        let maxY = rect.maxY
        let width = rect.width
        let midX = rect.midX

        let cornerRadius = min(32, width * 0.06)
        let cloudBaseY = minY + min(max(rect.height * 0.13, 40), 50)

        let x1 = minX + width * 0.10
        let x2 = minX + width * 0.26
        let x3 = minX + width * 0.43
        let x4 = minX + width * 0.58
        let x5 = minX + width * 0.74
        let x6 = minX + width * 0.90

        var path = Path()
        path.move(to: CGPoint(x: minX + cornerRadius, y: cloudBaseY))
        path.addLine(to: CGPoint(x: x1, y: cloudBaseY))

        path.addQuadCurve(
            to: CGPoint(x: x2, y: cloudBaseY),
            control: CGPoint(x: (x1 + x2) * 0.5, y: cloudBaseY - 12)
        )
        path.addQuadCurve(
            to: CGPoint(x: x3, y: cloudBaseY),
            control: CGPoint(x: (x2 + x3) * 0.5, y: cloudBaseY - 20)
        )
        path.addQuadCurve(
            to: CGPoint(x: x4, y: cloudBaseY),
            control: CGPoint(x: midX, y: cloudBaseY - 26)
        )
        path.addQuadCurve(
            to: CGPoint(x: x5, y: cloudBaseY),
            control: CGPoint(x: (x4 + x5) * 0.5, y: cloudBaseY - 20)
        )
        path.addQuadCurve(
            to: CGPoint(x: x6, y: cloudBaseY),
            control: CGPoint(x: (x5 + x6) * 0.5, y: cloudBaseY - 12)
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

        return path
    }
}
