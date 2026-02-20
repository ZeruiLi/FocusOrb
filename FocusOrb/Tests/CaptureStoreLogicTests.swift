import XCTest
@testable import FocusOrb

final class CaptureStoreLogicTests: XCTestCase {
    func testNormalizeManualOrderIncludesAllActiveTasks() {
        let now = Date()
        let first = TaskItem(id: UUID(), title: "A", createdAt: now, updatedAt: now)
        let second = TaskItem(id: UUID(), title: "B", createdAt: now.addingTimeInterval(1), updatedAt: now.addingTimeInterval(1))
        let third = TaskItem(id: UUID(), title: "C", createdAt: now.addingTimeInterval(2), updatedAt: now.addingTimeInterval(2))

        let normalized = CaptureAlgorithms.normalizeManualOrder(
            [third.id, first.id],
            activeTasks: [first, second, third]
        )

        XCTAssertEqual(normalized.count, 3)
        XCTAssertEqual(normalized[0].0, third.id)
        XCTAssertEqual(normalized[1].0, first.id)
        XCTAssertEqual(normalized[2].0, second.id)
        XCTAssertEqual(normalized.map(\.1), [0, 1, 2])
    }

    func testSortedCompletedTasksUsesLatestCompletionFirst() {
        let now = Date()
        let older = TaskItem(
            id: UUID(),
            title: "Older",
            createdAt: now,
            updatedAt: now,
            completedAt: now.addingTimeInterval(5),
            manualOrder: nil
        )
        let newer = TaskItem(
            id: UUID(),
            title: "Newer",
            createdAt: now,
            updatedAt: now,
            completedAt: now.addingTimeInterval(10),
            manualOrder: nil
        )

        let sorted = CaptureAlgorithms.sortedCompletedTasks([older, newer])
        XCTAssertEqual(sorted.first?.id, newer.id)
    }
}

