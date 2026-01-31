import Foundation
import GRDB

enum EventType: String, Codable {
    case sessionStart
    case enterRedPending
    case cancelRedPending
    case confirmRedStart
    case switchToGreen
    case sessionEnd
}

struct OrbEvent: Identifiable, Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "orbEvent"

    let id: UUID
    let timestamp: Date
    let type: EventType
    let sessionId: UUID
    let parentSessionId: UUID?
    let meta: [String: String]?

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        type: EventType,
        sessionId: UUID,
        parentSessionId: UUID? = nil,
        meta: [String: String]? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.type = type
        self.sessionId = sessionId
        self.parentSessionId = parentSessionId
        self.meta = meta
    }

    enum Columns: String, ColumnExpression {
        case id, timestamp, type, sessionId, parentSessionId, meta
    }

    init(row: Row) {
        let columnNames = Set(row.columnNames.map { $0.lowercased() })

        let idString: String? = row[Columns.id]
        id = idString.flatMap(UUID.init(uuidString:)) ?? UUID()

        timestamp = row[Columns.timestamp]

        let typeString: String? = row[Columns.type]
        type = typeString.flatMap(EventType.init(rawValue:)) ?? .sessionStart

        let sessionIdString: String? = row[Columns.sessionId]
        sessionId = sessionIdString.flatMap(UUID.init(uuidString:)) ?? UUID()

        if columnNames.contains(Columns.parentSessionId.rawValue.lowercased()),
           let parentIdString: String = row[Columns.parentSessionId] {
            parentSessionId = UUID(uuidString: parentIdString)
        } else {
            parentSessionId = nil
        }

        if columnNames.contains(Columns.meta.rawValue.lowercased()),
           let metaString: String = row[Columns.meta] {
            meta = (try? JSONDecoder().decode([String: String].self, from: Data(metaString.utf8))) ?? nil
        } else {
            meta = nil
        }
    }

    func encode(to container: inout PersistenceContainer) throws {
        container[Columns.id] = id.uuidString
        container[Columns.timestamp] = timestamp
        container[Columns.type] = type.rawValue
        container[Columns.sessionId] = sessionId.uuidString
        container[Columns.parentSessionId] = parentSessionId?.uuidString

        if let meta = meta {
            container[Columns.meta] = String(data: try JSONEncoder().encode(meta), encoding: .utf8)
        }
    }
}

struct OrbSegment: Identifiable {
    let id: UUID
    let sessionId: UUID
    let startTime: Date
    var endTime: Date?
    let type: SegmentType

    var duration: TimeInterval {
        (endTime ?? Date()).timeIntervalSince(startTime)
    }
}

enum SegmentType {
    case green
    case red
}
