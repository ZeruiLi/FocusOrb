import AppKit
import SwiftUI
import Combine

class StatusBarManager {
    private var statusItem: NSStatusItem?
    private weak var windowManager: OrbWindowManager?
    private weak var stateMachine: OrbStateMachine?
    private var cancellables = Set<AnyCancellable>()
    
    func setup(windowManager: OrbWindowManager, stateMachine: OrbStateMachine) {
        self.windowManager = windowManager
        self.stateMachine = stateMachine
        
        // Create status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength) // Revert to square
        statusItem?.isVisible = true
        
        guard let button = statusItem?.button else {
            print("❌ Failed to create status bar button")
            return
        }
        
        // Enforce basic layout
        button.imagePosition = .imageLeft
        
        print("✅ Status bar item created")
        
        // Set initial visible icon (SF Symbol)
        if let image = NSImage(systemSymbolName: "circle.fill", accessibilityDescription: "FocusOrb") {
            let config = NSImage.SymbolConfiguration(paletteColors: [.systemGreen])
            button.image = image.withSymbolConfiguration(config)
        } else {
            // Fallback if SF Symbol fails (unlikely on macOS 11+, but safe)
            button.title = "●"
        }
        
        button.action = #selector(statusBarButtonClicked(_:))
        button.target = self
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        
        // Build menu for right-click
        buildMenu()
        
        // Subscribe to state changes to update icon color
        stateMachine.$currentState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.updateIcon(for: state)
            }
            .store(in: &cancellables)
        
        // Initial icon update
        updateIcon(for: stateMachine.currentState)
    }
    
    @objc private func statusBarButtonClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        
        if event.type == .rightMouseUp {
            // Show menu on right-click
            if statusItem?.menu != nil {
                statusItem?.button?.performClick(nil)
            } else {
                showMenu()
            }
        } else {
            // Toggle orb visibility on left-click
            windowManager?.toggleOrb()
        }
    }
    
    private func showMenu() {
        guard let button = statusItem?.button else { return }
        let menu = buildMenu()
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 5), in: button)
    }
    
    @discardableResult
    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        
        let showOrbItem = NSMenuItem(title: "Show/Hide Orb", action: #selector(toggleOrbAction), keyEquivalent: "")
        showOrbItem.target = self
        menu.addItem(showOrbItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let endSessionItem = NSMenuItem(title: "End Session", action: #selector(endSessionAction), keyEquivalent: "")
        endSessionItem.target = self
        menu.addItem(endSessionItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let dashboardItem = NSMenuItem(title: "Dashboard", action: #selector(dashboardAction), keyEquivalent: "d")
        dashboardItem.target = self
        menu.addItem(dashboardItem)
        
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(settingsAction), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "Quit FocusOrb", action: #selector(quitAction), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        return menu
    }
    
    private func updateIcon(for state: OrbState) {
        guard let button = statusItem?.button else { return }
        
        let symbolName: String
        let color: NSColor
        
        switch state {
        case .green:
            symbolName = "circle.fill"
            color = NSColor.systemGreen
        case .redPending:
            symbolName = "hourglass.circle.fill" // Or just circle.fill with orange
            color = NSColor.systemOrange
        case .red:
            symbolName = "record.circle.fill" // Or circle.circle.fill
            color = NSColor.systemRed
        case .idle:
            symbolName = "circle"
            color = NSColor.gray
        }
        
        if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(paletteColors: [color])
            button.image = image.withSymbolConfiguration(config)
        } else {
            // Fallback logic
            button.image = nil
            button.title = "●"
            button.contentTintColor = color
        }
    }
    
    // MARK: - Actions
    
    @objc private func toggleOrbAction() {
        windowManager?.toggleOrb()
    }
    
    @objc private func endSessionAction() {
        stateMachine?.endSession()
    }
    
    @objc private func dashboardAction() {
        windowManager?.showDashboard()
    }
    
    @objc private func settingsAction() {
        windowManager?.showSettings()
    }
    
    @objc private func quitAction() {
        NSApp.terminate(nil)
    }
}
