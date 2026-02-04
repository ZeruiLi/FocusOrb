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
            background

            HStack(alignment: .center, spacing: 18) {
                leftContent

                illustration
                    .frame(width: 180, height: 170)
            }
            .padding(22)
        }
        .frame(width: 520, height: 260)
    }

    private var background: some View {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 1.0, green: 0.98, blue: 0.95),
                        AppTheme.Colors.focusMintSoft.opacity(0.14),
                        AppTheme.Colors.warmOrange.opacity(0.10),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                ZStack {
                    Circle()
                        .fill(AppTheme.Colors.focusMintSoft.opacity(0.16))
                        .frame(width: 220, height: 220)
                        .blur(radius: 26)
                        .offset(x: -160, y: -120)

                    Circle()
                        .fill(AppTheme.Colors.warmOrange.opacity(0.20))
                        .frame(width: 260, height: 260)
                        .blur(radius: 32)
                        .offset(x: 170, y: 120)
                }
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            }
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(Color.white.opacity(0.28), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.08), radius: 18, x: 0, y: 10)
    }

    private var leftContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                stickerMini(imageName: "focus")
                VStack(alignment: .leading, spacing: 2) {
                    Text("FocusOrb · 专注小卡")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(AppTheme.Colors.textPrimary.opacity(0.92))
                    Text("\(formatTime(startTime)) - \(formatTime(endTime))")
                        .font(.system(size: 11, weight: .medium, design: .rounded).monospacedDigit())
                        .foregroundColor(AppTheme.Colors.textSecondary.opacity(0.75))
                }

                Spacer()

                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.warmOrange.opacity(0.9))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(formatDuration(sessionDuration))
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                AppTheme.Colors.focusMintSoft,
                                AppTheme.Colors.focusMintSoft.opacity(0.75),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: AppTheme.Colors.focusMintSoft.opacity(0.18), radius: 10, x: 0, y: 6)

                Text("本次专注时长")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }

            HStack(spacing: 10) {
                exportMetricPill(
                    title: "专注",
                    value: formatDuration(greenDuration),
                    tint: AppTheme.Colors.focusMintSoft,
                    systemImage: "leaf.fill"
                )

                exportMetricPill(
                    title: "休息",
                    value: formatDuration(redDuration),
                    tint: AppTheme.Colors.warmOrange,
                    systemImage: "cup.and.saucer.fill"
                )

                exportMetricPill(
                    title: "平均专注",
                    value: formatDuration(avgGreenStreak),
                    tint: AppTheme.Colors.focusMintSoft.opacity(0.9),
                    systemImage: "clock.fill"
                )
            }
        }
    }

    private var illustration: some View {
        ZStack {
            Circle()
                .fill(AppTheme.Colors.warmOrange.opacity(0.18))
                .frame(width: 170, height: 170)
                .blur(radius: 18)
                .offset(x: 14, y: 10)

            Circle()
                .fill(AppTheme.Colors.focusMintSoft.opacity(0.16))
                .frame(width: 160, height: 160)
                .blur(radius: 18)
                .offset(x: -10, y: -12)

            if let image = BundledImage.swiftUIImage(named: "focus", subdirectory: "Orb") {
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 175, height: 155)
                    .shadow(color: Color.black.opacity(0.14), radius: 18, x: 0, y: 12)
            }

            if let tree = BundledImage.swiftUIImage(named: "tree", subdirectory: "Orb") {
                tree
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 38, height: 38)
                    .shadow(color: Color.black.opacity(0.10), radius: 8, x: 0, y: 6)
                    .offset(x: 42, y: 52)
            }
        }
    }

    private func exportMetricPill(title: String, value: String, tint: Color, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(tint.opacity(0.95))
                Text(title)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundColor(AppTheme.Colors.textSecondary.opacity(0.8))
            }

            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundColor(AppTheme.Colors.textPrimary.opacity(0.9))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.42))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.28), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 6)
    }

    private func stickerMini(imageName: String) -> some View {
        ZStack {
            Circle()
                .fill(AppTheme.Colors.warmOrange.opacity(0.18))
                .frame(width: 34, height: 34)
                .blur(radius: 8)
            if let image = BundledImage.swiftUIImage(named: imageName, subdirectory: "Orb") {
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 22, height: 22)
                    .shadow(color: AppTheme.Colors.warmOrange.opacity(0.22), radius: 6, x: 0, y: 4)
            } else {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.warmOrange)
            }
        }
        .frame(width: 34, height: 34)
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
