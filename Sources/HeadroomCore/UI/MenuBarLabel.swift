import SwiftUI

/// "A ▤ 12%/4% · O ▤ 77%/47% · G ▤ 18%": per signed-in provider, its tag, a
/// mini bar per limit window and the percentages, short-term window first.
struct MenuBarLabel: View {
    let monitors: [ProviderMonitor]
    /// Called with the rendered width so the status item can follow it.
    let onWidthChange: (CGFloat) -> Void

    var body: some View {
        let active = monitors.filter(\.isSignedIn)
        HStack(spacing: 10) {
            if active.isEmpty {
                Text("Usage")
            } else {
                ForEach(active) { ProviderGauge(monitor: $0) }
            }
        }
        .font(.system(size: 12).monospacedDigit())
        .padding(.horizontal, 7)
        .fixedSize()
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { onWidthChange($0) }
    }
}

private struct ProviderGauge: View {
    let monitor: ProviderMonitor

    var body: some View {
        HStack(spacing: 4) {
            Text(monitor.provider.tag).fontWeight(.semibold)
            if let windows = monitor.snapshot?.headline, !windows.isEmpty {
                VStack(spacing: 2) {
                    ForEach(windows) { MiniBar(percent: $0.percentUsed) }
                }
                Text(windows.map { Format.percent($0.percentUsed) }.joined(separator: "/"))
            } else {
                Text("–")
            }
        }
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
