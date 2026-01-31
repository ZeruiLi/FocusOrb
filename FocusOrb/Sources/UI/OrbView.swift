import SwiftUI

struct OrbView: View {
    @ObservedObject var stateMachine: OrbStateMachine

    @State private var isBreathing = false
    @State private var isLongPressing = false

    let mintColor = Color(red: 0.0, green: 1.0, blue: 0.6)
    let coralColor = Color(red: 1.0, green: 0.5, blue: 0.5)

    var body: some View {
        ZStack {
            Circle()
                .fill(coreColor)
                .frame(width: 50, height: 50)
                .blur(radius: isBreathing ? 15 : 8)
                .opacity(isBreathing ? 0.6 : 0.3)
                .scaleEffect(isBreathing ? 1.15 : 1.0)

            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            coreColor.opacity(0.4),
                            coreColor.opacity(0.1)
                        ]),
                        center: .center,
                        startRadius: 0,
                        endRadius: 30
                    )
                )
                .frame(width: 60, height: 60)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )

            Circle()
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.4), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 50, height: 50)
                .offset(x: -5, y: -5)
                .blur(radius: 5)
                .mask(Circle().frame(width: 58, height: 58))

            VStack(spacing: 0) {
                if case .redPending(_, let remaining) = stateMachine.currentState {
                    Text(String(format: "%.0f", ceil(remaining)))
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(radius: 2)
                } else if stateMachine.currentState != .idle {
                    Text(formatTime(stateMachine.currentSessionDuration))
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.9))
                        .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
                        .padding(.top, 2)
                }
            }

            if case .redPending(_, let remaining) = stateMachine.currentState {
                Circle()
                    .trim(from: 0, to: CGFloat(remaining / AppSettings.redPendingDuration))
                    .stroke(Color.white, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 62, height: 62)
                    .rotationEffect(.degrees(-90))
            }
        }
        .frame(width: 120, height: 120)
        .background(Color.clear)
        .contentShape(Rectangle())
        .scaleEffect(isLongPressing ? 0.9 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isLongPressing)
        .gesture(
            LongPressGesture(minimumDuration: 0.8)
                .onChanged { _ in
                    isLongPressing = true
                }
                .onEnded { _ in
                    isLongPressing = false
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                        stateMachine.endSession()
                    }
                }
        )
        .simultaneousGesture(
            TapGesture()
                .onEnded {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                        stateMachine.handleClick()
                    }
                }
        )
        .onAppear {
            startAnimations()
        }
    }

    private var coreColor: Color {
        switch stateMachine.currentState {
        case .green:
            mintColor
        case .redPending:
            Color.orange
        case .red:
            coralColor
        case .idle:
            Color.gray
        }
    }

    private func startAnimations() {
        isBreathing = false
        withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
            isBreathing = true
        }
    }

    private func formatTime(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

