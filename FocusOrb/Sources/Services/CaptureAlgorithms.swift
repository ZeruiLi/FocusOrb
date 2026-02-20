import Foundation

enum CaptureAlgorithms {
    static func sortedActiveTasks(_ tasks: [TaskItem]) -> [TaskItem] {
        let active = tasks.filter { !$0.isCompleted }
        let hasManualOrder = active.contains { $0.manualOrder != nil }

        if hasManualOrder {
            return active.sorted { lhs, rhs in
                let lhsOrder = lhs.manualOrder ?? Int.max
                let rhsOrder = rhs.manualOrder ?? Int.max
                if lhsOrder != rhsOrder {
                    return lhsOrder < rhsOrder
                }
                if lhs.createdAt != rhs.createdAt {
                    return lhs.createdAt < rhs.createdAt
                }
                return lhs.id.uuidString < rhs.id.uuidString
            }
        }

        return active.sorted { lhs, rhs in
            if lhs.createdAt != rhs.createdAt {
                return lhs.createdAt < rhs.createdAt
            }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    static func sortedCompletedTasks(_ tasks: [TaskItem]) -> [TaskItem] {
        tasks
            .filter(\.isCompleted)
            .sorted { lhs, rhs in
                let lhsDate = lhs.completedAt ?? lhs.updatedAt
                let rhsDate = rhs.completedAt ?? rhs.updatedAt
                if lhsDate != rhsDate {
                    return lhsDate > rhsDate
                }
                return lhs.id.uuidString < rhs.id.uuidString
            }
    }

    static func topTask(from tasks: [TaskItem]) -> TaskItem? {
        sortedActiveTasks(tasks).first
    }

    static func normalizeManualOrder(_ idsInOrder: [UUID], activeTasks: [TaskItem]) -> [(UUID, Int)] {
        var resolved = idsInOrder
        let existingIds = Set(idsInOrder)
        let fallback = sortedActiveTasks(activeTasks).map(\.id).filter { !existingIds.contains($0) }
        resolved.append(contentsOf: fallback)
        return resolved.enumerated().map { ($0.element, $0.offset) }
    }

    static func clipIDsToDeleteForRetention(clipsByOldestFirst: [ClipItem], maxCount: Int) -> [UUID] {
        guard clipsByOldestFirst.count > maxCount else { return [] }

        let deleteCount = clipsByOldestFirst.count - maxCount
        let candidates = clipsByOldestFirst.filter { !$0.isPinned }
        return Array(candidates.prefix(deleteCount)).map(\.id)
    }

    static func shouldIgnoreClip(content: String, latestContent: String?) -> Bool {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return true
        }
        return latestContent == content
    }
}

