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
    /// Pinned to the button's trailing edge, which stays put when the label
    /// changes width, so the popover does not move with it.
    private let anchor = PassthroughView()
    private var windowObservers: [NSObjectProtocol] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let button = statusItem.button else { return }
        let label = PassthroughHostingView(rootView: MenuBarLabel(monitors: monitors) { [statusItem] width in
            statusItem.length = width
        })
        label.translatesAutoresizingMaskIntoConstraints = false
        anchor.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(label)
        button.addSubview(anchor)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            label.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            label.topAnchor.constraint(equalTo: button.topAnchor),
            label.bottomAnchor.constraint(equalTo: button.bottomAnchor),
            anchor.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            anchor.topAnchor.constraint(equalTo: button.topAnchor),
            anchor.bottomAnchor.constraint(equalTo: button.bottomAnchor),
            anchor.widthAnchor.constraint(equalToConstant: 24),
        ])
        button.target = self
        button.action = #selector(togglePopover)

        let content = NSHostingController(rootView: PopoverView(monitors: monitors, updates: updates))
        content.sizingOptions = .preferredContentSize
        popover.contentViewController = content
        popover.behavior = .transient
    }

    @objc private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            observeStatusWindow()
            popover.show(relativeTo: anchor.bounds, of: anchor, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    /// The popover follows the status item's window when it is resized but not
    /// when the menu bar then shifts it to keep the right edge in place, so it
    /// is re-anchored after both.
    private func observeStatusWindow() {
        guard windowObservers.isEmpty, let window = statusItem.button?.window else { return }
        for name in [NSWindow.didMoveNotification, NSWindow.didResizeNotification] {
            windowObservers.append(NotificationCenter.default.addObserver(forName: name, object: window, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self, self.popover.isShown else { return }
                    self.popover.show(relativeTo: self.anchor.bounds, of: self.anchor, preferredEdge: .minY)
                }
            })
        }
    }
}

// Both let clicks fall through to the status bar button underneath.

private final class PassthroughHostingView<Content: View>: NSHostingView<Content> {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

private final class PassthroughView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
