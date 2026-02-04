import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    
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

                settingsSection(title: "Session Settings", systemImage: "timer") {
                    settingsRow(icon: "rectangle.3.group", title: "Auto-merge sessions within") {
                        Picker("", selection: $settings.autoMergeWindowMinutes) {
                            Text("Disabled").tag(0)
                            Text("5 minutes").tag(5)
                            Text("10 minutes").tag(10)
                            Text("15 minutes").tag(15)
                            Text("30 minutes").tag(30)
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
                            Text("Disabled").tag(0)
                            Text("1 minute").tag(1)
                            Text("3 minutes").tag(3)
                            Text("5 minutes").tag(5)
                            Text("10 minutes").tag(10)
                            Text("15 minutes").tag(15)
                            Text("30 minutes").tag(30)
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(width: 160)
                    }

                    settingsRow(icon: "hourglass", title: "Fill duration") {
                        Picker("", selection: $settings.autoBreakFillSeconds) {
                            Text("30 seconds").tag(30)
                            Text("60 seconds").tag(60)
                            Text("90 seconds").tag(90)
                            Text("2 minutes").tag(120)
                            Text("5 minutes").tag(300)
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
            }
            .padding(20)
        }
        .frame(width: 520, height: 420)
        .background(Material.thin)
    }

    @ViewBuilder
    private func settingsSection<Content: View>(title: String, systemImage: String, @ViewBuilder content: () -> Content) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: systemImage)
                        .foregroundColor(AppTheme.Colors.warmOrange)
                    Text(title)
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
            Text(title)
                .font(AppTheme.Typography.body)
            Spacer()
            content()
        }
        .frame(minHeight: 32)
    }
}
