import SwiftUI

class AppSettings: ObservableObject {
    static let shared = AppSettings()
    static let redPendingDuration: TimeInterval = 3.0 // 3秒倒计时
    
    @AppStorage("autoMergeWindowMinutes") var autoMergeWindowMinutes: Int = 5
    @AppStorage("launchAtLogin") var launchAtLogin: Bool = false
    @AppStorage("showOrbOnLaunch") var showOrbOnLaunch: Bool = true
    @AppStorage("hasSeenOnboarding") var hasSeenOnboarding: Bool = false
    @AppStorage("enableSessionReflection") var enableSessionReflection: Bool = true
    
    private init() {}
}
