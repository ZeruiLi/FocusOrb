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

    internal let eventStore: EventStore
    private var currentSessionId: UUID?

    private var timer: Timer?
    private var durationTimer: Timer?
    private var greenStartTimeBeforePending: Date?

    init(eventStore: EventStore) {
        self.eventStore = eventStore
        restoreState()
    }

    deinit {
        timer?.invalidate()
        durationTimer?.invalidate()
    }

    func startSession() {
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
    }

    func handleClick() {
        guard let sessionId = currentSessionId else {
            startSession()
            return
        }

        switch currentState {
        case .green(let greenStart):
            greenStartTimeBeforePending = greenStart
            eventStore.append(OrbEvent(type: .enterRedPending, sessionId: sessionId))
            startRedPendingTimer()

        case .redPending:
            eventStore.append(OrbEvent(type: .cancelRedPending, sessionId: sessionId))
            cancelRedPendingTimer()
            let restoredStart = greenStartTimeBeforePending ?? Date()
            currentState = .green(startTime: restoredStart)
            greenStartTimeBeforePending = nil

        case .red:
            eventStore.append(OrbEvent(type: .switchToGreen, sessionId: sessionId))
            currentState = .green(startTime: Date())

        case .idle:
            startSession()
        }
    }

    private func startDurationTimer() {
        durationTimer?.invalidate()
        durationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateDuration()
        }
        updateDuration()
    }

    private func updateDuration() {
        switch currentState {
        case .green(let start):
            currentSessionDuration = Date().timeIntervalSince(start)
        case .red(let start):
            currentSessionDuration = Date().timeIntervalSince(start)
        default:
            break
        }
    }

    private func startRedPendingTimer() {
        let duration = AppSettings.redPendingDuration
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
        }
    }

    private func continueRedPendingTimer(startTime: Date, remaining: TimeInterval) {
        let duration = AppSettings.redPendingDuration
        currentState = .redPending(startTime: startTime, remaining: remaining)

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let elapsed = Date().timeIntervalSince(startTime)
            let newRemaining = max(duration - elapsed, 0)

            if newRemaining == 0 {
                self.confirmRed()
            } else {
                self.currentState = .redPending(startTime: startTime, remaining: newRemaining)
            }
        }
    }

    private func cancelRedPendingTimer() {
        timer?.invalidate()
    }

    private func confirmRed() {
        timer?.invalidate()
        guard let sessionId = currentSessionId else { return }

        eventStore.append(OrbEvent(type: .confirmRedStart, sessionId: sessionId))
        currentState = .red(startTime: Date())
    }

    private func restoreState() {
        let lastNonReflection = eventStore.events.last { $0.type != .sessionReflection }
        guard let last = lastNonReflection, last.type != .sessionEnd else {
            currentState = .idle
            currentSessionId = nil
            return
        }

        currentSessionId = last.sessionId

        switch last.type {
        case .sessionStart, .switchToGreen, .cancelRedPending:
            currentState = .green(startTime: last.timestamp)
            startDurationTimer()

        case .confirmRedStart:
            currentState = .red(startTime: last.timestamp)
            startDurationTimer()

        case .enterRedPending:
            let elapsed = Date().timeIntervalSince(last.timestamp)
            let duration = AppSettings.redPendingDuration

            if elapsed >= duration {
                let confirmTime = last.timestamp.addingTimeInterval(duration)
                eventStore.append(OrbEvent(timestamp: confirmTime, type: .confirmRedStart, sessionId: last.sessionId))
                currentState = .red(startTime: confirmTime)
                startDurationTimer()
            } else {
                let remaining = duration - elapsed
                continueRedPendingTimer(startTime: last.timestamp, remaining: remaining)
            }

        default:
            currentState = .idle
        }
    }
}
