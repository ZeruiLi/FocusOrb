import SwiftUI
import Charts

enum StatsPeriod: String, CaseIterable {
    case day = "日"
    case week = "周"
    case month = "月"
    case year = "年"
}

struct DashboardView: View {
    @ObservedObject var eventStore: EventStore
    @State private var selectedPeriod: StatsPeriod = .day
    
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
    
    private var sessionListTitle: String {
        switch selectedPeriod {
        case .day: return "今日会话"
        case .week: return "本周会话"
        case .month: return "本月会话"
        case .year: return "今年会话"
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header with Period Picker
                HStack {
                    Text("Focus Dashboard")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    Picker("Period", selection: $selectedPeriod) {
                        ForEach(StatsPeriod.allCases, id: \.self) { period in
                            Text(period.rawValue).tag(period)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                }
                .padding(.horizontal)
                
                // Main Stats Ring
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 20)
                    
                    Circle()
                        .trim(from: 0, to: focusRatio)
                        .stroke(
                            AngularGradient(colors: [.mint, .teal], center: .center),
                            style: StrokeStyle(lineWidth: 20, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(), value: focusRatio)
                    
                    VStack {
                        Text(formatDuration(greenTotal))
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                        Text("专注时长")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(width: 220, height: 220)
                .padding(.top, 10)
                
                // Metric Cards
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    MetricCard(title: "休息时长", value: formatDuration(redTotal), color: .red)
                    MetricCard(title: "专注比例", value: String(format: "%.0f%%", focusRatio * 100), color: .teal)
                    MetricCard(title: "平均专注", value: formatDuration(avgStreak), color: .mint)
                    MetricCard(title: "最长专注", value: formatDuration(maxStreak), color: .green)
                }
                .padding(.horizontal)
                
                // Trend Chart
                if dailyTrend.count > 1 {
                    VStack(alignment: .leading) {
                        Text("趋势")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        Chart(dailyTrend) { stat in
                            BarMark(
                                x: .value("日期", stat.date, unit: .day),
                                y: .value("专注", stat.greenTotal / 3600)
                            )
                            .foregroundStyle(.mint.gradient)
                        }
                        .frame(height: 150)
                        .padding(.horizontal)
                        .chartYAxisLabel("小时")
                    }
                }
                
                // Session List
                VStack(alignment: .leading) {
                    Text(sessionListTitle)
                        .font(.headline)
                        .padding(.horizontal)
                    
                    if dailySessions.isEmpty {
                        Text("今日暂无专注记录")
                            .foregroundColor(.secondary)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(dailySessions) { session in
                                SessionCard(session: session)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
        .frame(minWidth: 500, minHeight: 650)
        .onAppear {
            eventStore.reload()
        }
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
            let uniqueSessionIds = Set(segments.map { $0.sessionId })
            let mergedCount = uniqueSessionIds.count
            
            return SessionDisplay(
                id: UUID(),
                sessionId: effectiveSessionId,
                startTime: start,
                endTime: end,
                greenDuration: green,
                redDuration: red,
                mergedCount: mergedCount
            )
        }.sorted { $0.startTime > $1.startTime } // Newest first
    }
    
    // MARK: - Helpers
    
    private var focusRatio: Double {
        let total = greenTotal + redTotal
        guard total > 0 else { return 0 }
        return greenTotal / total
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
        }
    }
}

// MARK: - Metric Card Component

struct MetricCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.title2.monospacedDigit())
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Material.thin)
        .cornerRadius(12)
    }
}

// MARK: - Session Card Component

struct SessionCard: View {
    let session: DashboardView.SessionDisplay
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("\(session.startTime, style: .time) - \(session.endTime, style: .time)")
                        .font(.headline)
                    
                    // Merge badge
                    if session.mergedCount > 1 {
                        Text("×\(session.mergedCount)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
                
                Text("总计 \(formatDuration(session.totalDuration))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                // Green Time
                HStack(spacing: 6) {
                    Text(formatDuration(session.greenDuration))
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Circle().fill(Color.mint).frame(width: 8, height: 8)
                }
                
                // Red Time (only if exists)
                if session.redDuration > 0 {
                    HStack(spacing: 6) {
                        Text(formatDuration(session.redDuration))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                        
                        Circle().fill(Color.red).frame(width: 8, height: 8)
                    }
                }
            }
        }
        .padding()
        .background(Material.thin)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
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

