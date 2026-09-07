import SwiftUI

/// Adds an unsigned account; the sign-in row then appears in the popover.
struct AddAccountMenu: View {
    enum Style {
        /// Full-width bordered button, for the settings page and the empty popover.
        case prominent
        /// Plus icon, for the popover footer.
        case compact
    }

    let store: AccountStore
    var style: Style = .prominent

    var body: some View {
        switch style {
        case .prominent:
            Menu { providers } label: {
                Label("Add account", systemImage: "plus").frame(maxWidth: .infinity)
            }
            .menuStyle(.button)
            .frame(maxWidth: .infinity)
            .font(.callout)
        case .compact:
            Menu { providers } label: { Image(systemName: "plus") }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .help("Add account")
        }
    }

    private var providers: some View {
        ForEach(Provider.allCases) { provider in
            Button(provider.name) { store.add(provider: provider) }
        }
    }
}
