import Foundation
import Combine

/// EventStore manages the event stream, now backed by SQLite via DatabaseManager.
class EventStore: ObservableObject {
    static let shared = EventStore()
    
    @Published private(set) var events: [OrbEvent] = []
    
    private init() {
        reload()
    }
    
    // MARK: - Public API
    
    /// Append a new event and persist to SQLite.
    func append(_ event: OrbEvent) {
        do {
            try DatabaseManager.shared.insert(event)
            events.append(event)
        } catch {
            print("Failed to insert event: \(error)")
        }
    }
    
    /// Reload all events from database.
    func reload() {
        do {
            events = try DatabaseManager.shared.fetchAllEvents()
        } catch {
            print("Failed to fetch events: \(error)")
            events = []
        }
    }
    
    /// Get the last event for state restoration.
    var lastEvent: OrbEvent? {
        return events.last
    }
    
    /// Fetch the last sessionEnd event (for auto-merge logic).
    func lastSessionEndEvent() -> OrbEvent? {
        do {
            return try DatabaseManager.shared.fetchLastSessionEndEvent()
        } catch {
            print("Failed to fetch last session end: \(error)")
            return nil
        }
    }
    
    /// Fetch events for a specific session.
    func events(for sessionId: UUID) -> [OrbEvent] {
        do {
            return try DatabaseManager.shared.fetchEvents(for: sessionId)
        } catch {
            print("Failed to fetch session events: \(error)")
            return []
        }
    }
}

