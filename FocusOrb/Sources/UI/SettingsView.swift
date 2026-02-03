import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    
    var body: some View {
        Form {
            Section(header: Text("Session Settings")) {
                Picker("Auto-merge sessions within:", selection: $settings.autoMergeWindowMinutes) {
                    Text("Disabled").tag(0)
                    Text("5 minutes").tag(5)
                    Text("10 minutes").tag(10)
                    Text("15 minutes").tag(15)
                    Text("30 minutes").tag(30)
                }
                
                Toggle("Show reflection prompt after session", isOn: $settings.enableSessionReflection)
            }
            
            Section(header: Text("App Behavior")) {
                Toggle("Launch at login", isOn: $settings.launchAtLogin)
                Toggle("Show orb on launch", isOn: $settings.showOrbOnLaunch)
            }
        }
        .padding(20)
        .frame(width: 520, height: 230)
    }
}
