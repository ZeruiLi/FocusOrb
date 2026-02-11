import SwiftUI
import AppKit
import Combine
import UserNotifications

final class OrbInteractionState: ObservableObject {
    @Published var isPressed = false
}

// Custom NSHostingView subclass to intercept right-clicks
class RightClickHostingView<Content: View>: NSHostingView<Content> {
    var onRightClick: ((NSPoint) -> Void)?
    
    override func rightMouseDown(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        onRightClick?(location)
        // Don't call super - we handle it ourselves
    }
}

// Custom NSPanel that resolves each input sequence into exactly one action:
// tap, long-press, or drag.
class DraggablePanel: NSPanel {
    enum InputPhase {
        case idle
        case pressed
        case dragging
        case longPressed
    }

    var onTap: (() -> Void)?
    var onLongPress: (() -> Void)?
    var onDragBegan: (() -> Void)?
    var onDragEnded: (() -> Void)?
    var onPressStateChanged: ((Bool) -> Void)?

    private var phase: InputPhase = .idle
    private var mouseDownPoint: NSPoint?
    private let dragThreshold: CGFloat = 10.0
    private let longPressDuration: TimeInterval = 0.8
    private var longPressTimer: Timer?

    deinit {
        longPressTimer?.invalidate()
    }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown {
            beginPress(at: event.locationInWindow)
        } else if event.type == .leftMouseDragged {
            guard let down = mouseDownPoint else { return }
            let dx = abs(event.locationInWindow.x - down.x)
            let dy = abs(event.locationInWindow.y - down.y)
            let passedThreshold = dx > dragThreshold || dy > dragThreshold

            if phase == .pressed && passedThreshold {
                phase = .dragging
                longPressTimer?.invalidate()
                onPressStateChanged?(false)
                onDragBegan?()
            }

            if phase == .dragging {
                self.setFrameOrigin(NSPoint(x: self.frame.origin.x + event.deltaX, y: self.frame.origin.y - event.deltaY))
            }
        } else if event.type == .leftMouseUp {
            longPressTimer?.invalidate()

            switch phase {
            case .pressed:
                onPressStateChanged?(false)
                onTap?()
            case .dragging:
                onPressStateChanged?(false)
                onDragEnded?()
            case .longPressed:
                onPressStateChanged?(false)
            case .idle:
                break
            }

            resetInput()
        } else {
            super.sendEvent(event)
        }
    }

    private func beginPress(at point: NSPoint) {
        resetInput()
        mouseDownPoint = point
        phase = .pressed
        onPressStateChanged?(true)

        longPressTimer = Timer.scheduledTimer(withTimeInterval: longPressDuration, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            guard self.phase == .pressed else { return }
            self.phase = .longPressed
            self.onPressStateChanged?(false)
            self.onLongPress?()
        }
    }

    private func resetInput() {
        longPressTimer?.invalidate()
        longPressTimer = nil
        mouseDownPoint = nil
        phase = .idle
    }
}

class OrbWindowManager: NSObject, ObservableObject, NSWindowDelegate {
    var panel: NSPanel!
    var summaryPanel: NSPanel?
    var startPanel: NSWindow?
    var dashboardWindow: NSWindow?  // Managed dashboard window
    var settingsWindow: NSWindow?
    
    private let stateMachine: OrbStateMachine
    private let interactionState = OrbInteractionState()
    private let orbPanelSize = CGSize(width: 200.0 * (2.0 / 3.0), height: 170.0 * (2.0 / 3.0))
    private var cancellables = Set<AnyCancellable>()
    private var isPresentingPreEndSummary = false
    private var skipPostEndSummaryOnce = false
    
    init(stateMachine: OrbStateMachine) {
        self.stateMachine = stateMachine
        super.init()
        setupPanel()
        setupObservers()
    }
    
