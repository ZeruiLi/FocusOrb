import Foundation
import GRDB

enum ClipKind: String, Codable, CaseIterable {
    case text
    case image
}

struct ClipItem: Identifiable, Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "clipItem"

    var id: UUID
    var content: String
    var kind: ClipKind
    var imagePath: String?
    var createdAt: Date
    var isPinned: Bool
    var lastCopiedAt: Date?

    init(
        id: UUID = UUID(),
        content: String,
        kind: ClipKind = .text,
        imagePath: String? = nil,
        createdAt: Date = Date(),
        isPinned: Bool = false,
        lastCopiedAt: Date? = nil
    ) {
        self.id = id
        self.content = content
        self.kind = kind
        self.imagePath = Self.normalizedImagePath(imagePath)
        self.createdAt = createdAt
        self.isPinned = isPinned
        self.lastCopiedAt = lastCopiedAt
    }

    enum Columns: String, ColumnExpression {
        case id, content, kind, imagePath, createdAt, isPinned, lastCopiedAt
    }

    var isImage: Bool {
        kind == .image
    }

    init(row: Row) {
        let idString: String? = row[Columns.id]
        id = idString.flatMap(UUID.init(uuidString:)) ?? UUID()
        content = row[Columns.content]
        let kindRaw: String? = row[Columns.kind]
        kind = kindRaw.flatMap(ClipKind.init(rawValue:)) ?? .text
        let rawImagePath: String? = row[Columns.imagePath]
        imagePath = Self.normalizedImagePath(rawImagePath)
        createdAt = row[Columns.createdAt]
        isPinned = row[Columns.isPinned]
        lastCopiedAt = row[Columns.lastCopiedAt]
    }

    func encode(to container: inout PersistenceContainer) {
        container[Columns.id] = id.uuidString
        container[Columns.content] = content
        container[Columns.kind] = kind.rawValue
        container[Columns.imagePath] = Self.normalizedImagePath(imagePath)
        container[Columns.createdAt] = createdAt
        container[Columns.isPinned] = isPinned
        container[Columns.lastCopiedAt] = lastCopiedAt
    }

    private static func normalizedImagePath(_ raw: String?) -> String? {
        let normalized = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }
}
