enum Provider: String, CaseIterable, Identifiable {
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

    /// Menu bar tag, by vendor: Anthropic, OpenAI, GitHub.
    var tag: String {
        switch self {
        case .claude: "A"
        case .codex: "O"
        case .copilot: "G"
        }
    }
}