    private func requestNotificationPermission() {
        // Prevent crash when running via 'swift run' (no bundle ID)
        guard Bundle.main.bundleIdentifier != nil else {
            print("⚠️ Running without Bundle ID. Using legacy notifications fallback.")
            return
        }
        
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if granted {
                print("✅ Notification permission granted")
            } else if let error = error {
                print("❌ Notification permission denied: \(error.localizedDescription)")
            }
        }
    }
    
    func setupPanel() {
        // Borderless panel with deterministic input arbitration.
        let dragPanel = DraggablePanel(
            contentRect: NSRect(x: 100, y: 100, width: orbPanelSize.width, height: orbPanelSize.height),
            styleMask: [.borderless, .nonactivatingPanel], 
            backing: .buffered,
            defer: false
        )
        self.panel = dragPanel

        dragPanel.onTap = { [weak self] in
            self?.stateMachine.handleClick()
        }
        dragPanel.onLongPress = { [weak self] in
            self?.requestSessionEndFromOrb()
        }
        dragPanel.onPressStateChanged = { [weak self] isPressed in
            self?.interactionState.isPressed = isPressed
        }
        dragPanel.onDragBegan = { [weak self] in
            self?.interactionState.isPressed = false
        }
        
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        // Critical for transparency
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false 
        
        // Disable standard moving to use our custom draggable logic
        panel.isMovableByWindowBackground = false
        
        let contentView = OrbView(
            stateMachine: stateMachine,
            interactionState: interactionState
        )
            .edgesIgnoringSafeArea(.all)
        
        let hostingView = RightClickHostingView(rootView: contentView)
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        hostingView.onRightClick = { [weak self] location in
            self?.showContextMenu(at: location, in: hostingView)
        }
        panel.contentView = hostingView
        
        // Build the context menu
        buildContextMenu()
    }
    
    private func buildContextMenu() {
        let menu = NSMenu()
        
        let endSessionItem = NSMenuItem(title: "End Session", action: #selector(menuEndSession), keyEquivalent: "")
        endSessionItem.target = self
        menu.addItem(endSessionItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let dashboardItem = NSMenuItem(title: "Dashboard", action: #selector(menuShowDashboard), keyEquivalent: "d")
        dashboardItem.target = self
        menu.addItem(dashboardItem)
        
        let hideItem = NSMenuItem(title: "Hide Orb", action: #selector(menuHideOrb), keyEquivalent: "h")
        hideItem.target = self
        menu.addItem(hideItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "Quit", action: #selector(menuQuit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        self.contextMenu = menu
    }
    
    private var contextMenu: NSMenu?
    
    private func showContextMenu(at location: NSPoint, in view: NSView) {
        guard let menu = contextMenu else { return }
        menu.popUp(positioning: nil, at: location, in: view)
    }
    
    // MARK: - Menu Actions
    
    @objc private func menuEndSession() {
        requestSessionEndFromExternal()
    }
    
    @objc private func menuShowDashboard() {
        showDashboard()
    }
    
    @objc private func menuHideOrb() {
        hideOrb()
    }
    
    @objc private func menuQuit() {
        NSApp.terminate(nil)
    }

    func requestSessionEndFromOrb() {
        requestSessionEnd(showOrbAfterCancel: true)
    }

    func requestSessionEndFromExternal() {
        requestSessionEnd(showOrbAfterCancel: isOrbVisible)
    }

    private func requestSessionEnd(showOrbAfterCancel: Bool) {
        guard let sessionId = stateMachine.activeSessionId else { return }
        let sessionEvents = EventStore.shared.events(for: sessionId)
        guard !sessionEvents.isEmpty else {
            stateMachine.endSession()
            return
        }

        let previewEnd = Date()
        let stats = StatsCalculator.sessionPreviewStats(events: sessionEvents, previewEndTime: previewEnd)

        // Keep the <60s threshold behavior: short sessions end immediately.
        guard stats.total >= 60 else {
            stateMachine.endSession()
            return
        }

        isPresentingPreEndSummary = true
        let startTime = sessionEvents.first(where: { $0.type == .sessionStart })?.timestamp ?? previewEnd
        presentSummary(
            stats: stats,
            startTime: startTime,
            endTime: previewEnd,
            mergedCount: mergedSessionCount(for: sessionId),
            showReflection: false,
            onSetMood: { _ in },
            onClose: {},
            onConfirmEnd: { [weak self] in
                self?.confirmEndSessionFromPreSummary()
            },
            onContinueSession: { [weak self] in
                self?.cancelPreEndSummary(showOrbAfterCancel: showOrbAfterCancel)
            }
        )
    }
    
    func setupObservers() {
        // Watch for State transitions to .idle (Session Ended)
        stateMachine.$currentState
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] state in
                if case .idle = state {
                    guard let self = self else { return }
                    if self.skipPostEndSummaryOnce {
                        self.skipPostEndSummaryOnce = false
                        self.showStart()
                        return
                    }
                    if self.isPresentingPreEndSummary {
                        return
                    }
                    // Only show summary if session was >= 60 seconds
                    if self.stateMachine.lastEndedSessionDuration >= 60 {
                        self.showSummary()
                    } else {
                        // Very short session, skip summary and go to start
                        self.showStart()
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Flow Control
    
    func launchApp() {
        if case .idle = stateMachine.currentState {
            // 强制首次引导
            if !AppSettings.shared.hasSeenOnboarding {
                showStart()
                return
            }
            
            // 检查 showOrbOnLaunch 设置
            if AppSettings.shared.showOrbOnLaunch {
                stateMachine.startSession()
                showOrb()
            } else {
                showStart()
            }
        } else {
            // Session 恢复场景
            showOrb()
            showResumeToast()
        }
    }
    
    private func showResumeToast() {
        // Custom in-app toast (no system permissions required)
        let toastWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 60),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        toastWindow.backgroundColor = .clear
        toastWindow.isOpaque = false
        toastWindow.level = .statusBar
        toastWindow.ignoresMouseEvents = true
        
        let toastView = NSView(frame: toastWindow.contentRect(forFrameRect: toastWindow.frame))
        toastView.wantsLayer = true
        toastView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.85).cgColor
        toastView.layer?.cornerRadius = 12
        
        let label = NSTextField(labelWithString: "✅ 已恢复上次会话\n您的专注会话已从上次中断处继续")
        label.alignment = .center
        label.textColor = .white
        label.font = NSFont.systemFont(ofSize: 13)
        label.frame = NSRect(x: 20, y: 10, width: 260, height: 40)
        toastView.addSubview(label)
        
        toastWindow.contentView = toastView
        
        // Position at top-center of screen
        if let screen = NSScreen.main {
            let screenRect = screen.visibleFrame
            let x = screenRect.midX - 150
            let y = screenRect.maxY - 100
            toastWindow.setFrameOrigin(NSPoint(x: x, y: y))
        }
        
        toastWindow.orderFront(nil)
        toastWindow.alphaValue = 0
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            toastWindow.animator().alphaValue = 1.0
        })
        
        // Auto-dismiss after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.3
                toastWindow.animator().alphaValue = 0
            }, completionHandler: {
                toastWindow.close()
            })
        }
    }
    
    private func showStart() {
        if startPanel == nil {
            let startView = StartView { [weak self] in
                self?.startFlow()
            }
            
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 300, height: 250),
                styleMask: [.titled, .closable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.center()
            window.contentView = NSHostingView(rootView: startView)
            window.isReleasedWhenClosed = false
            startPanel = window
        }
        
        startPanel?.makeKeyAndOrderFront(nil)
    }
    
    private func startFlow() {
        startPanel?.close()
        AppSettings.shared.hasSeenOnboarding = true
        stateMachine.startSession()
        showOrb()
    }
    
    func showOrb() {
        if let screen = NSScreen.main {
            let screenRect = screen.visibleFrame
            let margin: CGFloat = 24
            let x = screenRect.maxX - panel.frame.width - margin
            let y = screenRect.maxY - panel.frame.height - margin
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }
        panel.orderFront(nil)
        isOrbVisible = true
    }
    
    func hideOrb() {
        panel.orderOut(nil)
        isOrbVisible = false
    }
    
    @Published var isOrbVisible: Bool = false
    
    func toggleOrb() {
        print("🔄 toggleOrb called, isOrbVisible: \(isOrbVisible)")
        if isOrbVisible {
            hideOrb()
        } else {
            showOrb()
        }
    }

    private func revealOrbAtCurrentPosition() {
        panel.orderFront(nil)
        isOrbVisible = true
    }

    private func cancelPreEndSummary(showOrbAfterCancel: Bool) {
        isPresentingPreEndSummary = false
        summaryPanel?.orderOut(nil)
        if showOrbAfterCancel {
            revealOrbAtCurrentPosition()
        }
    }

    private func confirmEndSessionFromPreSummary() {
        isPresentingPreEndSummary = false
        skipPostEndSummaryOnce = true
        summaryPanel?.orderOut(nil)
        stateMachine.endSession()
    }
    
    func showDashboard() {
        print("📊 showDashboard called")
        NSApp.activate(ignoringOtherApps: true)
        
        // Create dashboard window if needed
        if dashboardWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = "FocusOrb · 复盘"
            window.center()
            window.contentView = NSHostingView(rootView: DashboardView(eventStore: EventStore.shared))
            window.isReleasedWhenClosed = false
            window.delegate = self
            dashboardWindow = window
        }
        
        dashboardWindow?.makeKeyAndOrderFront(nil)
    }

    func showSettings() {
        NSApp.activate(ignoringOtherApps: true)

        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 520, height: 360),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "FocusOrb · 设置"
            window.center()
            window.contentView = NSHostingView(rootView: SettingsView())
            window.isReleasedWhenClosed = false
            window.delegate = self
            settingsWindow = window
        }

        settingsWindow?.makeKeyAndOrderFront(nil)
    }
    
    // MARK: - NSWindowDelegate
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if sender == dashboardWindow {
            // Hide instead of close
            sender.orderOut(nil)
            return false
        }
        if sender == settingsWindow {
            sender.orderOut(nil)
            return false
        }
        return true
    }
    
    func showSummary() {
        isPresentingPreEndSummary = false

        guard let lastEndEvent = EventStore.shared.lastSessionEndEvent(),
              lastEndEvent.type == .sessionEnd else {
            showStart()
            return
        }

        let sessionId = lastEndEvent.sessionId
        let sessionEvents = EventStore.shared.events(for: sessionId)
        let stats = StatsCalculator.sessionStats(events: sessionEvents)
        let parentSessionId = sessionEvents.first(where: { $0.type == .sessionStart })?.parentSessionId
        let reflectionSessionId = parentSessionId ?? sessionId
        let startTime = sessionEvents.first(where: { $0.type == .sessionStart })?.timestamp ?? Date()
        let endTime = lastEndEvent.timestamp

        presentSummary(
            stats: stats,
            startTime: startTime,
            endTime: endTime,
            mergedCount: mergedSessionCount(for: sessionId),
            showReflection: AppSettings.shared.enableSessionReflection,
            onSetMood: { [weak self] mood in
                if let mood {
                    EventStore.shared.append(
                        OrbEvent(
                            type: .sessionReflection,
                            sessionId: reflectionSessionId,
                            meta: ["mood": mood.rawValue, "source": "summary"]
                        )
                    )
                }
                self?.summaryPanel?.orderOut(nil)
                self?.showStart()
            },
            onClose: { [weak self] in
                self?.summaryPanel?.orderOut(nil)
                self?.showStart()
            },
            onConfirmEnd: nil,
            onContinueSession: nil
        )
    }

    private func mergedSessionCount(for sessionId: UUID) -> Int? {
        let childSessions = EventStore.shared.events.filter { $0.parentSessionId == sessionId }
        let uniqueChildSessionIds = Set(childSessions.map { $0.sessionId })
        return uniqueChildSessionIds.isEmpty ? nil : (uniqueChildSessionIds.count + 1)
    }

    private func prepareSummaryPanelIfNeeded() {
        if summaryPanel == nil {
            summaryPanel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 340, height: 420),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            summaryPanel?.level = .floating
            summaryPanel?.backgroundColor = .clear
            summaryPanel?.isOpaque = false
            summaryPanel?.hasShadow = false
        }
    }

    private func presentSummary(
        stats: SessionStats,
        startTime: Date,
        endTime: Date,
        mergedCount: Int?,
        showReflection: Bool,
        onSetMood: @escaping (SessionMood?) -> Void,
        onClose: @escaping () -> Void,
        onConfirmEnd: (() -> Void)?,
        onContinueSession: (() -> Void)?
    ) {
        hideOrb()
        prepareSummaryPanelIfNeeded()

        let summaryView = SessionSummaryView(
            sessionDuration: stats.total,
            greenDuration: stats.green,
            redDuration: stats.red,
            segments: stats.segments,
            avgGreenStreak: stats.avgGreenStreak,
            startTime: startTime,
            endTime: endTime,
            mergedSessionCount: mergedCount,
            showReflection: showReflection,
            onSetMood: onSetMood,
            onClose: onClose,
            onConfirmEnd: onConfirmEnd,
            onContinueSession: onContinueSession
        )

        summaryPanel?.contentView = NSHostingView(rootView: summaryView)

        if let orbFrame = panel.frame as CGRect? {
            let centerX = orbFrame.midX
            let centerY = orbFrame.midY
            let summarySize = summaryPanel?.frame.size ?? CGSize(width: 340, height: 420)
            let summaryOrigin = CGPoint(
                x: centerX - summarySize.width / 2,
                y: centerY - summarySize.height / 2
            )
            summaryPanel?.setFrameOrigin(summaryOrigin)
        }

        summaryPanel?.orderFront(nil)
    }
}
