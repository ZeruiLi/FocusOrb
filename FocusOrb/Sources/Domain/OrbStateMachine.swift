import Foundation
import Combine

enum OrbState: Equatable {
    case idle
    case green(startTime: Date)
    case redPending(startTime: Date, remaining: TimeInterval)
    case red(startTime: Date)
}

class OrbStateMachine: ObservableObject {
    @Published var currentState: OrbState = .idle
    @Published var currentSessionDuration: TimeInterval = 0
    @Published var lastEndedSessionDuration: TimeInterval = 0
    @Published var idleFillProgress: Double = 0

    internal let eventStore: EventStore
    private var currentSessionId: UUID?
    private let idleTimeProvider: IdleTimeProviding
    private let snapshotStore: RuntimeSessionSnapshotStore
    private let autoCloseThresholdSeconds: TimeInterval = 30 * 60

    private var timer: Timer?
    private var durationTimer: Timer?
    private var idleMonitorTimer: Timer?
    private var greenStartTimeBeforePending: Date?

    var activeSessionId: UUID? {
        currentSessionId
    }

    init(
        eventStore: EventStore,
        idleTimeProvider: IdleTimeProviding = SystemIdleTimeProvider(),
        snapshotStore: RuntimeSessionSnapshotStore = .shared
    ) {
        self.eventStore = eventStore
        self.idleTimeProvider = idleTimeProvider
        self.snapshotStore = snapshotStore
        restoreState()
        startIdleMonitorTimer()
    }

    deinit {
        timer?.invalidate()
        durationTimer?.invalidate()
        idleMonitorTimer?.invalidate()
    }

    func startSession() {
        guard currentSessionId == nil else { return }

        let settings = AppSettings.shared
        let sessionId = UUID()
        var parentId: UUID? = nil

        if settings.autoMergeWindowMinutes > 0,
           let lastEnd = eventStore.lastSessionEndEvent() {
            let mergeWindowSeconds = TimeInterval(settings.autoMergeWindowMinutes * 60)
            let timeSinceLastSession = Date().timeIntervalSince(lastEnd.timestamp)
            if timeSinceLastSession <= mergeWindowSeconds {
                parentId = lastEnd.sessionId
            }
        }

        currentSessionId = sessionId
        eventStore.append(OrbEvent(type: .sessionStart, sessionId: sessionId, parentSessionId: parentId))

        currentState = .green(startTime: Date())
        startDurationTimer()
        idleFillProgress = 0
        snapshotStore.recordTick(sessionId: sessionId)
    }

    func endSession() {
        guard let sessionId = currentSessionId else { return }

        eventStore.append(OrbEvent(type: .sessionEnd, sessionId: sessionId))

        let events = eventStore.events(for: sessionId)
        let stats = StatsCalculator.sessionStats(events: events)
        lastEndedSessionDuration = stats.total

        currentState = .idle
        currentSessionId = nil
        timer?.invalidate()
        durationTimer?.invalidate()
        currentSessionDuration = 0
        greenStartTimeBeforePending = nil
        idleFillProgress = 0
        snapshotStore.clear()
    }

    func handleClick() {
        guard let sessionId = currentSessionId else {
            startSession()
            return
        }

        switch currentState {
        case .green(let greenStart):
            enterRedPending(sessionId: sessionId, fromGreenStart: greenStart, source: nil)

        case .redPending:
            eventStore.append(OrbEvent(type: .cancelRedPending, sessionId: sessionId))
            cancelRedPendingTimer()
            let restoredStart = greenStartTimeBeforePending ?? Date()
            currentState = .green(startTime: restoredStart)
            greenStartTimeBeforePending = nil
            idleFillProgress = 0

        case .red:
            eventStore.append(OrbEvent(type: .switchToGreen, sessionId: sessionId))
            currentState = .green(startTime: Date())
            idleFillProgress = 0

        case .idle:
            startSession()
        }
    }

    private func enterRedPending(sessionId: UUID, fromGreenStart: Date, source: String?) {
        greenStartTimeBeforePending = fromGreenStart
        idleFillProgress = 0
        if let source {
            eventStore.append(OrbEvent(type: .enterRedPending, sessionId: sessionId, meta: ["source": source]))
        } else {
            eventStore.append(OrbEvent(type: .enterRedPending, sessionId: sessionId))
        }
        startRedPendingTimer(duration: AppSettings.redPendingDuration)
    }

