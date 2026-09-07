import SwiftUI

/// Icon, tag, name, order, sign-in, optional per-account menu bar overrides and
/// removal for one account. Edits go straight to the store, which normalises and persists.
struct AccountSettingsRow: View {
    let monitor: AccountMonitor
    let store: AccountStore
    @State private var tag: String
    @State private var name: String
    @FocusState private var tagFocused: Bool

    init(monitor: AccountMonitor, store: AccountStore) {
        self.monitor = monitor
        self.store = store
        _tag = State(initialValue: monitor.account.tag)
        _name = State(initialValue: monitor.account.name)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                iconMenu
                // The placeholder shows the fallback used when the field is left empty.
                TextField(monitor.provider.tag, text: $tag)
                    .frame(width: 40)
                    .multilineTextAlignment(.center)
                    .focused($tagFocused)
                    // Grapheme clusters, so one emoji is one tag character.
                    .onChange(of: tag) { _, new in
                        tag = String(new.prefix(3))
                        commit()
                    }
                    // The store falls back to the provider letter on empty.
                    .onChange(of: tagFocused) { _, focused in if !focused { tag = monitor.account.tag } }
                    .help("Menu bar tag, up to 3 characters (emoji count as one)")
                Text(monitor.provider.name).frame(width: 52, alignment: .leading)
                TextField("Name (optional)", text: $name)
                    .onChange(of: name) { _, _ in commit() }
                orderButtons
                Button(role: .destructive) { store.remove(id: monitor.id) } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("Remove \(monitor.provider.name) and forget its tokens from the keychain")
            }
            .textFieldStyle(.roundedBorder)
            HStack {
                Toggle("Customise menu bar", isOn: customised)
                Spacer()
                if monitor.isSignedIn {
                    Text("Configured").font(.caption).foregroundStyle(.green)
                } else if monitor.pendingSignIn == nil {
                    SignInButton(monitor: monitor, store: store)
                }
            }
            if let pending = monitor.pendingSignIn {
                SignInPending(monitor: monitor, pending: pending)
            }
            if case .error(let message) = monitor.status {
                Text(message).font(.caption).foregroundStyle(.red)
            }
            if monitor.account.menuBar != nil {
                MenuBarOptionToggles(
                    bars: option(\.bars), percent: option(\.percent),
                    session: option(\.session), weekly: option(\.weekly)
                )
                .padding(.leading, 20)
            }
        }
        .font(.callout)
    }

    /// An image in place of the tag; the tag stays as the fallback and for
    /// the settings row itself.
    private var iconMenu: some View {
        Menu {
            Button(monitor.account.icon == nil ? "Choose image…" : "Change image…") {
                if let data = AccountIcon.pick() { setIcon(data) }
            }
            if monitor.account.icon != nil {
                Button("Remove image") { setIcon(nil) }
            }
        } label: {
            if monitor.account.icon != nil {
                AccountLabel(account: monitor.account)
            } else {
                Image(systemName: "photo")
            }
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Menu bar icon, shown instead of the tag")
    }

    private var orderButtons: some View {
        let index = store.monitors.firstIndex { $0.id == monitor.id } ?? 0
        return VStack(spacing: 0) {
            Button { store.move(id: monitor.id, by: -1) } label: { Image(systemName: "chevron.up") }
                .disabled(index == 0)
            Button { store.move(id: monitor.id, by: 1) } label: { Image(systemName: "chevron.down") }
                .disabled(index == store.monitors.count - 1)
        }
        .buttonStyle(.borderless)
        .controlSize(.mini)
        .help("Move up or down")
    }

    private var resolved: MenuBarOptions { monitor.account.menuBar ?? MenuBarOptions.global() }

    /// Turning the override on freezes today's globals; off follows them again.
    private var customised: Binding<Bool> {
        Binding(
            get: { monitor.account.menuBar != nil },
            set: { on in
                var account = monitor.account
                account.menuBar = on ? MenuBarOptions.global() : nil
                store.update(account)
            }
        )
    }

    private func option(_ keyPath: WritableKeyPath<MenuBarOptions, Bool>) -> Binding<Bool> {
        Binding(
            get: { resolved[keyPath: keyPath] },
            set: { value in
                var account = monitor.account
                var options = resolved
                options[keyPath: keyPath] = value
                account.menuBar = options
                store.update(account)
            }
        )
    }

    private func setIcon(_ data: Data?) {
        var account = monitor.account
        account.icon = data
        store.update(account)
    }

    private func commit() {
        var account = monitor.account
        account.tag = tag
        account.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        store.update(account)
    }
}
