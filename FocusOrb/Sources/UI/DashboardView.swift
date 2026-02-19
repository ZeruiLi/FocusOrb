import SwiftUI
import Charts
import AppKit
import UniformTypeIdentifiers

enum StatsPeriod: String, CaseIterable {
    case day = "日"
    case week = "周"
    case month = "月"
    case year = "年"
}

struct DashboardView: View {
    @ObservedObject var eventStore: EventStore
    @State private var selectedPeriod: StatsPeriod = .day
    @State private var showExportSheet = false
    @State private var exportOptions = DashboardExportOptions()
    @State private var exportError: String?
    
    // Computed properties for current period
    private var dateRange: DateInterval {
        switch selectedPeriod {
        case .day: return StatsCalculator.todayRange()
        case .week: return StatsCalculator.thisWeekRange()
        case .month: return StatsCalculator.thisMonthRange()
        case .year: return StatsCalculator.thisYearRange()
        }
    }
    
    private var allSegments: [OrbSegment] {
        let segments = StatsCalculator.calculateSegments(from: eventStore.events)
        return StatsCalculator.splitSegmentsByDay(segments)
    }
    
    private var filteredSegments: [OrbSegment] {
        StatsCalculator.filterSegments(allSegments, in: dateRange)
    }

    private var filteredEvents: [OrbEvent] {
        eventStore.events.filter { event in
            event.timestamp >= dateRange.start && event.timestamp < dateRange.end
        }
    }
    
    private var greenTotal: TimeInterval {
        StatsCalculator.greenTotal(filteredSegments)
    }
    
    private var redTotal: TimeInterval {
        StatsCalculator.redTotal(filteredSegments)
    }
    
    private var avgStreak: TimeInterval {
        StatsCalculator.avgGreenStreak(filteredSegments)
    }
    
    private var maxStreak: TimeInterval {
        StatsCalculator.maxGreenStreak(filteredSegments)
    }
    
    private var dailyTrend: [DailyStats] {
        StatsCalculator.dailyTrend(allSegments, in: dateRange)
    }

    private struct DailyStackPoint: Identifiable {
        let id = UUID()
        let date: Date
        let type: String
        let hours: Double
    }

    private var stackedTrendPoints: [DailyStackPoint] {
        dailyTrend.flatMap { stat in
            [
                DailyStackPoint(date: stat.date, type: "专注", hours: stat.greenTotal / 3600),
                DailyStackPoint(date: stat.date, type: "休息", hours: stat.redTotal / 3600)
            ]
        }
    }
    
    private var sessionListTitle: String {
        switch selectedPeriod {
        case .day: return "今日会话"
        case .week: return "本周会话"
        case .month: return "本月会话"
        case .year: return "今年会话"
        }
    }

    private var periodSubtitle: String {
        switch selectedPeriod {
        case .day: return "今日概览"
        case .week: return "本周概览"
        case .month: return "本月概览"
        case .year: return "今年概览"
        }
    }
    
