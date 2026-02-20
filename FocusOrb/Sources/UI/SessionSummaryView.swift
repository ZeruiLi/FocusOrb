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
    let onConfirmEnd: (() -> Void)?
    let onContinueSession: (() -> Void)?

    @State private var isExporting = false
    @State private var exportError: String?

    var body: some View {
        OrbPanelContainer(padding: 18) {
            VStack(spacing: 12) {
                StickerHeader(
                    imageName: "focus",
                    title: "Session Complete",
                    subtitle: "看见节奏，而不是评判",
                    style: .centered,
                    iconSize: 38
                )

                if let count = mergedSessionCount, count > 1 {
                    mergeHint(count: count)
                }

                durationHero

                HStack(spacing: 10) {
                    summaryMetric(
                        title: "专注",
                        value: formatDuration(greenDuration),
                        systemImage: "leaf.fill",
                        tint: AppTheme.Colors.focusTeal
                    )

                    summaryMetric(
                        title: "休息",
                        value: formatDuration(redDuration),
                        systemImage: "cup.and.saucer.fill",
                        tint: AppTheme.Colors.warmAmber
                    )

                    summaryMetric(
                        title: "专注比例",
                        value: focusPercentText,
                        systemImage: "percent",
                        tint: AppTheme.Colors.focusMintSoft
                    )
                }

                if avgGreenStreak > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "clock.fill")
                            .font(.caption2)
                            .foregroundColor(AppTheme.Colors.textMuted)
                        Text(L10n.string("平均专注"))
                            .font(.caption)
                            .foregroundColor(AppTheme.Colors.textMuted)
                        Text(formatDuration(avgGreenStreak))
                            .font(.caption.monospacedDigit())
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GlassCard(padding: 10) {
                    Text(supportiveLine)
                        .font(.caption)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if !segments.isEmpty {
                    segmentsSection
                }

                PrimaryCapsuleButton(title: "导出小卡", systemImage: "square.and.arrow.up", style: .warm) {
                    exportCard()
                }
                .disabled(isExporting)
                .accessibilityLabel(Text(L10n.string("导出专注小卡")))
                .opacity(isExporting ? 0.6 : 1)

                actionArea
            }
        }
        .padding(10)
        .frame(width: 356)
        .alert(L10n.string("导出失败"), isPresented: Binding(
            get: { exportError != nil },
            set: { _ in exportError = nil }
        )) {
            Button(L10n.string("OK"), role: .cancel) {}
        } message: {
            Text(exportError ?? "")
        }
    }

    private var durationHero: some View {
        GlassCard(padding: 14) {
            VStack(spacing: 8) {
                Text(formatDuration(sessionDuration))
                    .font(.system(size: 34, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppTheme.Colors.focusTeal, AppTheme.Colors.focusMintSoft],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text("\(formatTime(startTime)) - \(formatTime(endTime))")
                    .font(.caption.monospacedDigit())
                    .foregroundColor(AppTheme.Colors.textMuted)
            }
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private func mergeHint(count: Int) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.triangle.merge")
                .font(.caption2)
            Text(L10n.string("自动合并了 %d 段专注", count))
                .font(.caption)
        }
        .foregroundColor(AppTheme.Colors.textSecondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.32))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.35), lineWidth: 1)
        )
    }

    private var segmentsSection: some View {
        GlassCard(padding: 12) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(L10n.string("会话片段"))
                        .font(.caption.weight(.semibold))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    Spacer()
                    Text(L10n.string("%d 段", segments.count))
                        .font(.caption.monospacedDigit())
                        .foregroundColor(AppTheme.Colors.textMuted)
                }

                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(segments) { segment in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(segment.type == .green ? AppTheme.Colors.focusTeal : AppTheme.Colors.warmAmber)
                                    .frame(width: 7, height: 7)

                                Text("\(formatTime(segment.startTime)) - \(formatTime(segment.endTime ?? Date()))")
                                    .font(.caption.monospacedDigit())
                                    .foregroundColor(AppTheme.Colors.textSecondary)

                                Spacer()

                                Text(formatDuration(segment.duration))
                                    .font(.caption.monospacedDigit())
                                    .foregroundColor(AppTheme.Colors.textMuted)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.30))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                    }
                }
                .frame(maxHeight: 132)
            }
        }
    }

    @ViewBuilder
    private var actionArea: some View {
        if let onConfirmEnd, let onContinueSession {
            VStack(spacing: 10) {
                Text(L10n.string("确认后将结束本次会话"))
                    .font(.caption)
                    .foregroundColor(AppTheme.Colors.textMuted)

                HStack(spacing: 10) {
                    Button {
                        onContinueSession()
                    } label: {
                        Text(L10n.string("继续会话"))
                            .font(.caption.weight(.semibold))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                            .frame(minWidth: 96, minHeight: 38)
                            .background(Color.white.opacity(0.30))
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.36), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)

                    PrimaryCapsuleButton(title: "确认结束", systemImage: "checkmark", style: .warm) {
                        onConfirmEnd()
                    }
                }
            }
            .padding(.top, 2)
        } else if showReflection {
            reflectionArea
        } else {
            Button {
                onClose()
            } label: {
                Text(L10n.string("关闭"))
                    .font(.caption.weight(.semibold))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .frame(minWidth: 84, minHeight: 38)
                    .background(Color.white.opacity(0.30))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.36), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
        }
    }

    private var reflectionArea: some View {
        VStack(spacing: 10) {
            Text(L10n.string("这次感觉如何？（可选）"))
                .font(.caption)
                .foregroundColor(AppTheme.Colors.textMuted)

            HStack(spacing: 10) {
                ForEach(SessionMood.allCases) { mood in
                    Button {
                        onSetMood(mood)
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: mood.symbolName)
                                .font(.system(size: 14, weight: .semibold))
                            Text(mood.title)
                                .font(.caption2)
                        }
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .frame(width: 56, height: 54)
                        .background(Color.white.opacity(0.30))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.white.opacity(0.36), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(L10n.string("心情：%@", mood.title)))
                }
            }

            Button {
                onSetMood(nil)
            } label: {
                Text(L10n.string("跳过"))
                    .font(.caption.weight(.semibold))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .frame(minWidth: 84, minHeight: 34)
                    .background(Color.white.opacity(0.30))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.36), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 2)
    }

    private func summaryMetric(title: String, value: String, systemImage: String, tint: Color) -> some View {
        GlassCard(padding: 10) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 5) {
                    Image(systemName: systemImage)
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(tint)
                    Text(L10n.string(title))
                        .font(.caption2)
                        .foregroundColor(AppTheme.Colors.textMuted)
                }

                Text(value)
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var focusPercentText: String {
        let total = greenDuration + redDuration
        guard total > 0 else { return L10n.string("—") }
        return String(format: "%.0f%%", (greenDuration / total) * 100)
    }

    private var supportiveLine: String {
        let total = greenDuration + redDuration
        guard total > 0 else { return L10n.string("今天的每一小段努力都算数。") }

        let ratio = greenDuration / total
        if ratio >= 0.7 {
            return L10n.string("你保持了清晰的节奏。")
        } else if ratio >= 0.4 {
            return L10n.string("有专注也有恢复，这很真实。")
        } else {
            return L10n.string("你也在照顾自己，休息是计划的一部分。")
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
            exportError = L10n.string("无法生成图片")
            return
        }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType.png]
        panel.nameFieldStringValue = L10n.string("FocusOrb-Session-%@.png", exportDateString())

        let response = panel.runModal()
        guard response == .OK, let url = panel.url else { return }

        guard let tiff = nsImage.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let data = rep.representation(using: .png, properties: [:]) else {
            exportError = L10n.string("导出失败")
            return
        }

        do {
            try data.write(to: url)
        } catch {
            exportError = L10n.string("写入失败：%@", error.localizedDescription)
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
            OrbExportBackground()

            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    stickerMini(imageName: "focus")

                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.string("FocusOrb · Session"))
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(AppTheme.Colors.exportTextSecondary)
                        Text("\(formatTime(startTime)) - \(formatTime(endTime))")
                            .font(.system(size: 11, weight: .medium, design: .rounded).monospacedDigit())
                            .foregroundColor(AppTheme.Colors.exportTextSecondary.opacity(0.85))
                    }

                    Spacer()

                    Image(systemName: "sparkles")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.warmAmber)
                }

                OrbExportSurface(padding: 14, cornerRadius: 18, emphasized: true) {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(formatDuration(sessionDuration))
                                .font(.system(size: 38, weight: .bold, design: .rounded).monospacedDigit())
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [AppTheme.Colors.focusTeal, AppTheme.Colors.focusMintSoft],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )

                            Text(L10n.string("本次专注时长"))
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundColor(AppTheme.Colors.exportTextSecondary)
                        }

                        Spacer(minLength: 8)

                        orbIllustration
                            .frame(width: 136, height: 96)
                    }
                }

                HStack(spacing: 10) {
                    exportMetricTile(
                        title: "专注",
                        value: formatDuration(greenDuration),
                        tint: AppTheme.Colors.focusTeal,
                        systemImage: "leaf.fill"
                    )

                    exportMetricTile(
                        title: "休息",
                        value: formatDuration(redDuration),
                        tint: AppTheme.Colors.warmAmber,
                        systemImage: "cup.and.saucer.fill"
                    )

                    exportMetricTile(
                        title: "平均专注",
                        value: formatDuration(avgGreenStreak),
                        tint: AppTheme.Colors.focusMintSoft,
                        systemImage: "clock.fill"
                    )
                }

                OrbExportSurface(padding: 10, cornerRadius: 14) {
                    Text(supportiveLine)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(AppTheme.Colors.exportTextSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(22)
        }
        .frame(width: 560, height: 320)
    }

    private var supportiveLine: String {
        let total = greenDuration + redDuration
        guard total > 0 else { return L10n.string("今天的每一小段努力都算数。") }

        let ratio = greenDuration / total
        if ratio >= 0.7 {
            return L10n.string("你保持了清晰的节奏。")
        } else if ratio >= 0.4 {
            return L10n.string("有专注也有恢复，这很真实。")
        } else {
            return L10n.string("你也在照顾自己，休息是计划的一部分。")
        }
    }

    private var orbIllustration: some View {
        ZStack {
            Circle()
                .fill(AppTheme.Colors.panelGlowMint.opacity(0.92))
                .frame(width: 106, height: 106)
                .blur(radius: 18)

            Circle()
                .fill(AppTheme.Colors.panelGlowWarm.opacity(0.86))
                .frame(width: 94, height: 94)
                .blur(radius: 16)
                .offset(x: 18, y: 16)

            if let image = BundledImage.swiftUIImage(named: "focus", subdirectory: "Orb") {
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 102, height: 84)
                    .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 6)
            }
        }
    }

    private func exportMetricTile(title: String, value: String, tint: Color, systemImage: String) -> some View {
        OrbExportSurface(padding: 10, cornerRadius: 14) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 5) {
                    Image(systemName: systemImage)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(tint)
                    Text(L10n.string(title))
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundColor(AppTheme.Colors.exportTextSecondary)
                }

                Text(value)
                    .font(.system(size: 14, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundColor(AppTheme.Colors.exportTextPrimary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func stickerMini(imageName: String) -> some View {
        ZStack {
            Circle()
                .fill(AppTheme.Colors.panelGlowWarm.opacity(0.90))
                .frame(width: 34, height: 34)
                .blur(radius: 8)
            if let image = BundledImage.swiftUIImage(named: imageName, subdirectory: "Orb") {
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 22, height: 22)
            } else {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.warmAmber)
            }
        }
        .frame(width: 34, height: 34)
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = Int(interval) / 60 % 60
        let seconds = Int(interval) % 60

        if hours > 0 {
            return L10n.string("%dh %02dm", hours, minutes)
        }
        if minutes > 0 {
            return L10n.string("%02dm %02ds", minutes, seconds)
        }
        return L10n.string("%02ds", seconds)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
