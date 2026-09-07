import SwiftUI

/// The sign-in split button; shared by the popover section and the settings row.
struct SignInButton: View {
    let monitor: AccountMonitor
    /// Only for the store-wide sign-in guard: one browser flow at a time.
    let store: AccountStore

    var body: some View {
        // Codex binds a fixed localhost port, so sign-ins are serialised.
        Menu("Sign in to \(monitor.provider.name)") {
            Button("Sign in privately") { monitor.signIn(privately: true) }
        } primaryAction: {
            monitor.signIn()
        }
        .menuStyle(.button)
        .fixedSize()
        .disabled(store.isSigningIn)
        .help("Private sign-in opens a window without shared cookies, so a second account is not signed in as the first.")
    }
}

/// What a sign-in in progress asks of the user: paste a code, type a code, or
/// wait for the browser. Shown wherever the button was.
struct SignInPending: View {
    let monitor: AccountMonitor
    let pending: PendingSignIn
    @State private var pastedCode = ""
    @State private var copied = false

    var body: some View {
        switch pending.mode {
        case .pastedCode:
            Text("Authorize in the browser. The page then shows a code and says to paste it into Claude Code; paste it here instead:")
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                TextField("Code from the browser", text: $pastedCode)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(submitCode)
                Button("Continue", action: submitCode).disabled(pastedCode.isEmpty)
                Button("Cancel") { monitor.cancelSignIn() }
            }
            .font(.callout)
        case .deviceCode(let code):
            Text("Enter this code on the GitHub page that opened:")
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                ProgressView().controlSize(.small)
                Text(code).font(.system(.title3, design: .monospaced)).textSelection(.enabled)
                Button { copy(code) } label: { Image(systemName: copied ? "checkmark" : "doc.on.doc") }
                    .buttonStyle(.borderless)
                    .help("Copy code")
                Spacer()
                Button("Cancel") { monitor.cancelSignIn() }
            }
            .font(.callout)
        case .callback:
            HStack {
                ProgressView().controlSize(.small)
                Text("Waiting for the browser…").font(.callout).foregroundStyle(.secondary)
                Spacer()
                Button("Cancel") { monitor.cancelSignIn() }
            }
        }
    }

    private func copy(_ code: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(code, forType: .string)
        copied = true
        Task { try? await Task.sleep(for: .seconds(2)); copied = false }
    }

    private func submitCode() {
        monitor.submitPastedCode(pastedCode)
        pastedCode = ""
    }
}
