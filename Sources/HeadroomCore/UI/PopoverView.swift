import ServiceManagement
import SwiftUI

struct PopoverView: View {
    let monitors: [ProviderMonitor]
    let updates: UpdateChecker
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var showSettings = false
    @AppStorage(Settings.popoverOpacity) private var opacity = Settings.defaultPopoverOpacity

    var body: some View {
        // Re-render every minute so countdowns stay current while open.
        TimelineView(.periodic(from: .now, by: 60)) { context in
            VStack(alignment: .leading, spacing: 14) {
                ForEach(monitors) { monitor in
                    ProviderSection(monitor: monitor, now: context.date)
                }
                Divider()
                if showSettings {
                    SettingsSection(launchAtLogin: $launchAtLogin, setLaunchAtLogin: setLaunchAtLogin)
                    Divider()
                }
                footer
            }
            .padding(14)
            .frame(width: 320)
        }
        // The popover's own material is translucent; this keeps the text readable.
        .background(Color(nsColor: .windowBackgroundColor).opacity(opacity))
    }

    private var footer: some View {
        HStack {
            Button { showSettings.toggle() } label: { Image(systemName: "gearshape") }
                .buttonStyle(.borderless)
                .help("Settings")
            if let release = updates.available {
                Link("v\(release.version) available", destination: release.url).font(.caption)
            }
            Spacer()
            if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                Text("v\(version)").font(.caption).foregroundStyle(.tertiary)
            }
            Button("Quit") { NSApplication.shared.terminate(nil) }
        }
        .font(.callout)
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}

private struct SettingsSection: View {
    @Binding var launchAtLogin: Bool
    let setLaunchAtLogin: (Bool) -> Void
    @AppStorage(Settings.menuBarBars) private var showBars = true
    @AppStorage(Settings.menuBarPercent) private var showPercent = true
    @AppStorage(Settings.menuBarSession) private var showSession = true
    @AppStorage(Settings.menuBarWeekly) private var showWeekly = true
    @AppStorage(Settings.popoverOpacity) private var opacity = Settings.defaultPopoverOpacity
    @AppStorage(Settings.checkForUpdates) private var checkForUpdates = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Menu bar").font(.caption).foregroundStyle(.secondary)
            // At least one of each pair stays on.
            HStack(spacing: 16) {
                Toggle("Bars", isOn: $showBars).disabled(!showPercent)
                Toggle("Percentages", isOn: $showPercent).disabled(!showBars)
            }
            HStack(spacing: 16) {
                Toggle("Session", isOn: $showSession).disabled(!showWeekly)
                Toggle("Weekly", isOn: $showWeekly).disabled(!showSession)
            }
            Text("General").font(.caption).foregroundStyle(.secondary).padding(.top, 4)
            HStack {
                Text("Popover opacity")
                Slider(value: $opacity, in: 0.5...1).controlSize(.small)
            }
            Toggle("Launch at login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, enabled in setLaunchAtLogin(enabled) }
            Toggle("Check for updates (polls GitHub every 6 hours)", isOn: $checkForUpdates)
        }
        .toggleStyle(.checkbox)
        .font(.callout)
    }
}
