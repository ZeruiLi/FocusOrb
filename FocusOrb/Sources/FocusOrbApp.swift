import SwiftUI
import AppKit

@main
struct FocusOrbApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @ObservedObject private var settings = AppSettings.shared
    
    var body: some Scene {
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
        
        // Initialize Core Logic
        let eventStore = EventStore.shared
        let stateMachine = OrbStateMachine(eventStore: eventStore)
        self.stateMachine = stateMachine
        _ = CaptureStore.shared
        ClipboardMonitor.shared.syncWithSettings()
        syncLaunchAtLoginSetting()

        // Keep active sessions recoverable across app quit/power-off.
        powerOffObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willPowerOffNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            self?.preserveActiveSessionForRecovery(trigger: "power_off")
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
        preserveActiveSessionForRecovery(trigger: "terminate")
        ClipboardMonitor.shared.stop()
        if let powerOffObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(powerOffObserver)
        }
    }

    private func preserveActiveSessionForRecovery(trigger: String) {
        guard let sessionId = stateMachine?.activeSessionId else { return }
        RuntimeSessionSnapshotStore.shared.recordTick(sessionId: sessionId)
        print("🧭 Preserve active session snapshot for recovery (\(trigger))")
    }

    private func syncLaunchAtLoginSetting() {
        let requested = AppSettings.shared.launchAtLogin
        if LaunchAtLoginManager.shared.isEnabled != requested {
            _ = LaunchAtLoginManager.shared.setEnabled(requested)
        }
        AppSettings.shared.launchAtLogin = LaunchAtLoginManager.shared.isEnabled
    }
}
