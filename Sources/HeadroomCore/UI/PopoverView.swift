import SwiftUI

struct PopoverView: View {
    let store: AccountStore
    let updates: UpdateChecker
    let openSettings: () -> Void
    @State private var listHeight: CGFloat = 0
    @AppStorage(Settings.popoverOpacity) private var opacity = Settings.defaultPopoverOpacity

    var body: some View {
        // Re-render every minute so countdowns stay current while open.
        TimelineView(.periodic(from: .now, by: 60)) { context in
            VStack(alignment: .leading, spacing: 14) {
                // A popover taller than the screen is clipped, so past that it scrolls.
                ScrollView(showsIndicators: false) {
                    accounts(now: context.date)
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { listHeight = $0 }
                }
                .frame(height: min(listHeight, Self.maxListHeight))
                Divider()
                footer
            }
            .padding(14)
            .frame(width: 320)
        }
        // The popover's own material is translucent; this keeps the text readable.
        .background(Color(nsColor: .windowBackgroundColor).opacity(opacity))
    }

    /// Screen minus the menu bar, the footer and some breathing room.
    private static var maxListHeight: CGFloat {
        (NSScreen.main?.visibleFrame.height ?? 800) - 100
    }

    @ViewBuilder
    private func accounts(now: Date) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if store.monitors.isEmpty {
                Text("No accounts yet. Add one, then sign in.")
                    .font(.callout).foregroundStyle(.secondary)
                AddAccountMenu(store: store)
            } else {
                ForEach(store.monitors) { monitor in
                    AccountSection(monitor: monitor, store: store, now: now)
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            Button(action: openSettings) { Image(systemName: "gearshape") }
                .buttonStyle(.borderless)
                .help("Settings")
            AddAccountMenu(store: store, style: .compact)
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
}
