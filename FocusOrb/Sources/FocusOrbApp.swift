import SwiftUI
import SwiftData
import AppKit

@main
struct FocusOrbApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @ObservedObject private var settings = AppSettings.shared
    
    var body: some Scene {
        // The Main Dashboard Window (only shown when explicitly opened)
        WindowGroup(id: "dashboard") {
            DashboardView(eventStore: EventStore.shared)
                .environment(\.locale, settings.locale)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
        
        Settings {
            SettingsView()
                .environment(\.locale, settings.locale)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var orbWindowManager: OrbWindowManager?
    var statusBarManager: StatusBarManager?
    var stateMachine: OrbStateMachine?
    private var powerOffObserver: Any?
    
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
        self.stateMachine = stateMachine
        _ = CaptureStore.shared
        ClipboardMonitor.shared.syncWithSettings()
        syncLaunchAtLoginSetting()

        // Best-effort: close an active session on shutdown/power-off.
        powerOffObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willPowerOffNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            self?.endActiveSessionIfNeeded(reason: "power_off")
        }
        
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

    func applicationWillTerminate(_ notification: Notification) {
        endActiveSessionIfNeeded(reason: "terminate")
        ClipboardMonitor.shared.stop()
        if let powerOffObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(powerOffObserver)
        }
    }

    private func endActiveSessionIfNeeded(reason: String) {
        guard let sessionId = stateMachine?.activeSessionId else { return }
        EventStore.shared.append(
            OrbEvent(type: .sessionEnd, sessionId: sessionId, meta: ["reason": reason])
        )
        RuntimeSessionSnapshotStore.shared.clear()
    }

    private func syncLaunchAtLoginSetting() {
        let requested = AppSettings.shared.launchAtLogin
        if LaunchAtLoginManager.shared.isEnabled != requested {
            _ = LaunchAtLoginManager.shared.setEnabled(requested)
        }
        AppSettings.shared.launchAtLogin = LaunchAtLoginManager.shared.isEnabled
    }
}
