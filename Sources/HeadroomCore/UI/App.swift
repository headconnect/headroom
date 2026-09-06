import AppKit
import SwiftUI

public enum HeadroomApp {
    @MainActor public static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}

/// Status item with a SwiftUI label (MenuBarExtra only renders text and images,
/// not the usage bars) and a popover for the details.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let monitors = Provider.allCases.map { ProviderMonitor(provider: $0) }
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private let updates = UpdateChecker()

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let button = statusItem.button else { return }
        let label = PassthroughHostingView(rootView: MenuBarLabel(monitors: monitors) { [statusItem] width in
            statusItem.length = width
        })
        label.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            label.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            label.topAnchor.constraint(equalTo: button.topAnchor),
            label.bottomAnchor.constraint(equalTo: button.bottomAnchor),
        ])
        button.target = self
        button.action = #selector(togglePopover)

        let content = NSHostingController(rootView: PopoverView(monitors: monitors, updates: updates))
        content.sizingOptions = .preferredContentSize
        popover.contentViewController = content
        popover.behavior = .transient
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}

/// Lets clicks fall through to the status bar button underneath.
private final class PassthroughHostingView<Content: View>: NSHostingView<Content> {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
