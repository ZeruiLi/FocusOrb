import Foundation
import GRDB

enum NoteSource: String, Codable, CaseIterable {
    case manual
    case reflection
}

enum NoteTemplate: String, Codable, CaseIterable, Identifiable {
    case clean
    case warm
    case mint
    case dusk

    var id: String { rawValue }

    var title: String {
        switch self {
        case .clean:
            return L10n.string("Clean")
        case .warm:
            return L10n.string("Warm")
        case .mint:
            return L10n.string("Mint")
        case .dusk:
            return L10n.string("Dusk")
        }
    }
}

struct NoteItem: Identifiable, Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "noteItem"

    var id: UUID
    var title: String
    var content: String
    var createdAt: Date
    var updatedAt: Date
    var source: NoteSource
    var sessionId: UUID?
    var template: NoteTemplate
    var imagePaths: [String]

    init(
        id: UUID = UUID(),
        title: String = "",
        content: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        source: NoteSource = .manual,
        sessionId: UUID? = nil,
        template: NoteTemplate = .clean,
        imagePaths: [String] = []
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.source = source
        self.sessionId = sessionId
        self.template = template
        self.imagePaths = Self.normalizedImagePaths(imagePaths)
    }

    enum Columns: String, ColumnExpression {
        case id, title, content, createdAt, updatedAt, source, sessionId, template, imagePaths
    }

    var resolvedTitle: String {
        let normalized = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !normalized.isEmpty {
            return normalized
        }
        return Self.defaultTitle(from: content)
    }

    var previewText: String {
        let normalized = content
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.isEmpty {
            return L10n.string("No content yet.")
        }
        return String(normalized.prefix(120))
    }

    var primaryImagePath: String? {
        imagePaths.first
    }

    init(row: Row) {
        let idString: String? = row[Columns.id]
        id = idString.flatMap(UUID.init(uuidString:)) ?? UUID()
        title = row[Columns.title]
        content = row[Columns.content]
        createdAt = row[Columns.createdAt]
        updatedAt = row[Columns.updatedAt]

        let sourceRaw: String? = row[Columns.source]
        source = sourceRaw.flatMap(NoteSource.init(rawValue:)) ?? .manual

        let sessionRaw: String? = row[Columns.sessionId]
        sessionId = sessionRaw.flatMap(UUID.init(uuidString:))

        let templateRaw: String? = row[Columns.template]
        template = templateRaw.flatMap(NoteTemplate.init(rawValue:)) ?? .clean

        let rawImagePaths: String? = row[Columns.imagePaths]
        imagePaths = Self.decodeImagePaths(rawImagePaths)
    }

    func encode(to container: inout PersistenceContainer) {
        container[Columns.id] = id.uuidString
        container[Columns.title] = title
        container[Columns.content] = content
        container[Columns.createdAt] = createdAt
        container[Columns.updatedAt] = updatedAt
        container[Columns.source] = source.rawValue
        container[Columns.sessionId] = sessionId?.uuidString
        container[Columns.template] = template.rawValue
        container[Columns.imagePaths] = Self.encodeImagePaths(imagePaths)
    }

    private static func defaultTitle(from content: String) -> String {
        let firstLine = content
            .split(whereSeparator: \.isNewline)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let firstLine, !firstLine.isEmpty {
            return String(firstLine.prefix(36))
        }
        return L10n.string("Untitled Note")
    }

    private static func normalizedImagePaths(_ imagePaths: [String]) -> [String] {
        var seen = Set<String>()
        return imagePaths.compactMap { path in
            let normalized = path.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.isEmpty, seen.insert(normalized).inserted else {
                return nil
            }
            return normalized
        }
    }

    private static func decodeImagePaths(_ raw: String?) -> [String] {
        guard
            let raw,
            let data = raw.data(using: .utf8),
            let decoded = try? JSONDecoder().decode([String].self, from: data)
        else {
            return []
        }
        return normalizedImagePaths(decoded)
    }

    private static func encodeImagePaths(_ imagePaths: [String]) -> String {
        let normalized = normalizedImagePaths(imagePaths)
        guard
            let data = try? JSONEncoder().encode(normalized),
            let raw = String(data: data, encoding: .utf8)
        else {
            return "[]"
        }
        return raw
    }
}
