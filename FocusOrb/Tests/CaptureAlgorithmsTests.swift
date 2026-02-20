import XCTest
@testable import FocusOrb

final class CaptureAlgorithmsTests: XCTestCase {
    func testTopTaskDefaultsToOldestCreatedTask() {
        let now = Date()
        let tasks = [
            TaskItem(id: UUID(), title: "Second", createdAt: now.addingTimeInterval(10), updatedAt: now.addingTimeInterval(10)),
            TaskItem(id: UUID(), title: "First", createdAt: now, updatedAt: now)
        ]

        let top = CaptureAlgorithms.topTask(from: tasks)
        XCTAssertEqual(top?.title, "First")
    }

    func testManualOrderOverridesCreationTime() {
        let now = Date()
        let first = TaskItem(id: UUID(), title: "Oldest", createdAt: now, updatedAt: now, completedAt: nil, manualOrder: 1)
        let second = TaskItem(id: UUID(), title: "Newer", createdAt: now.addingTimeInterval(60), updatedAt: now.addingTimeInterval(60), completedAt: nil, manualOrder: 0)

        let sorted = CaptureAlgorithms.sortedActiveTasks([first, second])
        XCTAssertEqual(sorted.first?.id, second.id)
        XCTAssertEqual(CaptureAlgorithms.topTask(from: [first, second])?.id, second.id)
    }

    func testCompletedTaskIsExcludedFromTopTask() {
        let now = Date()
        let completed = TaskItem(
            id: UUID(),
            title: "Done",
            createdAt: now,
            updatedAt: now,
            completedAt: now.addingTimeInterval(1),
            manualOrder: nil
        )
        let active = TaskItem(
            id: UUID(),
            title: "Active",
            createdAt: now.addingTimeInterval(2),
            updatedAt: now.addingTimeInterval(2),
            completedAt: nil,
            manualOrder: nil
        )

        XCTAssertEqual(CaptureAlgorithms.topTask(from: [completed, active])?.id, active.id)
    }

    func testResetOrderFallsBackToCreationTime() {
        let now = Date()
        let first = TaskItem(id: UUID(), title: "First", createdAt: now, updatedAt: now, completedAt: nil, manualOrder: nil)
        let second = TaskItem(id: UUID(), title: "Second", createdAt: now.addingTimeInterval(20), updatedAt: now.addingTimeInterval(20), completedAt: nil, manualOrder: nil)

        let sorted = CaptureAlgorithms.sortedActiveTasks([second, first])
        XCTAssertEqual(sorted.first?.id, first.id)
    }

    func testShouldIgnoreClipForEmptyOrConsecutiveDuplicate() {
        XCTAssertTrue(CaptureAlgorithms.shouldIgnoreClip(content: "   ", latestContent: nil))
        XCTAssertTrue(CaptureAlgorithms.shouldIgnoreClip(content: "hello", latestContent: "hello"))
        XCTAssertFalse(CaptureAlgorithms.shouldIgnoreClip(content: "world", latestContent: "hello"))
    }

    func testClipRetentionPrefersRemovingOldestUnpinned() {
        let now = Date()
        let clips = [
            ClipItem(id: UUID(), content: "A", createdAt: now, isPinned: false),
            ClipItem(id: UUID(), content: "B", createdAt: now.addingTimeInterval(1), isPinned: true),
            ClipItem(id: UUID(), content: "C", createdAt: now.addingTimeInterval(2), isPinned: false)
        ]

        let deleteIDs = CaptureAlgorithms.clipIDsToDeleteForRetention(clipsByOldestFirst: clips, maxCount: 2)
        XCTAssertEqual(deleteIDs, [clips[0].id])
    }

    func testPinnedClipsAreNotDeletedEvenIfOverLimit() {
        let now = Date()
        let clips = [
            ClipItem(id: UUID(), content: "A", createdAt: now, isPinned: true),
            ClipItem(id: UUID(), content: "B", createdAt: now.addingTimeInterval(1), isPinned: true),
            ClipItem(id: UUID(), content: "C", createdAt: now.addingTimeInterval(2), isPinned: true)
        ]

        let deleteIDs = CaptureAlgorithms.clipIDsToDeleteForRetention(clipsByOldestFirst: clips, maxCount: 2)
        XCTAssertTrue(deleteIDs.isEmpty)
    }
}