    var body: some View {
        ZStack {
            OrbAmbientCanvas()
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    dashboardHeader
                    overviewCard

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        MetricCard(title: "休息时长", value: formatDuration(redTotal), color: AppTheme.Colors.warmAmber)
                        MetricCard(title: "专注比例", value: String(format: "%.0f%%", focusRatio * 100), color: AppTheme.Colors.focusTeal)
                        MetricCard(title: "平均专注", value: formatDuration(avgStreak), color: AppTheme.Colors.focusMintSoft)
                        MetricCard(title: "最长专注", value: formatDuration(maxStreak), color: .green)
                    }

                    rhythmCard

                    if dailyTrend.count > 1 {
                        trendCard
                    }

                    analysisCard

                    if !moodCounts.isEmpty {
                        moodCard
                    }

                    sessionListCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 20)
            }
        }
        .frame(minWidth: 620, minHeight: 760)
        .onAppear {
            eventStore.reload()
        }
        .sheet(isPresented: $showExportSheet) {
            DashboardExportSheet(
                options: $exportOptions,
                onCancel: { showExportSheet = false },
                onExport: {
                    showExportSheet = false
                    exportDashboardCard()
                }
            )
        }
        .alert("导出失败", isPresented: Binding(
            get: { exportError != nil },
            set: { _ in exportError = nil }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportError ?? "")
        }
    }

    private var dashboardHeader: some View {
        GlassCard(padding: 14) {
            HStack(spacing: 12) {
                StickerHeader(
                    imageName: "focus",
                    title: "专注复盘",
                    subtitle: periodSubtitle,
                    style: .leading,
                    iconSize: 34
                )

                Spacer(minLength: 8)

                Picker("Period", selection: $selectedPeriod) {
                    ForEach(StatsPeriod.allCases, id: \.self) { period in
                        Text(period.rawValue).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 190)
                .padding(4)
                .background(Color.white.opacity(0.34))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.white.opacity(0.35), lineWidth: 1)
                )

                PrimaryCapsuleButton(title: "导出小卡", systemImage: "square.and.arrow.up", style: .warm) {
                    showExportSheet = true
                }
            }
        }
    }

    private var overviewCard: some View {
        GlassCard(padding: 20) {
            VStack(spacing: 12) {
                overviewRing
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)

                VStack(spacing: 4) {
                    Text("看见节奏，而不是评判")
                        .font(.headline)
                        .foregroundColor(AppTheme.Colors.textPrimary)

                    Text("区间：\(dateRangeLabel)")
                        .font(.caption)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                .multilineTextAlignment(.center)

                HStack(spacing: 8) {
                    dashboardChip(
                        title: "专注",
                        value: formatDuration(greenTotal),
                        tint: AppTheme.Colors.focusTeal,
                        systemImage: "leaf.fill"
                    )
                    dashboardChip(
                        title: "休息",
                        value: formatDuration(redTotal),
                        tint: AppTheme.Colors.warmAmber,
                        systemImage: "cup.and.saucer.fill"
                    )
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .frame(maxWidth: .infinity, minHeight: 392)
        }
    }

    private var overviewRing: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.34), lineWidth: 20)

            Circle()
                .trim(from: clampedFocusRatio, to: 1)
                .stroke(
                    AngularGradient(
                        colors: [AppTheme.Colors.warmAmber.opacity(0.95), AppTheme.Colors.warmAmber.opacity(0.65)],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 20, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            Circle()
                .trim(from: 0, to: clampedFocusRatio)
                .stroke(
                    AngularGradient(
                        colors: [AppTheme.Colors.focusTeal, AppTheme.Colors.focusMintSoft],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 20, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: focusRatio)

            VStack(spacing: 2) {
                Text(formatDuration(greenTotal))
                    .font(.system(size: 50, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundColor(AppTheme.Colors.focusTeal)
                Text("专注时长")
                    .font(.headline)
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
        }
        .frame(width: 280, height: 280)
    }

    private var rhythmCard: some View {
        GlassCard(padding: 14) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("节奏")
                        .font(.headline)
                    Spacer()
                    Text(rhythmSubtitle)
                        .font(.caption)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    InsightCard(
                        title: "段数",
                        value: "\(focusBlocks) 专注 · \(breakBlocks) 休息",
                        systemImage: "rectangle.split.3x1",
                        tint: AppTheme.Colors.focusTeal
                    )
                    InsightCard(
                        title: "平均休息",
                        value: avgBreak > 0 ? formatDuration(avgBreak) : "—",
                        systemImage: "cup.and.saucer.fill",
                        tint: AppTheme.Colors.warmAmber
                    )
                    InsightCard(
                        title: "误触回滚",
                        value: pendingCount > 0 ? "\(rollbackCount) / \(pendingCount)" : "—",
                        systemImage: "arrow.uturn.backward.circle.fill",
                        tint: .orange
                    )
                    InsightCard(
                        title: "切换次数",
                        value: "\(switchCount)",
                        systemImage: "arrow.left.and.right",
                        tint: AppTheme.Colors.focusMintSoft
                    )
                }
            }
        }
    }

    private var trendCard: some View {
        GlassCard(padding: 14) {
            VStack(alignment: .leading, spacing: 10) {
                Text("趋势")
                    .font(.headline)

                Chart(stackedTrendPoints) { point in
                    BarMark(
                        x: .value("日期", point.date, unit: .day),
                        y: .value("小时", point.hours)
                    )
                    .foregroundStyle(by: .value("类型", point.type))
                }
                .frame(height: 154)
                .chartYAxisLabel("小时")
                .chartForegroundStyleScale([
                    "专注": AnyShapeStyle(AppTheme.Colors.focusTeal.gradient),
                    "休息": AnyShapeStyle(AppTheme.Colors.warmAmber.opacity(0.9))
                ])
                .chartLegend(position: .top, alignment: .leading)
            }
        }
    }

    private var analysisCard: some View {
        GlassCard(padding: 14) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(analysisTitle)
                        .font(.headline)
                    Spacer()
                    Text(analysisSubtitle)
                        .font(.caption)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(analysisItems) { item in
                        InsightCard(
                            title: item.title,
                            value: item.value,
                            systemImage: item.systemImage,
                            tint: item.tint
                        )
                    }
                }
            }
        }
    }

    private var moodCard: some View {
        GlassCard(padding: 14) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("心情")
                        .font(.headline)
                    Spacer()
                    Text("可选记录，用于理解节奏")
                        .font(.caption)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(moodCounts) { item in
                            MoodChip(mood: item.mood, count: item.count)
                        }
                    }
                }

                Text(moodInsightLine)
                    .font(.caption)
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
        }
    }

    private var sessionListCard: some View {
        GlassCard(padding: 14) {
            VStack(alignment: .leading, spacing: 10) {
                Text(sessionListTitle)
                    .font(.headline)

                if dailySessions.isEmpty {
                    Text("\(sessionListTitle)暂无记录")
                        .font(.caption)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(dailySessions) { session in
                            SessionCard(session: session)
                        }
                    }
                }
            }
        }
    }

    private func dashboardChip(title: String, value: String, tint: Color, systemImage: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.caption2.weight(.semibold))
                .foregroundColor(tint)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption2)
                    .foregroundColor(AppTheme.Colors.textMuted)
                Text(value)
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.32))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.36), lineWidth: 1)
        )
    }
    
    // MARK: - Session Data Computation
    
    struct SessionDisplay: Identifiable {
        let id: UUID
        let sessionId: UUID
        let startTime: Date
        let endTime: Date
        let greenDuration: TimeInterval
        let redDuration: TimeInterval
        let mergedCount: Int  // Number of physical sessions merged (1 = not merged)
        let mood: SessionMood?
        
        var totalDuration: TimeInterval { greenDuration + redDuration }
    }
    
    private var dailySessions: [SessionDisplay] {
        // Build parentSessionId mapping from events
        var parentMap: [UUID: UUID] = [:]
        for event in eventStore.events where event.parentSessionId != nil {
            parentMap[event.sessionId] = event.parentSessionId!
        }
        
        // Group segments by effective session ID (parent if exists, else self)
        let groupedByEffectiveId = Dictionary(grouping: filteredSegments) { segment -> UUID in
            parentMap[segment.sessionId] ?? segment.sessionId
        }
        
        return groupedByEffectiveId.compactMap { (effectiveSessionId, segments) -> SessionDisplay? in
            let green = StatsCalculator.greenTotal(segments)
            let red = StatsCalculator.redTotal(segments)
            let start = segments.map { $0.startTime }.min() ?? Date()
            let end = segments.map { $0.endTime ?? Date() }.max() ?? Date()
            
            let totalDuration = green + red
            
            // Filter out sessions shorter than 60 seconds
            guard totalDuration >= 60 else { return nil }
            
            // Count how many unique physical sessions were merged
            var uniqueSessionIds = Set(segments.map { $0.sessionId })
            uniqueSessionIds.insert(effectiveSessionId)
            let mergedCount = uniqueSessionIds.count
            let mood = latestMood(for: uniqueSessionIds)
            
            return SessionDisplay(
                id: UUID(),
                sessionId: effectiveSessionId,
                startTime: start,
                endTime: end,
                greenDuration: green,
                redDuration: red,
                mergedCount: mergedCount,
                mood: mood
            )
        }.sorted { $0.startTime > $1.startTime } // Newest first
    }
    
    // MARK: - Helpers
    
    private var focusRatio: Double {
        let total = greenTotal + redTotal
        guard total > 0 else { return 0 }
        return greenTotal / total
    }

    private var clampedFocusRatio: Double {
        min(max(focusRatio, 0), 1)
    }

    private var focusBlocks: Int {
        filteredSegments.filter { $0.type == .green }.count
    }

    private var breakBlocks: Int {
        filteredSegments.filter { $0.type == .red }.count
    }

    private var avgBreak: TimeInterval {
        guard breakBlocks > 0 else { return 0 }
        return redTotal / Double(breakBlocks)
    }

    private var pendingCount: Int {
        filteredEvents.filter { $0.type == .enterRedPending }.count
    }

    private var rollbackCount: Int {
        filteredEvents.filter { $0.type == .cancelRedPending }.count
    }

    private var switchCount: Int {
        max(focusBlocks + breakBlocks - 1, 0)
    }

    private var rhythmSubtitle: String {
        if pendingCount > 0 && rollbackCount > 0 {
            let rate = Double(rollbackCount) / Double(pendingCount)
            return String(format: "误触回滚 %.0f%%", rate * 100)
        }
        if focusBlocks + breakBlocks > 0 {
            return "看见节奏，而不是评判"
        }
        return "从一次专注开始"
    }

    private var totalDaysInRange: Int {
        let calendar = Calendar.current
        var count = 0
        var day = calendar.startOfDay(for: dateRange.start)
        while day < dateRange.end {
            count += 1
            day = calendar.date(byAdding: .day, value: 1, to: day)!
        }
        return max(count, 1)
    }

    private var focusDays: Int {
        dailyTrend.filter { $0.greenTotal > 0 }.count
    }

    private var avgFocusPerDay: TimeInterval {
        guard totalDaysInRange > 0 else { return 0 }
        return greenTotal / Double(totalDaysInRange)
    }

    private var bestFocusDayLabel: String {
        guard let best = dailyTrend.max(by: { $0.greenTotal < $1.greenTotal }),
              best.greenTotal > 0 else { return "—" }
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: best.date)
    }

    private var breakRatioPercent: String {
        let total = greenTotal + redTotal
        guard total > 0 else { return "—" }
        return String(format: "%.0f%%", (redTotal / total) * 100)
    }

    private func peakFocusHourLabel() -> String {
        let calendar = Calendar.current
        var buckets: [Int: TimeInterval] = [:]
        let segments = filteredSegments.filter { $0.type == .green }

        for segment in segments {
            let end = segment.endTime ?? Date()
            var current = segment.startTime
            while current < end {
                guard let hourInterval = calendar.dateInterval(of: .hour, for: current) else { break }
                let hourEnd = hourInterval.end
                let sliceEnd = min(end, hourEnd)
                let hour = calendar.component(.hour, from: current)
                buckets[hour, default: 0] += sliceEnd.timeIntervalSince(current)
                current = sliceEnd
            }
        }

        guard let best = buckets.max(by: { $0.value < $1.value }), best.value > 0 else {
            return "—"
        }
        let next = (best.key + 1) % 24
        return String(format: "%02d:00-%02d:00", best.key, next)
    }

    private struct AnalysisItem: Identifiable {
        let id = UUID()
        let title: String
        let value: String
        let systemImage: String
        let tint: Color
    }

    private var analysisTitle: String {
        switch selectedPeriod {
        case .day: return "当日分析"
        case .week: return "本周分析"
        case .month: return "本月分析"
        case .year: return "年度分析"
        }
    }

    private var analysisSubtitle: String {
        if greenTotal + redTotal == 0 {
            return "暂无数据"
        }
        return "关注节奏与恢复"
    }

    private var analysisItems: [AnalysisItem] {
        if selectedPeriod == .day {
            return [
                AnalysisItem(title: "高效时段", value: peakFocusHourLabel(), systemImage: "clock.fill", tint: .teal),
                AnalysisItem(title: "专注时长", value: formatDuration(greenTotal), systemImage: "leaf.fill", tint: AppTheme.Colors.focusMintSoft),
                AnalysisItem(title: "休息占比", value: breakRatioPercent, systemImage: "cup.and.saucer.fill", tint: AppTheme.Colors.warmOrange),
                AnalysisItem(title: "切换次数", value: "\(switchCount)", systemImage: "arrow.left.and.right", tint: .orange)
            ]
        }

        return [
            AnalysisItem(title: "最专注的一天", value: bestFocusDayLabel, systemImage: "star.fill", tint: AppTheme.Colors.focusMintSoft),
            AnalysisItem(title: "平均每日专注", value: formatDuration(avgFocusPerDay), systemImage: "gauge.medium", tint: .teal),
            AnalysisItem(title: "有专注的天数", value: "\(focusDays)/\(totalDaysInRange)", systemImage: "calendar", tint: .green),
            AnalysisItem(title: "休息占比", value: breakRatioPercent, systemImage: "cup.and.saucer.fill", tint: AppTheme.Colors.warmOrange)
        ]
    }

    private struct MoodCountItem: Identifiable {
        let id = UUID()
        let mood: SessionMood
        let count: Int
    }

    private var moodCounts: [MoodCountItem] {
        let moods: [SessionMood] = filteredEvents.compactMap { event in
            guard event.type == .sessionReflection else { return nil }
            guard let raw = event.meta?["mood"] else { return nil }
            return SessionMood(rawValue: raw)
        }

        let grouped = Dictionary(grouping: moods, by: { $0 })
        return grouped
            .map { MoodCountItem(mood: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }
    }

    private var moodInsightLine: String {
        guard let top = moodCounts.first else { return "每一次记录都是一次更懂自己的开始。" }
        switch top.mood {
        case .calm:
            return "你更常选择「平静」。继续维持这个节奏就很好。"
        case .good:
            return "你更常选择「满足」。把有效的节奏留给自己。"
        case .stressed:
            return "你更常选择「焦虑」。下次试试把第一段专注缩短一点。"
        case .tired:
            return "你更常选择「疲惫」。给自己留一点恢复空间也很重要。"
        }
    }

    private func latestMood(for sessionIds: Set<UUID>) -> SessionMood? {
        let events = eventStore.events
            .filter { $0.type == .sessionReflection && sessionIds.contains($0.sessionId) }
            .sorted { $0.timestamp > $1.timestamp }
        guard let raw = events.first?.meta?["mood"] else { return nil }
        return SessionMood(rawValue: raw)
    }
    
    private func formatDuration(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = Int(interval) / 60 % 60
        if hours > 0 {
            return String(format: "%dh %02dm", hours, minutes)
        } else {
            let seconds = Int(interval) % 60
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    private func colorFor(_ type: EventType) -> Color {
        switch type {
        case .sessionStart, .switchToGreen, .cancelRedPending:
            return .green
        case .enterRedPending:
            return .orange
        case .confirmRedStart:
            return .red
        case .sessionEnd:
            return .gray
        case .sessionReflection:
            return .blue
        }
    }

    private var dateRangeLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        let start = formatter.string(from: dateRange.start)
        let end = formatter.string(from: dateRange.end.addingTimeInterval(-60))
        return "\(start) - \(end)"
    }

    private func exportDashboardCard() {
        let exportStackedPoints = stackedTrendPoints.map {
            DashboardExportCardView.ExportStackPoint(date: $0.date, type: $0.type, hours: $0.hours)
        }
        let caption = exportOptions.captionMode.resolvedText(
            custom: exportOptions.customCaption,
            fallback: insightCaption()
        )
        let content = DashboardExportCardView(
            options: exportOptions,
            periodTitle: analysisTitle,
            dateRangeLabel: dateRangeLabel,
            captionText: caption,
            greenTotal: greenTotal,
            redTotal: redTotal,
            focusRatio: focusRatio,
            avgStreak: avgStreak,
            maxStreak: maxStreak,
            rhythmItems: [
                ("段数", "\(focusBlocks) 专注 · \(breakBlocks) 休息"),
                ("平均休息", avgBreak > 0 ? formatDuration(avgBreak) : "—"),
                ("误触回滚", pendingCount > 0 ? "\(rollbackCount) / \(pendingCount)" : "—"),
                ("切换次数", "\(switchCount)")
            ],
            analysisItems: analysisItems.map { ($0.title, $0.value) },
            moodItems: moodCounts.map { ($0.mood.title, $0.count) },
            trendItems: exportStackedPoints
        )

        let renderer = ImageRenderer(content: content)
        renderer.scale = exportOptions.scale
        renderer.isOpaque = exportOptions.visualStyle.isOpaque
        renderer.proposedSize = exportOptions.proposedSize

        guard let nsImage = renderer.nsImage else {
            exportError = "无法生成图片"
            return
        }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType.png]
        panel.nameFieldStringValue = "FocusOrb-\(analysisTitle)-\(exportDateString()).png"

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
        return formatter.string(from: Date())
    }

    private func insightCaption() -> String {
        // 洞察型：具体、可执行、不过度情绪化
        switch selectedPeriod {
        case .day:
            if greenTotal + redTotal == 0 { return "从一次专注开始，系统会自动生成你的节奏洞察。" }
            let peak = peakFocusHourLabel()
            if peak != "—" && switchCount >= 10 {
                return "你在 \(peak) 更容易进入状态。今天切换 \(switchCount) 次，试试把第一段专注缩短到 15–20 分钟。"
            }
            if peak != "—" {
                return "你在 \(peak) 更容易进入状态。把重要任务放到这个窗口，会更省力。"
            }
            return "今天的节奏已经被记录下来。明天也可以从一个更短的专注段开始。"
        case .week, .month, .year:
            if greenTotal + redTotal == 0 { return "这段时间暂无记录。开始一次专注就能生成趋势与洞察。" }
            let best = bestFocusDayLabel
            let avg = formatDuration(avgFocusPerDay)
            return "最专注的一天是 \(best)，平均每天专注 \(avg)。把这个节奏复制到下周，会更稳。"
        }
    }
}

