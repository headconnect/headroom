import SwiftUI

public struct UsageWidgetApp: App {
    @State private var monitors = Provider.allCases.map { ProviderMonitor(provider: $0) }

    public init() {}

    public var body: some Scene {
        MenuBarExtra {
            PopoverView(monitors: monitors)
        } label: {
            Text(MenuBarTitle.text(for: monitors))
        }
        .menuBarExtraStyle(.window)
    }
}

enum MenuBarTitle {
    /// "A 12% · O 77% · G 18%": peak utilisation per signed-in provider.
    @MainActor
    static func text(for monitors: [ProviderMonitor]) -> String {
        let parts = monitors.filter(\.isSignedIn).map { monitor in
            let percent = monitor.snapshot?.peakPercent.map { "\(Int($0.rounded()))%" } ?? "–"
            return "\(monitor.provider.tag) \(percent)"
        }
        return parts.isEmpty ? "Usage" : parts.joined(separator: " · ")
    }
}
