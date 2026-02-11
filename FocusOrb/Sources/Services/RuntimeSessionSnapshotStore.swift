import Foundation

/// Stores a minimal "runtime heartbeat" for crash/kill recovery.
///
/// Goal: prevent counting offline time (app not running) into focus duration after restart.
final class RuntimeSessionSnapshotStore {
    static let shared = RuntimeSessionSnapshotStore()

    struct Snapshot: Equatable {
        let sessionId: UUID
        let lastTickAt: Date
    }

    private enum Keys {
        static let activeSessionId = "focusorb.runtime.activeSessionId"
        static let lastTickAt = "focusorb.runtime.lastTickAt"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> Snapshot? {
        guard let rawId = defaults.string(forKey: Keys.activeSessionId),
              let sessionId = UUID(uuidString: rawId),
              let lastTickAt = defaults.object(forKey: Keys.lastTickAt) as? Date else {
            return nil
        }
        return Snapshot(sessionId: sessionId, lastTickAt: lastTickAt)
    }

    func recordTick(sessionId: UUID, tickAt: Date = Date()) {
        defaults.set(sessionId.uuidString, forKey: Keys.activeSessionId)
        defaults.set(tickAt, forKey: Keys.lastTickAt)
    }

    func clear() {
        defaults.removeObject(forKey: Keys.activeSessionId)
        defaults.removeObject(forKey: Keys.lastTickAt)
    }
}