    private func startDurationTimer() {
        durationTimer?.invalidate()
        durationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateDuration()
        }
        updateDuration()
    }

    private func updateDuration() {
        let now = Date()
        switch currentState {
        case .green(let start):
            currentSessionDuration = now.timeIntervalSince(start)
        case .red(let start):
            currentSessionDuration = now.timeIntervalSince(start)
        default:
            break
        }

        if let sessionId = currentSessionId {
            snapshotStore.recordTick(sessionId: sessionId, tickAt: now)
        }
    }

    private func startRedPendingTimer(duration: TimeInterval) {
        let startTime = Date()
        currentState = .redPending(startTime: startTime, remaining: duration)

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let elapsed = Date().timeIntervalSince(startTime)
            let remaining = max(duration - elapsed, 0)

            if remaining == 0 {
                self.confirmRed()
            } else {
                self.currentState = .redPending(startTime: startTime, remaining: remaining)
            }

            if let sessionId = self.currentSessionId {
                self.snapshotStore.recordTick(sessionId: sessionId)
            }
        }
    }

    private func continueRedPendingTimer(remaining: TimeInterval) {
        // Restart countdown from "remaining" to avoid counting offline time.
        startRedPendingTimer(duration: remaining)
    }

    private func cancelRedPendingTimer() {
        timer?.invalidate()
    }

    private func confirmRed() {
        timer?.invalidate()
        guard let sessionId = currentSessionId else { return }

        eventStore.append(OrbEvent(type: .confirmRedStart, sessionId: sessionId))
        currentState = .red(startTime: Date())
        idleFillProgress = 0
    }

    private func lastGreenStartBeforePending(sessionId: UUID, pendingAt: Date) -> Date? {
        let events = eventStore.events(for: sessionId).filter { $0.timestamp < pendingAt }
        for e in events.reversed() {
            switch e.type {
            case .sessionStart, .switchToGreen, .cancelRedPending:
                return e.timestamp
            default:
                continue
            }
        }
        return nil
    }

    private func restoreState() {
        let lastNonReflection = eventStore.events.last { $0.type != .sessionReflection }
        guard let last = lastNonReflection else {
            currentState = .idle
            currentSessionId = nil
            snapshotStore.clear()
            return
        }

        idleFillProgress = 0

        guard last.type != .sessionEnd else {
            currentState = .idle
            currentSessionId = nil
            snapshotStore.clear()
            return
        }

        let now = Date()
        let sessionId = last.sessionId

        let snap = snapshotStore.load()
        let lastTickAt = (snap?.sessionId == sessionId) ? snap?.lastTickAt : nil
        // If no snapshot exists (e.g. first launch after upgrading), treat the "in-app end"
        // as the last persisted event time to avoid counting offline time.
        let effectiveLastTickAt = lastTickAt ?? last.timestamp

        if now.timeIntervalSince(effectiveLastTickAt) > autoCloseThresholdSeconds {
            eventStore.append(
                OrbEvent(
                    timestamp: effectiveLastTickAt,
                    type: .sessionEnd,
                    sessionId: sessionId,
                    meta: ["reason": "stale_autoclose"]
                )
            )
            currentState = .idle
            currentSessionId = nil
            timer?.invalidate()
            durationTimer?.invalidate()
            currentSessionDuration = 0
            greenStartTimeBeforePending = nil
            idleFillProgress = 0
            snapshotStore.clear()
            return
        }

        currentSessionId = sessionId
        idleFillProgress = 0

        switch last.type {
        case .sessionStart, .switchToGreen, .cancelRedPending:
            let elapsed = max(effectiveLastTickAt.timeIntervalSince(last.timestamp), 0)
            currentState = .green(startTime: now.addingTimeInterval(-elapsed))
            startDurationTimer()

        case .confirmRedStart:
            let elapsed = max(effectiveLastTickAt.timeIntervalSince(last.timestamp), 0)
            currentState = .red(startTime: now.addingTimeInterval(-elapsed))
            startDurationTimer()

        case .enterRedPending:
            let duration = AppSettings.redPendingDuration
            let pendingElapsed = max(effectiveLastTickAt.timeIntervalSince(last.timestamp), 0)
            greenStartTimeBeforePending = lastGreenStartBeforePending(sessionId: sessionId, pendingAt: last.timestamp)

            if pendingElapsed >= duration {
                let confirmTime = last.timestamp.addingTimeInterval(duration)
                eventStore.append(
                    OrbEvent(
                        timestamp: confirmTime,
                        type: .confirmRedStart,
                        sessionId: last.sessionId,
                        meta: ["source": "restore"]
                    )
                )
                let redElapsed = max(effectiveLastTickAt.timeIntervalSince(confirmTime), 0)
                currentState = .red(startTime: now.addingTimeInterval(-redElapsed))
                startDurationTimer()
            } else {
                let remaining = duration - pendingElapsed
                continueRedPendingTimer(remaining: remaining)
            }

        default:
            currentState = .idle
        }
    }

    private func startIdleMonitorTimer() {
        idleMonitorTimer?.invalidate()
        idleMonitorTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            self?.updateIdleFillProgress()
        }
        updateIdleFillProgress()
    }

    private func updateIdleFillProgress() {
        guard let sessionId = currentSessionId else {
            idleFillProgress = 0
            return
        }

        guard case .green(let greenStart) = currentState else {
            idleFillProgress = 0
            return
        }

        let settings = AppSettings.shared
        let idleMinutes = settings.autoBreakIdleMinutes
        guard idleMinutes > 0 else {
            idleFillProgress = 0
            return
        }

        let t1 = TimeInterval(idleMinutes * 60)
        let tFill = max(TimeInterval(settings.autoBreakFillSeconds), 1)
        let idleSeconds = idleTimeProvider.idleSeconds()

        if idleSeconds < t1 {
            idleFillProgress = 0
            return
        }

        let fillElapsed = idleSeconds - t1
        let progress = min(max(fillElapsed / tFill, 0), 1)
        idleFillProgress = progress

        if progress >= 1 {
            enterRedPending(sessionId: sessionId, fromGreenStart: greenStart, source: "idle")
        }
    }
}
