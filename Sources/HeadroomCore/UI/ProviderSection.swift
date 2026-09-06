import SwiftUI

struct ProviderSection: View {
    let monitor: ProviderMonitor
    let now: Date
    @State private var pastedCode = ""
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            if monitor.isSignedIn {
                usage
            } else {
                signIn
            }
            if case .error(let message) = monitor.status {
                Text(message).font(.caption).foregroundStyle(.red)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(monitor.provider.name).font(.headline)
            if let account = monitor.tokens?.account {
                Text(account).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            if monitor.isSignedIn {
                Button { monitor.refreshNow() } label: {
                    if monitor.status == .refreshing {
                        ProgressView().controlSize(.mini)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .buttonStyle(.borderless)
                .help("Refresh now")
                Button { monitor.signOut() } label: { Image(systemName: "rectangle.portrait.and.arrow.right") }
                    .buttonStyle(.borderless)
                    .help("Sign out")
            }
        }
    }

    @ViewBuilder
    private var usage: some View {
        if let snapshot = monitor.snapshot {
            ForEach(snapshot.windows) { window in
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(window.label)
                        Spacer()
                        Text("\(Format.percent(window.percentUsed)) used").monospacedDigit()
                    }
                    .font(.callout)
                    ProgressView(value: window.percentUsed, total: 100)
                        .tint(Format.tint(window.percentUsed))
                    let caption = [window.resetsAt.map { "Resets in \(Format.countdown(to: $0, from: now))" }, window.detail]
                        .compactMap { $0 }.joined(separator: " · ")
                    if !caption.isEmpty {
                        Text(caption).font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
            Text(schedule(snapshot)).font(.caption2).foregroundStyle(.tertiary)
        } else if monitor.status == .refreshing {
            Text("Loading…").font(.callout).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var signIn: some View {
        if let pending = monitor.pendingSignIn {
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
                waiting(label: "Waiting for the browser…")
            }
        } else {
            Button("Sign in to \(monitor.provider.name)") { monitor.signIn() }
        }
    }

    private func waiting(label: String) -> some View {
        HStack {
            ProgressView().controlSize(.small)
            Text(label).font(.callout).foregroundStyle(.secondary).textSelection(.enabled)
            Spacer()
            Button("Cancel") { monitor.cancelSignIn() }
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

    private func schedule(_ snapshot: UsageSnapshot) -> String {
        var parts = ["Updated \(Format.age(snapshot.fetchedAt, now: now))"]
        if let next = monitor.nextCheck, next > now {
            parts.append("next check in \(Format.countdown(to: next, from: now))")
        }
        return parts.joined(separator: " · ")
    }

}
