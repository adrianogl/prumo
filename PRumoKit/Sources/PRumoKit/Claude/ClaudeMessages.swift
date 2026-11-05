enum ClaudeMessages {
    static let gitTimedOut = "O git demorou demais para responder."

    static func invalidBranch(_ branch: String) -> String {
        "Nome de branch inválido: \(branch)"
    }
}
