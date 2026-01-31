import SwiftUI

struct StartView: View {
    var onStart: () -> Void
    
    var body: some View {
        VStack(spacing: 30) {
            // Logo (Static Orb)
            ZStack {
                Circle().fill(Color.mint.opacity(0.3)).frame(width: 60, height: 60).blur(radius: 10)
                Circle().fill(Color.mint.opacity(0.8)).frame(width: 40, height: 40)
            }
            .shadow(color: .mint, radius: 20)
            
            VStack(spacing: 8) {
                Text("FocusOrb")
                    .font(.system(.largeTitle, design: .rounded))
                    .fontWeight(.bold)
                Text("Find your flow.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                // Interaction hints
                VStack(spacing: 4) {
                    Text("点击切换状态 · 长按结束")
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.6))
                    Text("绿色→橙色 3秒内可回滚")
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.6))
                }
                .padding(.top, 4)
            }
            
            Button(action: onStart) {
                Text("Start Flow")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(LinearGradient(colors: [.mint, .teal], startPoint: .topLeading, endPoint: .bottomTrailing))
                    )
                    .shadow(color: .mint.opacity(0.4), radius: 10, y: 5)
            }
            .buttonStyle(.plain)
        }
        .frame(width: 300, height: 250)
        .background(Material.regular)
    }
}