// MARK: - Export Options

private struct DashboardExportOptions {
    enum VisualStyle: String, CaseIterable, Identifiable {
        case orb = "悬浮窗同款"

        var id: String { rawValue }

        var isOpaque: Bool { true }
    }

    enum Template: String, CaseIterable, Identifiable {
        case long = "长图（推荐）"
        case poster4x5 = "4:5"
        case story9x16 = "9:16"
        case square1x1 = "1:1"
        var id: String { rawValue }
    }

    enum Density: String, CaseIterable, Identifiable {
        case comfy = "舒展"
        case compact = "紧凑"
        var id: String { rawValue }
    }

    enum CaptionMode: String, CaseIterable, Identifiable {
        case off = "关闭"
        case `default` = "默认洞察"
        case custom = "自定义"
        var id: String { rawValue }

        func resolvedText(custom: String, fallback: String) -> String? {
            switch self {
            case .off:
                return nil
            case .default:
                return fallback
            case .custom:
                return custom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? fallback : custom
            }
        }
    }

    enum CaptionPosition: String, CaseIterable, Identifiable {
        case top = "顶部"
        case bottom = "底部"
        var id: String { rawValue }
    }

    enum ExportScale: String, CaseIterable, Identifiable {
        case x2 = "2x"
        case x3 = "3x"
        var id: String { rawValue }

