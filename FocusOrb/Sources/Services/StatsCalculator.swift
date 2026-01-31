import Foundation

struct DailyStats: Identifiable {
    let id = UUID()
    let date: Date
    let greenTotal: TimeInterval
    let redTotal: TimeInterval
}

struct SessionStats {
    let total: TimeInterval
    let green: TimeInterval
    let red: TimeInterval
    let segments: [OrbSegment]
    let avgGreenStreak: TimeInterval
    let maxGreenStreak: TimeInterval
}

class StatsCalculator {
    static func calculateSegments(from events: [OrbEvent]) -> [OrbSegment] {
        var segments: [OrbSegment] = []
        var currentStart: Date?
        var currentType: SegmentType?
        var currentSessionId: UUID?

        let sortedEvents = events.sorted { $0.timestamp < $1.timestamp }

        for event in sortedEvents {
            switch event.type {
            case .sessionStart:
                if let start = currentStart, let type = currentType, let sessionId = currentSessionId {
                    segments.append(OrbSegment(id: UUID(), sessionId: sessionId, startTime: start, endTime: event.timestamp, type: type))
                }
                currentStart = event.timestamp
                currentType = .green
                currentSessionId = event.sessionId

            case .switchToGreen, .cancelRedPending:
                if let start = currentStart, currentType == .red, let sessionId = currentSessionId {
                    segments.append(OrbSegment(id: UUID(), sessionId: sessionId, startTime: start, endTime: event.timestamp, type: .red))
                    currentStart = event.timestamp
                    currentType = .green
                } else if currentType == nil {
                    currentStart = event.timestamp
                    currentType = .green
                    currentSessionId = event.sessionId
                }

            case .confirmRedStart:
                if let start = currentStart, currentType == .green, let sessionId = currentSessionId {
                    segments.append(OrbSegment(id: UUID(), sessionId: sessionId, startTime: start, endTime: event.timestamp, type: .green))
                }
                currentStart = event.timestamp
                currentType = .red
                currentSessionId = event.sessionId

            case .sessionEnd:
                if let start = currentStart, let type = currentType, let sessionId = currentSessionId {
                    segments.append(OrbSegment(id: UUID(), sessionId: sessionId, startTime: start, endTime: event.timestamp, type: type))
                }
                currentStart = nil
                currentType = nil
                currentSessionId = nil

            default:
                break
            }
        }

        return segments
    }

    static func splitSegmentsByDay(_ segments: [OrbSegment]) -> [OrbSegment] {
        var result: [OrbSegment] = []
        let calendar = Calendar.current

        for segment in segments {
            guard let endTime = segment.endTime else {
                result.append(segment)
                continue
            }

            let startDay = calendar.startOfDay(for: segment.startTime)
            let endDay = calendar.startOfDay(for: endTime)

            if startDay == endDay {
                result.append(segment)
                continue
            }

            var currentStart = segment.startTime
            var currentDay = startDay

            while currentDay < endDay {
                let nextDay = calendar.date(byAdding: .day, value: 1, to: currentDay)!
                let midnight = calendar.startOfDay(for: nextDay)

                result.append(
                    OrbSegment(
                        id: UUID(),
                        sessionId: segment.sessionId,
                        startTime: currentStart,
                        endTime: midnight,
                        type: segment.type
                    )
                )

                currentStart = midnight
                currentDay = nextDay
            }

            result.append(
                OrbSegment(
                    id: UUID(),
                    sessionId: segment.sessionId,
                    startTime: currentStart,
                    endTime: endTime,
                    type: segment.type
                )
            )
        }

        return result
    }

    static func filterSegments(_ segments: [OrbSegment], in range: DateInterval) -> [OrbSegment] {
        segments.filter { segment in
            guard let endTime = segment.endTime else { return false }
            return segment.startTime >= range.start && endTime <= range.end
        }
    }

    static func todayRange() -> DateInterval {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        return DateInterval(start: start, end: end)
    }

    static func thisWeekRange() -> DateInterval {
        let calendar = Calendar.current
        let today = Date()
        let weekday = calendar.component(.weekday, from: today)
        let daysFromMonday = (weekday + 5) % 7
        let monday = calendar.date(byAdding: .day, value: -daysFromMonday, to: calendar.startOfDay(for: today))!
        let nextMonday = calendar.date(byAdding: .day, value: 7, to: monday)!
        return DateInterval(start: monday, end: nextMonday)
    }

    static func thisMonthRange() -> DateInterval {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: Date())
        let start = calendar.date(from: components)!
        let end = calendar.date(byAdding: .month, value: 1, to: start)!
        return DateInterval(start: start, end: end)
    }

    static func thisYearRange() -> DateInterval {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year], from: Date())
        let start = calendar.date(from: components)!
        let end = calendar.date(byAdding: .year, value: 1, to: start)!
        return DateInterval(start: start, end: end)
    }

    static func greenTotal(_ segments: [OrbSegment]) -> TimeInterval {
        segments.filter { $0.type == .green }.reduce(0) { $0 + $1.duration }
    }

    static func redTotal(_ segments: [OrbSegment]) -> TimeInterval {
        segments.filter { $0.type == .red }.reduce(0) { $0 + $1.duration }
    }

    static func avgGreenStreak(_ segments: [OrbSegment]) -> TimeInterval {
        let greenSegments = segments.filter { $0.type == .green }
        guard !greenSegments.isEmpty else { return 0 }
        let total = greenSegments.reduce(0) { $0 + $1.duration }
        return total / Double(greenSegments.count)
    }

    static func maxGreenStreak(_ segments: [OrbSegment]) -> TimeInterval {
        segments.filter { $0.type == .green }.map(\.duration).max() ?? 0
    }

    static func dailyTrend(_ segments: [OrbSegment], in range: DateInterval) -> [DailyStats] {
        let calendar = Calendar.current
        let split = splitSegmentsByDay(segments)

        var dailyData: [Date: (green: TimeInterval, red: TimeInterval)] = [:]

        for segment in split {
            let day = calendar.startOfDay(for: segment.startTime)
            guard day >= range.start && day < range.end else { continue }

            var current = dailyData[day] ?? (green: 0, red: 0)
            if segment.type == .green {
                current.green += segment.duration
            } else {
                current.red += segment.duration
            }
            dailyData[day] = current
        }

        var result: [DailyStats] = []
        var currentDay = calendar.startOfDay(for: range.start)
        while currentDay < range.end {
            let data = dailyData[currentDay] ?? (green: 0, red: 0)
            result.append(DailyStats(date: currentDay, greenTotal: data.green, redTotal: data.red))
            currentDay = calendar.date(byAdding: .day, value: 1, to: currentDay)!
        }

        return result
    }

    static func sessionStats(events: [OrbEvent]) -> SessionStats {
        let segments = calculateSegments(from: events)
        let green = greenTotal(segments)
        let red = redTotal(segments)

        return SessionStats(
            total: green + red,
            green: green,
            red: red,
            segments: segments,
            avgGreenStreak: avgGreenStreak(segments),
            maxGreenStreak: maxGreenStreak(segments)
        )
    }
}

