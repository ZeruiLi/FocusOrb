import SwiftUI
import AppKit
import Combine
import UserNotifications

enum LaunchDestination: Equatable {
    case firstLaunchAssist
    case startAndShowOrb
    case startOnly
    case resumeAndShowOrb
}

struct StartPresentationPolicy: Equatable {
    let hideOrbBeforeShow: Bool
    let allowClose: Bool
}

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
    var captureWindow: NSWindow?
    var quickNotePanel: NSPanel?
    var quickClipsPanel: NSPanel?
    var taskHUDPanel: NSPanel?
    private var resumeToastWindow: NSWindow?
    
    private let stateMachine: OrbStateMachine
    private let captureStore = CaptureStore.shared
    private let interactionState = OrbInteractionState()
    private let orbPanelSize = CGSize(width: 200.0 * (2.0 / 3.0), height: 170.0 * (2.0 / 3.0))
    private var cancellables = Set<AnyCancellable>()
    private var isPresentingPreEndSummary = false
    private var skipPostEndSummaryOnce = false
    private var isOrbInteractionLocked = false
    private var startPanelAllowsClose = false
    
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

    private func setOrbInteractionLocked(_ locked: Bool) {
        isOrbInteractionLocked = locked
        panel?.ignoresMouseEvents = locked
    }

    private func dismissStartPanelIfVisible() {
        startPanel?.orderOut(nil)
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
            guard let self = self, !self.isOrbInteractionLocked else { return }
            self.stateMachine.handleClick()
        }
        dragPanel.onLongPress = { [weak self] in
            guard let self = self, !self.isOrbInteractionLocked else { return }
            self.requestSessionEndFromOrb()
        }
        dragPanel.onPressStateChanged = { [weak self] isPressed in
            self?.interactionState.isPressed = isPressed
        }
        dragPanel.onDragBegan = { [weak self] in
            self?.interactionState.isPressed = false
        }
        dragPanel.onDragEnded = { [weak self] in
            self?.refreshTaskHUD()
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
        
        let endSessionItem = NSMenuItem(title: L10n.string("End Session"), action: #selector(menuEndSession), keyEquivalent: "")
        endSessionItem.target = self
        menu.addItem(endSessionItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let dashboardItem = NSMenuItem(title: L10n.string("Dashboard"), action: #selector(menuShowDashboard), keyEquivalent: "d")
        dashboardItem.target = self
        menu.addItem(dashboardItem)

        let captureItem = NSMenuItem(title: L10n.string("Capture"), action: #selector(menuShowCapture), keyEquivalent: "c")
        captureItem.target = self
        menu.addItem(captureItem)

        let quickNoteItem = NSMenuItem(title: L10n.string("Quick Note"), action: #selector(menuShowQuickNote), keyEquivalent: "n")
        quickNoteItem.target = self
        menu.addItem(quickNoteItem)

        let quickClipsItem = NSMenuItem(title: L10n.string("Quick Clips"), action: #selector(menuShowQuickClips), keyEquivalent: "l")
        quickClipsItem.target = self
        menu.addItem(quickClipsItem)
        
        let hideItem = NSMenuItem(title: L10n.string("Hide Orb"), action: #selector(menuHideOrb), keyEquivalent: "h")
        hideItem.target = self
        menu.addItem(hideItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: L10n.string("Quit"), action: #selector(menuQuit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        self.contextMenu = menu
    }
    
    private var contextMenu: NSMenu?
    
    private func showContextMenu(at location: NSPoint, in view: NSView) {
        guard !isOrbInteractionLocked else { return }
        guard let menu = contextMenu else { return }
        menu.popUp(positioning: nil, at: location, in: view)
    }
    
    // MARK: - Menu Actions
    
    @objc private func menuEndSession() {
        requestSessionEndFromExternal()
    }
    
    @objc private func menuShowDashboard() {
        DispatchQueue.main.async { [weak self] in
            self?.showDashboard()
        }
    }

    @objc private func menuShowCapture() {
        DispatchQueue.main.async { [weak self] in
            self?.showCapture(initialTab: .notes)
        }
    }

    @objc private func menuShowQuickNote() {
        DispatchQueue.main.async { [weak self] in
            self?.showQuickNote()
        }
    }

    @objc private func menuShowQuickClips() {
        DispatchQueue.main.async { [weak self] in
            self?.showQuickClips()
        }
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
        guard !isOrbInteractionLocked else { return }
        guard !isPresentingPreEndSummary else { return }
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
                guard let self = self else { return }
                if case .idle = state {
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
                } else {
                    if self.startPanel?.isVisible == true {
                        self.dismissStartPanelIfVisible()
                    }
                    if !AppSettings.shared.hasSeenOnboarding {
                        AppSettings.shared.hasSeenOnboarding = true
                    }
                }
                self.refreshTaskHUD()
            }
            .store(in: &cancellables)

        captureStore.$topTask
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshTaskHUD()
            }
            .store(in: &cancellables)

        AppSettings.shared.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshTaskHUD()
                self?.refreshLocalizedUI()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Flow Control
    
    static func launchDestination(
        currentState: OrbState,
        hasSeenOnboarding: Bool,
        showOrbOnLaunch: Bool
    ) -> LaunchDestination {
        if case .idle = currentState {
            if !hasSeenOnboarding {
                return .firstLaunchAssist
            }
            return showOrbOnLaunch ? .startAndShowOrb : .startOnly
        }
        return .resumeAndShowOrb
    }

    static func startPresentationPolicy(for destination: LaunchDestination) -> StartPresentationPolicy {
        switch destination {
        case .firstLaunchAssist:
            return StartPresentationPolicy(hideOrbBeforeShow: false, allowClose: true)
        case .startOnly:
            return StartPresentationPolicy(hideOrbBeforeShow: true, allowClose: false)
        case .startAndShowOrb, .resumeAndShowOrb:
            return StartPresentationPolicy(hideOrbBeforeShow: false, allowClose: true)
        }
    }

    func launchApp() {
        let destination = Self.launchDestination(
            currentState: stateMachine.currentState,
            hasSeenOnboarding: AppSettings.shared.hasSeenOnboarding,
            showOrbOnLaunch: AppSettings.shared.showOrbOnLaunch
        )

        switch destination {
        case .firstLaunchAssist:
            let policy = Self.startPresentationPolicy(for: destination)
            showOrb()
            showStart(
                hideOrbBeforeShow: policy.hideOrbBeforeShow,
                allowClose: policy.allowClose
            )
        case .startAndShowOrb:
            stateMachine.startSession()
            showOrb()
        case .startOnly:
            let policy = Self.startPresentationPolicy(for: destination)
            showStart(
                hideOrbBeforeShow: policy.hideOrbBeforeShow,
                allowClose: policy.allowClose
            )
        case .resumeAndShowOrb:
            showOrb()
            showResumeToast()
        }
    }
    
    private func showResumeToast() {
        if let existing = resumeToastWindow {
            existing.orderOut(nil)
            existing.close()
            resumeToastWindow = nil
        }

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
        toastWindow.isReleasedWhenClosed = false
        resumeToastWindow = toastWindow
        
        let toastView = NSView(frame: toastWindow.contentRect(forFrameRect: toastWindow.frame))
        toastView.wantsLayer = true
        toastView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.85).cgColor
        toastView.layer?.cornerRadius = 12
        
        let label = NSTextField(labelWithString: L10n.string("✅ 已恢复上次会话\n您的专注会话已从上次中断处继续"))
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self, weak toastWindow] in
            guard let self, let toastWindow else { return }
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.3
                toastWindow.animator().alphaValue = 0
            }, completionHandler: {
                toastWindow.close()
                if self.resumeToastWindow === toastWindow {
                    self.resumeToastWindow = nil
                }
            })
        }
    }
    
    private func showStart(
        hideOrbBeforeShow: Bool = true,
        allowClose: Bool = false
    ) {
        NSApp.activate(ignoringOtherApps: true)
        setOrbInteractionLocked(false)
        startPanelAllowsClose = allowClose
        if hideOrbBeforeShow {
            hideOrb()
        }

        if startPanel == nil {
            let startView = StartView { [weak self] in
                self?.startFlow()
            }

            var styleMask: NSWindow.StyleMask = [.titled, .fullSizeContentView]
            if allowClose {
                styleMask.insert(.closable)
            }
            
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 300, height: 250),
                styleMask: styleMask,
                backing: .buffered,
                defer: false
            )
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.center()
            window.contentView = NSHostingView(rootView: localizedRoot(startView))
            window.isReleasedWhenClosed = false
            window.delegate = self
            startPanel = window
        }

        configureStartPanelCloseBehavior(allowClose: allowClose)
        
        startPanel?.makeKeyAndOrderFront(nil)
    }
    
    private func configureStartPanelCloseBehavior(allowClose: Bool) {
        guard let startPanel else { return }
        var styleMask = startPanel.styleMask
        if allowClose {
            styleMask.insert(.closable)
        } else {
            styleMask.remove(.closable)
        }
        startPanel.styleMask = styleMask
        startPanel.standardWindowButton(.closeButton)?.isHidden = !allowClose
    }

    private func startFlow() {
        dismissStartPanelIfVisible()
        AppSettings.shared.hasSeenOnboarding = true
        stateMachine.startSession()
        showOrb()
    }
    
    func showOrb() {
        guard !isOrbInteractionLocked else { return }

        if let screen = NSScreen.main {
            let screenRect = screen.visibleFrame
            let margin: CGFloat = 24
            let x = screenRect.maxX - panel.frame.width - margin
            let y = screenRect.maxY - panel.frame.height - margin
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }
        panel.orderFront(nil)
        isOrbVisible = true
        refreshTaskHUD()
    }
    
    func hideOrb() {
        panel.orderOut(nil)
        isOrbVisible = false
        hideTaskHUD()
    }
    
    @Published var isOrbVisible: Bool = false
    
    func toggleOrb() {
        guard !isOrbInteractionLocked else { return }
        print("🔄 toggleOrb called, isOrbVisible: \(isOrbVisible)")
        if isOrbVisible {
            hideOrb()
        } else {
            showOrb()
        }
    }

    private func revealOrbAtCurrentPosition() {
        guard !isOrbInteractionLocked else { return }
        panel.orderFront(nil)
        isOrbVisible = true
        refreshTaskHUD()
    }

    private func cancelPreEndSummary(showOrbAfterCancel: Bool) {
        isPresentingPreEndSummary = false
        summaryPanel?.orderOut(nil)
        setOrbInteractionLocked(false)
        if showOrbAfterCancel {
            revealOrbAtCurrentPosition()
        }
    }

    private func confirmEndSessionFromPreSummary() {
        isPresentingPreEndSummary = false
        skipPostEndSummaryOnce = true
        summaryPanel?.orderOut(nil)
        setOrbInteractionLocked(false)
        stateMachine.endSession()
    }
    
    func showDashboard() {
        print("📊 showDashboard called")
        NSApp.activate(ignoringOtherApps: true)
        
        // Create dashboard window if needed
        if dashboardWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 920, height: 780),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = L10n.string("FocusOrb · 复盘")
            window.center()
            window.contentView = NSHostingView(rootView: localizedRoot(DashboardView(eventStore: EventStore.shared)))
            window.isReleasedWhenClosed = false
            window.delegate = self
            dashboardWindow = window
        }
        
        dashboardWindow?.makeKeyAndOrderFront(nil)
    }

    func showCapture(initialTab: CaptureTab = .notes) {
        NSApp.activate(ignoringOtherApps: true)

        if captureWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 700, height: 920),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = L10n.string("FocusOrb · Capture")
            window.center()
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.minSize = NSSize(width: 660, height: 820)
            captureWindow = window
        }

        captureWindow?.minSize = NSSize(width: 660, height: 820)
        captureWindow?.contentView = NSHostingView(rootView: localizedRoot(CaptureDrawerView(initialTab: initialTab)))
        captureWindow?.makeKeyAndOrderFront(nil)
    }

    func showQuickNote() {
        NSApp.activate(ignoringOtherApps: true)

        if quickNotePanel == nil {
            quickNotePanel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 340, height: 180),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            quickNotePanel?.title = L10n.string("Quick Note")
            quickNotePanel?.isFloatingPanel = true
            quickNotePanel?.level = .floating
            quickNotePanel?.isReleasedWhenClosed = false
            quickNotePanel?.delegate = self
            quickNotePanel?.hidesOnDeactivate = false
        }

        let rootView = QuickNotePopoverView(captureStore: captureStore) { [weak self] in
            self?.quickNotePanel?.orderOut(nil)
        }
        quickNotePanel?.contentView = NSHostingView(rootView: localizedRoot(rootView))
        positionQuickPanel(quickNotePanel, preferredSize: CGSize(width: 340, height: 190))
        quickNotePanel?.makeKeyAndOrderFront(nil)
    }

    func showQuickClips() {
        NSApp.activate(ignoringOtherApps: true)

        if quickClipsPanel == nil {
            quickClipsPanel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 380, height: 360),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            quickClipsPanel?.title = L10n.string("Quick Clips")
            quickClipsPanel?.isFloatingPanel = true
            quickClipsPanel?.level = .floating
            quickClipsPanel?.isReleasedWhenClosed = false
            quickClipsPanel?.delegate = self
            quickClipsPanel?.hidesOnDeactivate = false
        }

        let rootView = QuickClipsPopoverView(captureStore: captureStore) { [weak self] in
            self?.quickClipsPanel?.orderOut(nil)
        }
        quickClipsPanel?.contentView = NSHostingView(rootView: localizedRoot(rootView))
        positionQuickPanel(quickClipsPanel, preferredSize: CGSize(width: 380, height: 360))
        quickClipsPanel?.makeKeyAndOrderFront(nil)
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
            window.title = L10n.string("FocusOrb · 设置")
            window.center()
            window.contentView = NSHostingView(rootView: localizedRoot(SettingsView()))
            window.isReleasedWhenClosed = false
            window.delegate = self
            settingsWindow = window
        }

        settingsWindow?.makeKeyAndOrderFront(nil)
    }
    
    // MARK: - NSWindowDelegate
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if sender == startPanel {
            if startPanelAllowsClose {
                sender.orderOut(nil)
            } else {
                sender.makeKeyAndOrderFront(nil)
            }
            return false
        }
        if sender == dashboardWindow {
            // Hide instead of close
            sender.orderOut(nil)
            return false
        }
        if sender == settingsWindow {
            sender.orderOut(nil)
            return false
        }
        if sender == captureWindow {
            sender.orderOut(nil)
            return false
        }
        if sender == quickNotePanel {
            sender.orderOut(nil)
            return false
        }
        if sender == quickClipsPanel {
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
                    self?.resolveSaveMoodToNotesPreferenceIfNeeded()
                    EventStore.shared.append(
                        OrbEvent(
                            type: .sessionReflection,
                            sessionId: reflectionSessionId,
                            meta: ["mood": mood.rawValue, "source": "summary"]
                        )
                    )
                    if AppSettings.shared.saveMoodToNotes {
                        let content = self?.buildReflectionNoteContent(
                            mood: mood,
                            startTime: startTime,
                            endTime: endTime
                        ) ?? L10n.string("[会话心情] %@", mood.title)
                        CaptureStore.shared.addNote(
                            content: content,
                            source: .reflection,
                            sessionId: reflectionSessionId
                        )
                    }
                }
                self?.setOrbInteractionLocked(false)
                self?.summaryPanel?.orderOut(nil)
                self?.showStart()
            },
            onClose: { [weak self] in
                self?.setOrbInteractionLocked(false)
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
                contentRect: NSRect(x: 0, y: 0, width: 396, height: 620),
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
        setOrbInteractionLocked(true)
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

        summaryPanel?.contentView = NSHostingView(rootView: localizedRoot(summaryView))

        if let orbFrame = panel.frame as CGRect? {
            let centerX = orbFrame.midX
            let centerY = orbFrame.midY
            let summarySize = summaryPanel?.frame.size ?? CGSize(width: 396, height: 620)
            let summaryOrigin = CGPoint(
                x: centerX - summarySize.width / 2,
                y: centerY - summarySize.height / 2
            )
            summaryPanel?.setFrameOrigin(summaryOrigin)
        }

        summaryPanel?.orderFront(nil)
    }

    // MARK: - Top Task HUD

    private func hideTaskHUD() {
        taskHUDPanel?.orderOut(nil)
    }

    private func refreshTaskHUD() {
        guard isOrbVisible else {
            hideTaskHUD()
            return
        }
        guard AppSettings.shared.showTopTaskHUD else {
            hideTaskHUD()
            return
        }
        guard let task = captureStore.topTask else {
            hideTaskHUD()
            return
        }

        let panel = ensureTaskHUDPanel()
        let estimatedWidth = estimateTopTaskHUDWidth(taskTitle: task.title)
        let preferredWidth = min(max(170, estimatedWidth), 420)
        let preferredSize = CGSize(width: preferredWidth, height: 34)
        panel.setContentSize(preferredSize)
        panel.contentView = NSHostingView(
            rootView: localizedRoot(TopTaskHUDView(taskTitle: task.title) { [weak self] in
                self?.showCapture(initialTab: .tasks)
            })
        )

        positionTaskHUD()
        panel.orderFront(nil)
    }

    private func ensureTaskHUDPanel() -> NSPanel {
        if let taskHUDPanel {
            return taskHUDPanel
        }

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 220, height: 34),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.isMovable = false
        panel.isReleasedWhenClosed = false
        taskHUDPanel = panel
        return panel
    }

    private func estimateTopTaskHUDWidth(taskTitle: String) -> CGFloat {
        let prefixText = L10n.string("Next:") as NSString
        let titleText = taskTitle as NSString

        let prefixWidth = prefixText.size(
            withAttributes: [.font: NSFont.systemFont(ofSize: 11, weight: .semibold)]
        ).width
        let titleWidth = titleText.size(
            withAttributes: [.font: NSFont.systemFont(ofSize: 12, weight: .semibold)]
        ).width

        // Icon + fixed paddings + inner spacings.
        return ceil(prefixWidth + titleWidth + 50)
    }

    private func positionTaskHUD() {
        guard let hudPanel = taskHUDPanel else { return }

        let orbFrame = panel.frame
        let hudSize = hudPanel.frame.size
        guard let screen = panel.screen ?? NSScreen.main else { return }
        let visible = screen.visibleFrame

        var x = orbFrame.midX - hudSize.width / 2
        x = min(max(x, visible.minX + 8), visible.maxX - hudSize.width - 8)

        // Orb panel is larger than the visual cloud; anchor HUD to the cloud bottom.
        let visualCloudBottomInset: CGFloat = 24
        var y = orbFrame.minY + visualCloudBottomInset - hudSize.height - 4
        if y < visible.minY + 8 {
            y = orbFrame.maxY - 14
        }

        hudPanel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func positionQuickPanel(_ panel: NSPanel?, preferredSize: CGSize) {
        guard let panel else { return }
        panel.setContentSize(preferredSize)

        let screen = self.panel.screen ?? NSScreen.main
        let visible = screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
        let anchor = self.panel.frame

        var x = anchor.maxX - preferredSize.width
        var y = anchor.minY - preferredSize.height - 12
        if y < visible.minY + 8 {
            y = anchor.maxY + 12
        }

        x = min(max(x, visible.minX + 8), visible.maxX - preferredSize.width - 8)
        y = min(max(y, visible.minY + 8), visible.maxY - preferredSize.height - 8)
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func resolveSaveMoodToNotesPreferenceIfNeeded() {
        guard !AppSettings.shared.hasAskedSaveMoodToNotes else { return }

        let alert = NSAlert()
        alert.messageText = L10n.string("保存心情到 Notes？")
        alert.informativeText = L10n.string("以后将自动把会话心情保存到 Notes。你可以在设置里随时修改。")
        alert.addButton(withTitle: L10n.string("保存"))
        alert.addButton(withTitle: L10n.string("不保存"))
        let response = alert.runModal()

        AppSettings.shared.saveMoodToNotes = (response == .alertFirstButtonReturn)
        AppSettings.shared.hasAskedSaveMoodToNotes = true
    }

    private func buildReflectionNoteContent(mood: SessionMood, startTime: Date, endTime: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return L10n.string(
            "[会话心情] %@-%@ · %@",
            formatter.string(from: startTime),
            formatter.string(from: endTime),
            mood.title
        )
    }

    private func refreshLocalizedUI() {
        buildContextMenu()
        dashboardWindow?.title = L10n.string("FocusOrb · 复盘")
        captureWindow?.title = L10n.string("FocusOrb · Capture")
        quickNotePanel?.title = L10n.string("Quick Note")
        quickClipsPanel?.title = L10n.string("Quick Clips")
        settingsWindow?.title = L10n.string("FocusOrb · 设置")
    }

    private func localizedRoot<Content: View>(_ rootView: Content) -> some View {
        LocalizedHostingRoot(content: rootView)
    }
}

private struct LocalizedHostingRoot<Content: View>: View {
    @ObservedObject private var settings = AppSettings.shared
    let content: Content

    var body: some View {
        content.environment(\.locale, settings.locale)
    }
}
