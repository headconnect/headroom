enum Provider: String, CaseIterable, Codable, Identifiable {
    case claude
    case codex
    case copilot

    var id: String { rawValue }

    var name: String {
        switch self {
        case .claude: "Claude"
        case .codex: "Codex"
        case .copilot: "Copilot"
        }
    }

    /// Default menu bar tag, by vendor: Anthropic, OpenAI, GitHub. Accounts
    /// start from this and the user can edit it.
    var tag: String {
        switch self {
        case .claude: "A"
        case .codex: "O"
        case .copilot: "G"
        }
    }
}