        var value: CGFloat {
            switch self {
            case .x2: return 2
            case .x3: return 3
            }
        }
    }

    var visualStyle: VisualStyle = .orb
    var template: Template = .long
    var density: Density = .comfy

    var captionMode: CaptionMode = .default
    var captionPosition: CaptionPosition = .bottom
    var customCaption: String = ""

    var showTitle: Bool = true
    var showDateRange: Bool = true
    var showHero: Bool = true
    var showRhythm: Bool = true
    var showAnalysis: Bool = true
    var showMood: Bool = true
    var showTrend: Bool = true

    var exportScale: ExportScale = .x3

    var scale: CGFloat { exportScale.value }

    var width: CGFloat {
        // 朋友圈/小红书更稳的宽度：1080px 级别（配合 3x）
        // 这里用点数，最终像素 = width * scale
        420
    }

    var proposedSize: ProposedViewSize {
        let w = width
        switch template {
        case .long:
            return ProposedViewSize(width: w, height: nil)
        case .poster4x5:
            return ProposedViewSize(width: w, height: w * (5.0 / 4.0))
        case .story9x16:
            return ProposedViewSize(width: w, height: w * (16.0 / 9.0))
        case .square1x1:
            return ProposedViewSize(width: w, height: w)
        }
    }
}

