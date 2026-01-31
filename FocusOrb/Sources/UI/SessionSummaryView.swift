import SwiftUI

struct SessionSummaryView: View {
    let sessionDuration: TimeInterval
    let greenDuration: TimeInterval
    let redDuration: TimeInterval
    let segments: [OrbSegment]
    let avgGreenStreak: TimeInterval
    let startTime: Date
    let endTime: Date
    let mergedSessionCount: Int?
    let onClose: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            // Header
            Text("Session Complete")
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Merge hint
            if let count = mergedSessionCount, count > 1 {
                Text("自动合并了 \(count) 段专注")
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.7))
            }
            
            // Total Duration
            Text(formatDuration(sessionDuration))
                .font(.system(.title, design: .rounded).monospacedDigit())
                .fontWeight(.bold)
                .foregroundColor(Color(red: 0.0, green: 0.95, blue: 0.6))
            
            // Time Range
            Text("\(formatTime(startTime)) - \(formatTime(endTime))")
                .font(.caption2)
                .foregroundColor(.secondary.opacity(0.6))
            
            // Green/Red Summary
            HStack(spacing: 16) {
                Label {
                    Text(formatDuration(greenDuration))
                } icon: {
                    Circle().fill(Color.green).frame(width: 6, height: 6)
                }
                .font(.footnote)
                
                Label {
                    Text(formatDuration(redDuration))
                } icon: {
                    Circle().fill(Color.red).frame(width: 6, height: 6)
                }
                .font(.footnote)
            }
            .foregroundColor(.secondary)
            
            // Avg Green Streak
            if avgGreenStreak > 0 {
                HStack(spacing: 4) {
                    Text("Avg Focus:")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(formatDuration(avgGreenStreak))
                        .font(.caption2.monospacedDigit())
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
                .padding(.vertical, 4)
            
            // Segment List
            if !segments.isEmpty {
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(segments) { segment in
                            HStack {
                                Circle()
                                    .fill(segment.type == .green ? Color.green : Color.red)
                                    .frame(width: 6, height: 6)
                                
                                Text("\(formatTime(segment.startTime)) - \(formatTime(segment.endTime ?? Date()))")
                                    .font(.caption2.monospacedDigit())
                                
                                Spacer()
                                
                                Text(formatDuration(segment.duration))
                                    .font(.caption2.monospacedDigit())
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .frame(maxHeight: 120)
            }
        }
        .padding(20)
        .frame(width: 260)
        .background(Material.ultraThin)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
        .onTapGesture {
            onClose()
        }
    }
    
    private func formatDuration(_ interval: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: interval) ?? "00:00:00"
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

