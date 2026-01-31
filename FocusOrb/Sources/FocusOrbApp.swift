import SwiftUI
import SwiftData

@main
struct FocusOrbApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        // The Main Dashboard Window (only shown when explicitly opened)
        WindowGroup(id: "dashboard") {
            DashboardView(eventStore: EventStore.shared)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
        
        Settings {
            SettingsView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var orbWindowManager: OrbWindowManager?
    var statusBarManager: StatusBarManager?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set as accessory app (menu bar only, no Dock icon)
        NSApp.setActivationPolicy(.accessory)
        
        // Hide (not close) any auto-opened windows (dashboard from WindowGroup)
        // Hiding allows us to show them later
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            for window in NSApp.windows where !(window is NSPanel) {
                window.isReleasedWhenClosed = false  // Prevent destruction on close
                window.orderOut(nil)  // Hide instead of close
            }
        }
        
        // Initialize Core Logic
        let eventStore = EventStore.shared
        let stateMachine = OrbStateMachine(eventStore: eventStore)
        
        // Initialize Orb Window
        orbWindowManager = OrbWindowManager(stateMachine: stateMachine)
        orbWindowManager?.launchApp() // Start with Start Screen
        
        // Initialize Status Bar - Delayed to prevent launch race conditions
        statusBarManager = StatusBarManager()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak orbWindowManager] in
            guard let windowManager = orbWindowManager else { return }
            self.statusBarManager?.setup(windowManager: windowManager, stateMachine: stateMachine)
        }
    }
}
