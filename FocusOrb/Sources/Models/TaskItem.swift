import Foundation
import GRDB

struct TaskItem: Identifiable, Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "taskItem"

    var id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date
    var completedAt: Date?
    var manualOrder: Int?

    init(
        id: UUID = UUID(),
        title: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        completedAt: Date? = nil,
        manualOrder: Int? = nil
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.completedAt = completedAt
        self.manualOrder = manualOrder
    }

    enum Columns: String, ColumnExpression {
        case id, title, createdAt, updatedAt, completedAt, manualOrder
    }

    var isCompleted: Bool {
        completedAt != nil
    }

    init(row: Row) {
        let idString: String? = row[Columns.id]
        id = idString.flatMap(UUID.init(uuidString:)) ?? UUID()
        title = row[Columns.title]
        createdAt = row[Columns.createdAt]
        updatedAt = row[Columns.updatedAt]
        completedAt = row[Columns.completedAt]
        manualOrder = row[Columns.manualOrder]
    }

    func encode(to container: inout PersistenceContainer) {
        container[Columns.id] = id.uuidString
        container[Columns.title] = title
        container[Columns.createdAt] = createdAt
        container[Columns.updatedAt] = updatedAt
        container[Columns.completedAt] = completedAt
        container[Columns.manualOrder] = manualOrder
    }
}