private struct DashboardExportSheet: View {
    @Binding var options: DashboardExportOptions
    let onCancel: () -> Void
    let onExport: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("导出小卡")
                    .font(.headline)
                Spacer()
                Text("如果内容超出比例，会建议改用长图")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Form {
                Picker("版式", selection: $options.template) {
                    ForEach(DashboardExportOptions.Template.allCases) { template in
                        Text(template.rawValue).tag(template)
                    }
                }
                Picker("密度", selection: $options.density) {
                    ForEach(DashboardExportOptions.Density.allCases) { density in
                        Text(density.rawValue).tag(density)
                    }
                }
                Picker("清晰度", selection: $options.exportScale) {
                    ForEach(DashboardExportOptions.ExportScale.allCases) { s in
                        Text(s.rawValue).tag(s)
                    }
                }

                Section("内容") {
                    Toggle("标题与品牌", isOn: $options.showTitle)
                    Toggle("日期范围", isOn: $options.showDateRange)
                    Toggle("主视觉（专注/比例）", isOn: $options.showHero)
                    Toggle("节奏", isOn: $options.showRhythm)
                    Toggle("分析", isOn: $options.showAnalysis)
                    Toggle("心情", isOn: $options.showMood)
                    Toggle("趋势图", isOn: $options.showTrend)
                }

                Section("句子") {
                    Picker("句子", selection: $options.captionMode) {
                        ForEach(DashboardExportOptions.CaptionMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    Picker("位置", selection: $options.captionPosition) {
                        ForEach(DashboardExportOptions.CaptionPosition.allCases) { pos in
                            Text(pos.rawValue).tag(pos)
                        }
                    }
                    if options.captionMode == .custom {
                        TextEditor(text: $options.customCaption)
                            .frame(height: 72)
                    }
                }
            }
            .frame(width: 460)

            HStack {
                Spacer()
                Button("取消", action: onCancel)
                Button("导出", action: onExport)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 520)
    }
}

private struct DashboardExportCardView: View {
    struct ExportStackPoint: Identifiable {
        let id = UUID()
        let date: Date
        let type: String
        let hours: Double
    }

