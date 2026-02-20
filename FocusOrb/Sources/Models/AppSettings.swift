import SwiftUI

class AppSettings: ObservableObject {
    static let shared = AppSettings()
    static let redPendingDuration: TimeInterval = 3.0 // 3秒倒计时

    @AppStorage("appLanguage") private var appLanguageRawValue: String = AppLanguage.system.rawValue
    
    @AppStorage("autoMergeWindowMinutes") var autoMergeWindowMinutes: Int = 5
    @AppStorage("autoBreakIdleMinutes") var autoBreakIdleMinutes: Int = 0
    @AppStorage("autoBreakFillSeconds") var autoBreakFillSeconds: Int = 60
    @AppStorage("launchAtLogin") var launchAtLogin: Bool = false
    @AppStorage("showOrbOnLaunch") var showOrbOnLaunch: Bool = true
    @AppStorage("hasSeenOnboarding") var hasSeenOnboarding: Bool = false
    @AppStorage("enableSessionReflection") var enableSessionReflection: Bool = true
    @AppStorage("showTopTaskHUD") var showTopTaskHUD: Bool = true
    @AppStorage("enableClips") var enableClips: Bool = true
    @AppStorage("pauseClips") var pauseClips: Bool = false
    @AppStorage("saveMoodToNotes") var saveMoodToNotes: Bool = false
    @AppStorage("hasAskedSaveMoodToNotes") var hasAskedSaveMoodToNotes: Bool = false

    var appLanguage: AppLanguage {
        get {
            AppLanguage(rawValue: appLanguageRawValue) ?? .system
        }
        set {
            let newRawValue = newValue.rawValue
            guard appLanguageRawValue != newRawValue else { return }
            appLanguageRawValue = newRawValue
            objectWillChange.send()
        }
    }

    var locale: Locale {
        appLanguage.locale
    }
    
    private init() {}
}
