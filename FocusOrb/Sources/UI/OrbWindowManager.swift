import SwiftUI
import AppKit
import Combine
import UserNotifications

// Custom NSHostingView subclass to intercept right-clicks
class RightClickHostingView<Content: View>: NSHostingView<Content> {
    var onRightClick: ((NSPoint) -> Void)?
    
    override func rightMouseDown(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        onRightClick?(location)
        // Don't call super - we handle it ourselves
    }
}

// Custom NSPanel to handle drag threshold with delayed event dispatch
class DraggablePanel: NSPanel {
    private var pendingMouseDownEvent: NSEvent?
    private var isDragging = false
    private var hasSentMouseDown = false
    private let dragThreshold: CGFloat = 10.0
    private var mouseDownTimer: Timer?
    
    // Helper to avoid calling super in closure
    private func forwardEvent(_ event: NSEvent) {
        super.sendEvent(event)
    }
    
    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown {
            // Store the event and start a timer
            pendingMouseDownEvent = event
            isDragging = false
            hasSentMouseDown = false
            
            // Wait 100ms to see if user is dragging or clicking
            mouseDownTimer?.invalidate()
            mouseDownTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { [weak self] _ in
                guard let self = self, let downEvent = self.pendingMouseDownEvent else { return }
                
                // If we haven't started dragging by now, it's a click/long-press
                if !self.isDragging {
                    self.forwardEvent(downEvent)
                    self.hasSentMouseDown = true
                }
            }
        } else if event.type == .leftMouseDragged {
            // ANY drag movement should cancel the timer (even small movements)
            if !isDragging && mouseDownTimer != nil {
                mouseDownTimer?.invalidate()
            }
            
            if let downEvent = pendingMouseDownEvent {
                // Check if we moved enough to call it a "real" drag
                let dx = abs(event.locationInWindow.x - downEvent.locationInWindow.x)
                let dy = abs(event.locationInWindow.y - downEvent.locationInWindow.y)
                
                if dx > dragThreshold || dy > dragThreshold {
                    isDragging = true
                }
            }
            
            if isDragging {
                // Handle window dragging manually
                self.setFrameOrigin(NSPoint(x: self.frame.origin.x + event.deltaX, y: self.frame.origin.y - event.deltaY))
            } else if hasSentMouseDown {
                // Timer has fired, forward drag events to SwiftUI (for small jitter during long press)
                super.sendEvent(event)
            }
            // If timer hasn't fired and not dragging, don't send drag events (waiting for timer)
        } else if event.type == .leftMouseUp {
            mouseDownTimer?.invalidate()
            
            if isDragging {
                // We were dragging, do NOT send any events to SwiftUI
            } else if hasSentMouseDown {
                // Timer already sent MouseDown, just send MouseUp for normal click/long-press
                super.sendEvent(event)
            } else if let downEvent = pendingMouseDownEvent {
                // Very fast click (< 100ms), send both Down and Up
                super.sendEvent(downEvent)
                super.sendEvent(event)
            }
            
            pendingMouseDownEvent = nil
            isDragging = false
            hasSentMouseDown = false
        } else {
            super.sendEvent(event)
        }
    }
}

class OrbWindowManager: NSObject, ObservableObject, NSWindowDelegate {
    var panel: NSPanel!
    var summaryPanel: NSPanel?
    var startPanel: NSWindow?
    var dashboardWindow: NSWindow?  // Managed dashboard window
    
    private let stateMachine: OrbStateMachine
    private var cancellables = Set<AnyCancellable>()
    
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
        // Updated Window Logic: Borderless (Fix Transparency) + Large Size (Fix Clipping)
        // Use DraggablePanel instead of standard NSPanel
        let dragPanel = DraggablePanel(
            contentRect: NSRect(x: 100, y: 100, width: 120, height: 120),
            styleMask: [.borderless, .nonactivatingPanel], 
            backing: .buffered,
            defer: false
        )
        self.panel = dragPanel
        
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        // Critical for transparency
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false 
        
        // Disable standard moving to use our custom draggable logic
        panel.isMovableByWindowBackground = false
        
        // Orb View with custom hosting view for right-click
        // Pass a binding or callback for drag state if needed in View (optional if we consume the event)
        // For now, DraggablePanel consuming MouseUp after drag is enough to stop TapGesture.
        let contentView = OrbView(stateMachine: stateMachine)
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
        stateMachine.endSession()
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
    
    func setupObservers() {
        // Watch for State transitions to .idle (Session Ended)
        stateMachine.$currentState
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] state in
                if case .idle = state {
                    guard let self = self else { return }
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
            let x = screenRect.maxX - 150
            let y = screenRect.maxY - 150
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
            window.title = "FocusOrb Dashboard"
            window.center()
            window.contentView = NSHostingView(rootView: DashboardView(eventStore: EventStore.shared))
            window.isReleasedWhenClosed = false
            window.delegate = self
            dashboardWindow = window
        }
        
        dashboardWindow?.makeKeyAndOrderFront(nil)
    }
    
    // MARK: - NSWindowDelegate
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if sender == dashboardWindow {
            // Hide instead of close
            sender.orderOut(nil)
            return false
        }
        return true
    }
    
    func showSummary() {
        hideOrb() 
        
        // 从最后一条 sessionEnd 事件获取 sessionId
        guard let lastEndEvent = EventStore.shared.lastSessionEndEvent(),
              lastEndEvent.type == .sessionEnd else {
            showStart()  // 没有结束事件，回到开始页
            return
        }
        let sessionId = lastEndEvent.sessionId
        let sessionEvents = EventStore.shared.events(for: sessionId)
        let stats: SessionStats = StatsCalculator.sessionStats(events: sessionEvents)
        
        // Calculate session time range
        let startTime = sessionEvents.first(where: { $0.type == .sessionStart })?.timestamp ?? Date()
        let endTime = lastEndEvent.timestamp
        
        // Calculate merged count: count how many sessions have this session as parent + self
        let childSessions = EventStore.shared.events.filter { $0.parentSessionId == sessionId }
        let uniqueChildSessionIds = Set(childSessions.map { $0.sessionId })
        let mergedCount = uniqueChildSessionIds.isEmpty ? nil : (uniqueChildSessionIds.count + 1)
        
        if summaryPanel == nil {
            summaryPanel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 280, height: 320),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            summaryPanel?.level = .floating
            summaryPanel?.backgroundColor = .clear
            summaryPanel?.isOpaque = false
            summaryPanel?.hasShadow = false
        }
        
        let summaryView = SessionSummaryView(
            sessionDuration: stats.total,
            greenDuration: stats.green,
            redDuration: stats.red,
            segments: stats.segments,
            avgGreenStreak: stats.avgGreenStreak,
            startTime: startTime,
            endTime: endTime,
            mergedSessionCount: mergedCount,
            onClose: { [weak self] in
                self?.summaryPanel?.orderOut(nil)
                self?.showStart()
            }
        )
        
        summaryPanel?.contentView = NSHostingView(rootView: summaryView)
        
        // Position exactly where the orb was
        if let orbFrame = panel.frame as CGRect? {
            let centerX = orbFrame.midX
            let centerY = orbFrame.midY
            let summaryWidth: CGFloat = 220
            let summaryHeight: CGFloat = 140
            
            let summaryOrigin = CGPoint(
                x: centerX - summaryWidth/2,
                y: centerY - summaryHeight/2
            )
            summaryPanel?.setFrameOrigin(summaryOrigin)
        }
        
        summaryPanel?.orderFront(nil)
    }
}
