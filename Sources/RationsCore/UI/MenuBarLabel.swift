import SwiftUI

/// "A ▤ 12%/4%  O ▤ 77%/47%  G ▤ 18%": per signed-in account, its tag, a
/// mini bar per limit window and the percentages, short-term window first.
/// Which parts appear is a user setting.
struct MenuBarLabel: View {
    let store: AccountStore
    /// Called with the rendered width so the status item can follow it.
    let onWidthChange: (CGFloat) -> Void

    var body: some View {
        let active = store.monitors.filter(\.isSignedIn)
        HStack(spacing: 10) {
            if active.isEmpty {
                Text("Rations")
            } else {
                ForEach(active) { AccountGauge(monitor: $0) }
            }
        }
        .font(.system(size: 12).monospacedDigit())
        .padding(.horizontal, 7)
        .fixedSize()
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { onWidthChange($0) }
    }
}

private struct AccountGauge: View {
    let monitor: AccountMonitor
    @AppStorage(Settings.menuBarBars) private var showBars = true
    @AppStorage(Settings.menuBarPercent) private var showPercent = true
    @AppStorage(Settings.menuBarSession) private var showSession = true
    @AppStorage(Settings.menuBarWeekly) private var showWeekly = true

    var body: some View {
        let options = MenuBarOptions.resolve(
            for: monitor.account,
            global: MenuBarOptions(bars: showBars, percent: showPercent, session: showSession, weekly: showWeekly)
        )
        HStack(spacing: 4) {
            AccountLabel(account: monitor.account, height: 14)
            let windows = selectedWindows(options)
            if windows.isEmpty {
                Text("–")
            } else {
                if options.bars {
                    VStack(spacing: 2) {
                        ForEach(windows) { MiniBar(percent: $0.percentUsed) }
                    }
                }
                if options.percent {
                    Text(windows.map { Format.percent($0.percentUsed) }.joined(separator: "/"))
                }
            }
        }
    }

    /// The headline windows the user wants; a provider with a single window
    /// (Copilot) always shows it.
    private func selectedWindows(_ options: MenuBarOptions) -> [UsageWindow] {
        let headline = Array(monitor.snapshot?.headline ?? [])
        guard headline.count > 1 else { return headline }
        return headline.enumerated().filter { $0.offset == 0 ? options.session : options.weekly }.map(\.element)
    }
}

private struct MiniBar: View {
    let percent: Double

    var body: some View {
        ZStack(alignment: .leading) {
            Capsule().fill(.primary.opacity(0.25))
            Capsule().fill(Format.tint(percent)).frame(width: max(3, 14 * percent / 100))
        }
        .frame(width: 14, height: 3.5)
    }
}
