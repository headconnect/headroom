import AppKit
import AuthenticationServices

/// Shows a provider's authorize page in a cookie-less browser window, so a
/// second account of the same provider is not silently signed in as the first.
///
/// The session is only a browser here: none of the flows redirect to a scheme we
/// own (Codex lands on the localhost callback server, Claude shows a code to
/// paste, Copilot polls the device code), so the callback scheme is one nobody
/// ever sends us and the completion handler has nothing to do. The caller
/// cancels the session when the sign-in ends.
@MainActor
final class PrivateSignInSession: NSObject, ASWebAuthenticationPresentationContextProviding {
    private var session: ASWebAuthenticationSession?
    /// This is an accessory app whose only window is a transient popover that
    /// closes as soon as the auth window takes focus, so we anchor to a private
    /// invisible window and keep it alive for the whole session.
    private lazy var anchor: NSWindow = {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1, height: 1),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.alphaValue = 0
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.isExcludedFromWindowsMenu = true
        return window
    }()

    func start(url: URL) {
        anchor.center()
        anchor.orderFrontRegardless()
        // Closing the window is left to the popover's Cancel button, exactly as
        // closing a browser tab is today.
        let session = ASWebAuthenticationSession(url: url, callbackURLScheme: "range-anxiety-private") { _, _ in }
        session.prefersEphemeralWebBrowserSession = true
        session.presentationContextProvider = self
        self.session = session
        // Accessory apps are not frontmost, so the window would otherwise open
        // behind whatever the user was looking at.
        NSApp.activate(ignoringOtherApps: true)
        session.start()
    }

    func cancel() {
        session?.cancel()
        session = nil
        anchor.orderOut(nil)
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor { anchor }
}