    let options: DashboardExportOptions
    let periodTitle: String
    let dateRangeLabel: String
    let captionText: String?
    let greenTotal: TimeInterval
    let redTotal: TimeInterval
    let focusRatio: Double
    let avgStreak: TimeInterval
    let maxStreak: TimeInterval
    let rhythmItems: [(String, String)]
    let analysisItems: [(String, String)]
    let moodItems: [(String, Int)]
    let trendItems: [ExportStackPoint]

    var body: some View {
        ZStack {
            OrbExportBackground(cornerRadius: 28)
            exportLongCard
        }
    }

    private var exportLongCard: some View {
        VStack(alignment: .leading, spacing: options.density == .comfy ? 14 : 10) {
            if options.showTitle || options.showDateRange {
                headerBlock
            }

            if let captionText, options.captionPosition == .top {
                captionBlock(captionText)
            }

            if options.showHero {
                heroBlock
            }

            if options.showRhythm {
                sectionGrid(title: "节奏", items: rhythmItems)
            }

            if options.showAnalysis {
                sectionGrid(title: "分析", items: analysisItems)
            }

            if options.showMood && !moodItems.isEmpty {
                moodBlock
            }

            if options.showTrend && trendItems.count > 1 {
                trendBlock
            }

            if let captionText, options.captionPosition == .bottom {
                captionBlock(captionText)
            }

            footerBlock
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var headerBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            if options.showTitle {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("FocusOrb")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(secondaryText)
                        Text(periodTitle)
                            .font(.title3.weight(.semibold))
                            .foregroundColor(primaryText)
                    }
                    Spacer()
                    Image(systemName: "sparkles")
                        .font(.title3)
                        .foregroundColor(AppTheme.Colors.warmAmber)
                }
            }
            if options.showDateRange {
                Text(dateRangeLabel)
                    .font(.caption)
                    .foregroundColor(secondaryText)
            }
        }
    }

    private func captionBlock(_ text: String) -> some View {
        OrbExportSurface(padding: 12, cornerRadius: 16) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "quote.bubble.fill")
                    .foregroundColor(AppTheme.Colors.warmAmber)
                    .font(.callout)
                    .padding(.top, 1)
                Text(text)
                    .font(.callout)
                    .foregroundColor(primaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var heroBlock: some View {
        OrbExportSurface(padding: 14, cornerRadius: 20, emphasized: true) {
            HStack(spacing: 14) {
                let clampedRatio = min(max(focusRatio, 0), 1)

                ZStack {
                    Circle()
                        .stroke(AppTheme.Colors.exportSurfaceStroke.opacity(0.90), lineWidth: 12)

                    Circle()
                        .trim(from: clampedRatio, to: 1)
                        .stroke(
                            AngularGradient(
                                colors: [AppTheme.Colors.warmAmber.opacity(0.95), AppTheme.Colors.warmAmber.opacity(0.70)],
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 12, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))

                    Circle()
                        .trim(from: 0, to: clampedRatio)
                        .stroke(
                            AngularGradient(colors: [accent, accent.opacity(0.76)], center: .center),
                            style: StrokeStyle(lineWidth: 12, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 2) {
                        Text(formatDuration(greenTotal))
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundColor(primaryText)
                        Text("专注时长")
                            .font(.caption2)
                            .foregroundColor(secondaryText)
                    }
                }
                .frame(width: 120, height: 120)

                VStack(alignment: .leading, spacing: 10) {
                    pillMetric("休息", formatDuration(redTotal))
                    pillMetric("专注比例", String(format: "%.0f%%", focusRatio * 100))
                    HStack(spacing: 10) {
                        pillMetric("平均专注", formatDuration(avgStreak))
                        pillMetric("最长专注", formatDuration(maxStreak))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func sectionGrid(title: String, items: [(String, String)]) -> some View {
        OrbExportSurface(padding: 14, cornerRadius: 20) {
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(secondaryText)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(Array(items.prefix(4).enumerated()), id: \.offset) { _, item in
                        OrbExportSurface(padding: 10, cornerRadius: 14) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.0)
                                    .font(.caption2)
                                    .foregroundColor(secondaryText)
                                Text(item.1)
                                    .font(.callout.weight(.semibold).monospacedDigit())
                                    .foregroundColor(primaryText)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
        }
    }

    private var moodBlock: some View {
        OrbExportSurface(padding: 14, cornerRadius: 20) {
            VStack(alignment: .leading, spacing: 10) {
                Text("心情")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(secondaryText)
                HStack(spacing: 10) {
                    ForEach(Array(moodItems.prefix(6).enumerated()), id: \.offset) { _, item in
                        HStack(spacing: 6) {
                            Text(item.0)
                                .font(.caption)
                                .foregroundColor(primaryText)
                            Text("×\(item.1)")
                                .font(.caption2.monospacedDigit())
                                .foregroundColor(secondaryText)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(AppTheme.Colors.exportSurfaceStrong.opacity(0.92))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(AppTheme.Colors.exportSurfaceStroke, lineWidth: 1)
                        )
                    }
                }
            }
        }
    }

    private var trendBlock: some View {
        OrbExportSurface(padding: 14, cornerRadius: 20) {
            VStack(alignment: .leading, spacing: 10) {
                Text("趋势")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(secondaryText)
                Chart(trendItems) { point in
                    BarMark(
                        x: .value("日期", point.date, unit: .day),
                        y: .value("小时", point.hours)
                    )
                    .foregroundStyle(by: .value("类型", point.type))
                }
                .frame(height: options.density == .comfy ? 160 : 130)
                .chartForegroundStyleScale([
                    "专注": AnyShapeStyle(accent.gradient),
                    "休息": AnyShapeStyle(AppTheme.Colors.warmAmber.opacity(0.88))
                ])
                .chartLegend(position: .top, alignment: .leading)
            }
        }
    }

    private var footerBlock: some View {
        HStack {
            Text("FocusOrb · 看见节奏")
                .font(.caption2)
                .foregroundColor(secondaryText)
            Spacer()
            Text(dateRangeLabel)
                .font(.caption2.monospacedDigit())
                .foregroundColor(secondaryText.opacity(0.9))
        }
        .padding(.horizontal, 4)
        .padding(.top, 4)
    }

    private func pillMetric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundColor(secondaryText)
            Text(value)
                .font(.callout.weight(.semibold).monospacedDigit())
                .foregroundColor(primaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(AppTheme.Colors.exportSurfaceStrong.opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppTheme.Colors.exportSurfaceStroke, lineWidth: 1)
        )
    }

    private var accent: Color {
        AppTheme.Colors.focusTeal
    }

    private var primaryText: Color {
        AppTheme.Colors.exportTextPrimary
    }

    private var secondaryText: Color {
        AppTheme.Colors.exportTextSecondary
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
}

// MARK: - Metric Card Component

struct MetricCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                Text(value)
                    .font(.title2.monospacedDigit())
                    .fontWeight(.semibold)
                    .foregroundColor(color)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Session Card Component

struct SessionCard: View {
    let session: DashboardView.SessionDisplay
    
    var body: some View {
        GlassCard {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("\(session.startTime, style: .time) - \(session.endTime, style: .time)")
                            .font(.headline)

                        if let mood = session.mood {
                            HStack(spacing: 4) {
                                Image(systemName: mood.symbolName)
                                    .font(.caption2)
                                Text(mood.title)
                                    .font(.caption2)
                            }
                            .foregroundColor(AppTheme.Colors.textSecondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.30))
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .stroke(Color.white.opacity(0.36), lineWidth: 1)
                            )
                            .accessibilityLabel(Text("心情：\(mood.title)"))
                        }

                        // Merge badge
                        if session.mergedCount > 1 {
                            Text("×\(session.mergedCount)")
                                .font(.caption2)
                                .foregroundColor(AppTheme.Colors.textSecondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.white.opacity(0.30))
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .stroke(Color.white.opacity(0.34), lineWidth: 1)
                                )
                        }
                    }

                    Text("总计 \(formatDuration(session.totalDuration))")
                        .font(.caption)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    // Green Time
                    HStack(spacing: 6) {
                        Text(formatDuration(session.greenDuration))
                            .font(.system(.body, design: .monospaced))
                            .fontWeight(.medium)
                            .foregroundColor(.primary)

                        Circle().fill(AppTheme.Colors.focusMintSoft).frame(width: 8, height: 8)
                    }

                    // Red Time (only if exists)
                    if session.redDuration > 0 {
                        HStack(spacing: 6) {
                            Text(formatDuration(session.redDuration))
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(AppTheme.Colors.textSecondary)

                            Circle().fill(AppTheme.Colors.warmOrange).frame(width: 8, height: 8)
                        }
                    }
                }
            }
        }
    }
    
    private func formatDuration(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = Int(interval) / 60 % 60
        if hours > 0 {
            return String(format: "%dh %02dm", hours, minutes)
        } else {
            let seconds = Int(interval) % 60
            if minutes == 0 && seconds > 0 {
                return "<1m"
            }
            return String(format: "%02dm", minutes)
        }
    }
}

// MARK: - Insight Card Component

struct InsightCard: View {
    let title: String
    let value: String
    let systemImage: String
    let tint: Color

    var body: some View {
        GlassCard(padding: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(tint.opacity(0.18))
                    Image(systemName: systemImage)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(tint)
                }
                .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    Text(value)
                        .font(.callout.monospacedDigit())
                        .fontWeight(.semibold)
                        .foregroundColor(AppTheme.Colors.textPrimary)
                }
                Spacer(minLength: 0)
            }
        }
    }
}

// MARK: - Mood Chip

struct MoodChip: View {
    let mood: SessionMood
    let count: Int

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: mood.symbolName)
                .font(.caption2)
            Text(mood.title)
                .font(.caption)
            Text("×\(count)")
                .font(.caption2.monospacedDigit())
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.28))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.34), lineWidth: 1)
        )
        .accessibilityLabel(Text("\(mood.title) \(count) 次"))
    }
}
