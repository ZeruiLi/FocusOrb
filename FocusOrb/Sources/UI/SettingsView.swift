import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    @State private var isSyncingLaunchAtLogin = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                StickerHeader(
                    imageName: "focus",
                    title: "设置",
                    subtitle: "偏好与自动化",
                    style: .leading,
                    iconSize: 36
                )

                settingsSection(title: "Language", systemImage: "globe") {
                    settingsRow(icon: "character.bubble", title: "App Language") {
                        Picker(
                            "",
                            selection: Binding(
                                get: { settings.appLanguage },
                                set: { settings.appLanguage = $0 }
                            )
                        ) {
                            ForEach(AppLanguage.allCases) { language in
                                Text(L10n.string(language.displayNameKey)).tag(language)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(width: 160)
                    }
                }

                    settingsSection(title: "Session Settings", systemImage: "timer") {
                    settingsRow(icon: "rectangle.3.group", title: "Auto-merge sessions within") {
                        Picker("", selection: $settings.autoMergeWindowMinutes) {
                            Text(L10n.string("Disabled")).tag(0)
                            Text(L10n.string("5 minutes")).tag(5)
                            Text(L10n.string("10 minutes")).tag(10)
                            Text(L10n.string("15 minutes")).tag(15)
                            Text(L10n.string("30 minutes")).tag(30)
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(width: 160)
                    }

                    settingsRow(icon: "text.bubble", title: "Show reflection prompt") {
                        Toggle("", isOn: $settings.enableSessionReflection)
                            .labelsHidden()
                    }
                }

                settingsSection(title: "Auto Break (Idle)", systemImage: "cup.and.saucer") {
                    settingsRow(icon: "clock.arrow.2.circlepath", title: "Start filling after") {
                        Picker("", selection: $settings.autoBreakIdleMinutes) {
                            Text(L10n.string("Disabled")).tag(0)
                            Text(L10n.string("1 minute")).tag(1)
                            Text(L10n.string("3 minutes")).tag(3)
                            Text(L10n.string("5 minutes")).tag(5)
                            Text(L10n.string("10 minutes")).tag(10)
                            Text(L10n.string("15 minutes")).tag(15)
                            Text(L10n.string("30 minutes")).tag(30)
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(width: 160)
                    }

                    settingsRow(icon: "hourglass", title: "Fill duration") {
                        Picker("", selection: $settings.autoBreakFillSeconds) {
                            Text(L10n.string("30 seconds")).tag(30)
                            Text(L10n.string("60 seconds")).tag(60)
                            Text(L10n.string("90 seconds")).tag(90)
                            Text(L10n.string("2 minutes")).tag(120)
                            Text(L10n.string("5 minutes")).tag(300)
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(width: 160)
                        .disabled(settings.autoBreakIdleMinutes == 0)
                    }
                }

                settingsSection(title: "App Behavior", systemImage: "gearshape") {
                    settingsRow(icon: "power", title: "Launch at login") {
                        Toggle("", isOn: $settings.launchAtLogin)
                            .labelsHidden()
                    }
                    settingsRow(icon: "sparkles", title: "Show orb on launch") {
                        Toggle("", isOn: $settings.showOrbOnLaunch)
                            .labelsHidden()
                    }
                }

                settingsSection(title: "Capture", systemImage: "tray.full") {
                    settingsRow(icon: "list.bullet.rectangle", title: "Show Top Task HUD") {
                        Toggle("", isOn: $settings.showTopTaskHUD)
                            .labelsHidden()
                    }
                    settingsRow(icon: "doc.on.clipboard", title: "Enable Clips") {
                        Toggle("", isOn: $settings.enableClips)
                            .labelsHidden()
                    }
                    settingsRow(icon: "pause.circle", title: "Pause Clips") {
                        Toggle("", isOn: $settings.pauseClips)
                            .labelsHidden()
                            .disabled(!settings.enableClips)
                    }
                    settingsRow(icon: "text.bubble", title: "Save mood to Notes") {
                        Toggle("", isOn: $settings.saveMoodToNotes)
                            .labelsHidden()
                    }
                }
            }
            .padding(20)
        }
        .frame(width: 520, height: 420)
        .background(Material.thin)
        .onAppear {
            syncLaunchAtLoginToggle()
            ClipboardMonitor.shared.syncWithSettings()
        }
        .onChange(of: settings.launchAtLogin) { _, newValue in
            guard !isSyncingLaunchAtLogin else { return }
            guard !LaunchAtLoginManager.shared.setEnabled(newValue) else { return }
            syncLaunchAtLoginToggle()
        }
        .onChange(of: settings.enableClips) { _, _ in
            ClipboardMonitor.shared.syncWithSettings()
        }
        .onChange(of: settings.pauseClips) { _, _ in
            ClipboardMonitor.shared.syncWithSettings()
        }
    }

    @ViewBuilder
    private func settingsSection<Content: View>(title: String, systemImage: String, @ViewBuilder content: () -> Content) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: systemImage)
                        .foregroundColor(AppTheme.Colors.warmOrange)
                    Text(L10n.string(title))
                        .font(AppTheme.Typography.title)
                }
                content()
            }
        }
    }

    @ViewBuilder
    private func settingsRow<Content: View>(icon: String, title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .frame(width: 18)
                .foregroundColor(AppTheme.Colors.textSecondary)
            Text(L10n.string(title))
                .font(AppTheme.Typography.body)
            Spacer()
            content()
        }
        .frame(minHeight: 32)
    }

    private func syncLaunchAtLoginToggle() {
        isSyncingLaunchAtLogin = true
        settings.launchAtLogin = LaunchAtLoginManager.shared.isEnabled
        isSyncingLaunchAtLogin = false
    }
}
