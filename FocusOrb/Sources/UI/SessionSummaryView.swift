import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct SessionSummaryView: View {
    let sessionDuration: TimeInterval
    let greenDuration: TimeInterval
    let redDuration: TimeInterval
    let segments: [OrbSegment]
    let avgGreenStreak: TimeInterval
    let startTime: Date
    let endTime: Date
    let mergedSessionCount: Int?
    let showReflection: Bool
    let onSetMood: (SessionMood?) -> Void
    let onClose: () -> Void

    @State private var isExporting = false
    @State private var exportError: String?
    
    var body: some View {
        VStack(spacing: 12) {
            StickerHeader(
                imageName: "focus",
                title: "Session Complete",
                subtitle: nil,
                style: .centered,
                iconSize: 36
            )
            
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
                .foregroundColor(AppTheme.Colors.focusMint)
            
            // Time Range
            Text("\(formatTime(startTime)) - \(formatTime(endTime))")
                .font(.caption2)
                .foregroundColor(.secondary.opacity(0.6))
            
            // Green/Red Summary
            HStack(spacing: 16) {
                Label {
                    Text(formatDuration(greenDuration))
                } icon: {
                    Circle().fill(AppTheme.Colors.focusMint).frame(width: 6, height: 6)
                }
                .font(.footnote)
                
                Label {
                    Text(formatDuration(redDuration))
                } icon: {
                    Circle().fill(AppTheme.Colors.warmOrange).frame(width: 6, height: 6)
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
            
            // Gentle summary (emotional value, no judgement)
            Text(supportiveLine)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 2)
            
            Divider()
                .padding(.vertical, 4)

            // Segment List
            if !segments.isEmpty {
                GlassCard(padding: 12) {
                    ScrollView {
                        VStack(spacing: 6) {
                            ForEach(segments) { segment in
                                HStack {
                                    Circle()
                                        .fill(segment.type == .green ? AppTheme.Colors.focusMint : AppTheme.Colors.warmOrange)
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

            PrimaryCapsuleButton(title: "导出小卡", systemImage: "square.and.arrow.up", style: .warm) {
                exportCard()
            }
            .disabled(isExporting)
            .accessibilityLabel(Text("导出专注小卡"))
            
            if showReflection {
                VStack(spacing: 10) {
                    Text("这次感觉如何？（可选）")
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.8))
                    
                    HStack(spacing: 10) {
                        ForEach(SessionMood.allCases) { mood in
                            Button {
                                onSetMood(mood)
                            } label: {
                                GlassCard(padding: 8) {
                                    VStack(spacing: 6) {
                                        Image(systemName: mood.symbolName)
                                            .font(.system(size: 14, weight: .semibold))
                                        Text(mood.title)
                                            .font(.caption2)
                                    }
                                    .frame(width: 50, height: 40)
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(Text("心情：\(mood.title)"))
                        }
                    }
                    
                    Button {
                        onSetMood(nil)
                    } label: {
                        Text("跳过")
                            .font(.caption)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Material.thin)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(AppTheme.Colors.surfaceStroke, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 6)
            } else {
                Button {
                    onClose()
                } label: {
                    Text("关闭")
                        .font(.caption)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Material.thin)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(AppTheme.Colors.surfaceStroke, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .padding(.top, 6)
            }
        }
        .padding(20)
        .frame(width: 300)
        .background(AppTheme.Effects.cardMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Effects.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Effects.cardRadius, style: .continuous)
                .stroke(AppTheme.Colors.surfaceStroke, lineWidth: 1)
        )
        .shadow(color: AppTheme.Effects.cardShadow.color, radius: AppTheme.Effects.cardShadow.radius, x: 0, y: 5)
        .alert("导出失败", isPresented: Binding(
            get: { exportError != nil },
            set: { _ in exportError = nil }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportError ?? "")
        }
    }
    
    private var supportiveLine: String {
        let total = greenDuration + redDuration
        guard total > 0 else { return "今天的每一小段努力都算数。" }
        
        let ratio = greenDuration / total
        if ratio >= 0.7 {
            return "你保持了清晰的节奏。"
        } else if ratio >= 0.4 {
            return "有专注也有恢复，这很真实。"
        } else {
            return "你也在照顾自己——休息是计划的一部分。"
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

    private func exportCard() {
        guard !isExporting else { return }
        isExporting = true
        defer { isExporting = false }

        let content = SessionExportCardView(
            sessionDuration: sessionDuration,
            greenDuration: greenDuration,
            redDuration: redDuration,
            avgGreenStreak: avgGreenStreak,
            startTime: startTime,
            endTime: endTime
        )

        let renderer = ImageRenderer(content: content)
        renderer.scale = 2

        guard let nsImage = renderer.nsImage else {
            exportError = "无法生成图片"
            return
        }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType.png]
        panel.nameFieldStringValue = "FocusOrb-Session-\(exportDateString()).png"

        let response = panel.runModal()
        guard response == .OK, let url = panel.url else { return }

        guard let tiff = nsImage.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let data = rep.representation(using: .png, properties: [:]) else {
            exportError = "导出失败"
            return
        }

        do {
            try data.write(to: url)
        } catch {
            exportError = "写入失败：\(error.localizedDescription)"
        }
    }

    private func exportDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmm"
        return formatter.string(from: endTime)
    }
}

private struct SessionExportCardView: View {
    let sessionDuration: TimeInterval
    let greenDuration: TimeInterval
    let redDuration: TimeInterval
    let avgGreenStreak: TimeInterval
    let startTime: Date
    let endTime: Date

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.mint.opacity(0.25), Color.teal.opacity(0.15)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.25), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("FocusOrb · 专注小卡")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "sparkles")
                        .foregroundColor(.teal)
                }

                Text(formatDuration(sessionDuration))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .monospacedDigit()

                Text("\(formatTime(startTime)) - \(formatTime(endTime))")
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack(spacing: 16) {
                    exportMetric(title: "专注", value: formatDuration(greenDuration), color: .mint)
                    exportMetric(title: "休息", value: formatDuration(redDuration), color: .red)
                    exportMetric(title: "平均专注", value: formatDuration(avgGreenStreak), color: .teal)
                }
            }
            .padding(20)
        }
        .frame(width: 420, height: 220)
    }

    private func exportMetric(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.callout.monospacedDigit())
                .foregroundColor(color)
        }
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = Int(interval) / 60 % 60
        if hours > 0 {
            return String(format: "%dh %02dm", hours, minutes)
        } else {
            return String(format: "%02dm", minutes)
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
