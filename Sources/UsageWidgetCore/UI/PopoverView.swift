import ServiceManagement
import SwiftUI

struct PopoverView: View {
    let monitors: [ProviderMonitor]
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        // Re-render every minute so countdowns stay current while open.
        TimelineView(.periodic(from: .now, by: 60)) { context in
            VStack(alignment: .leading, spacing: 14) {
                ForEach(monitors) { monitor in
                    ProviderSection(monitor: monitor, now: context.date)
                }
                Divider()
                HStack {
                    Toggle("Launch at login", isOn: $launchAtLogin)
                        .toggleStyle(.checkbox)
                        .onChange(of: launchAtLogin) { _, enabled in setLaunchAtLogin(enabled) }
                    Spacer()
                    Button("Quit") { NSApplication.shared.terminate(nil) }
                }
                .font(.callout)
            }
            .padding(14)
            .frame(width: 320)
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}
