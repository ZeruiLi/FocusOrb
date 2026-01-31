import Foundation
import GRDB

/// Manages the SQLite database connection and schema for FocusOrb.
class DatabaseManager {
    static let shared = DatabaseManager()
    
    private var dbQueue: DatabaseQueue!
    
    private init() {
        do {
            dbQueue = try setupDatabase()
        } catch {
            fatalError("Failed to initialize database: \(error)")
        }
    }
    
    // MARK: - Setup
    
    private func setupDatabase() throws -> DatabaseQueue {
        // Find App Support Directory
        let fileManager = FileManager.default
        let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupportURL.appendingPathComponent("FocusOrb", isDirectory: true)
        
        // Ensure directory exists
        try fileManager.createDirectory(at: appDir, withIntermediateDirectories: true)
        
        let dbPath = appDir.appendingPathComponent("focusorb.sqlite").path
        let dbQueue = try DatabaseQueue(path: dbPath)
        
        // Run migrations
        try migrator.migrate(dbQueue)
        
        return dbQueue
    }
    
    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        
        migrator.registerMigration("v1_createEvents") { db in
            try db.create(table: "orbEvent", ifNotExists: true) { t in
                t.column("id", .text).primaryKey()
                t.column("timestamp", .datetime).notNull().indexed()
                t.column("type", .text).notNull()
                t.column("sessionId", .text).notNull().indexed()
                t.column("meta", .text) // JSON encoded
            }
        }
        
        // Fix 4: Add parentSessionId for merge tracking
        migrator.registerMigration("v2_addParentSessionId") { db in
            try db.alter(table: "orbEvent") { t in
                t.add(column: "parentSessionId", .text)
            }
        }
        
        return migrator
    }
    
    // MARK: - CRUD Operations
    
    /// Insert a new event into the database.
    func insert(_ event: OrbEvent) throws {
        try dbQueue.write { db in
            try event.insert(db)
        }
    }
    
    /// Fetch all events, ordered by timestamp ascending.
    func fetchAllEvents() throws -> [OrbEvent] {
        try dbQueue.read { db in
            try OrbEvent.order(Column("timestamp").asc).fetchAll(db)
        }
    }
    
    /// Fetch events for a specific session.
    func fetchEvents(for sessionId: UUID) throws -> [OrbEvent] {
        try dbQueue.read { db in
            try OrbEvent
                .filter(Column("sessionId") == sessionId.uuidString)
                .order(Column("timestamp").asc)
                .fetchAll(db)
        }
    }
    
    /// Fetch the last event (most recent by timestamp).
    func fetchLastEvent() throws -> OrbEvent? {
        try dbQueue.read { db in
            try OrbEvent.order(Column("timestamp").desc).fetchOne(db)
        }
    }
    
    /// Fetch the last sessionEnd event to check for auto-merge.
    func fetchLastSessionEndEvent() throws -> OrbEvent? {
        try dbQueue.read { db in
            try OrbEvent
                .filter(Column("type") == EventType.sessionEnd.rawValue)
                .order(Column("timestamp").desc)
                .fetchOne(db)
        }
    }
    
    /// Fetch all unique session IDs.
    func fetchAllSessionIds() throws -> [UUID] {
        try dbQueue.read { db in
            let rows = try Row.fetchAll(db, sql: "SELECT DISTINCT sessionId FROM orbEvent ORDER BY MIN(timestamp)")
            return rows.compactMap { UUID(uuidString: $0["sessionId"]) }
        }
    }
}
