enum ClaudeMessages {
    static let gitTimedOut = "O git demorou demais para responder."
    static let forkNotice = " O PR vem de um fork; não faça push."
    static let shellTimedOut = "O shell demorou demais para responder ao procurar o claude."
    static let commandTimedOut = "O comando demorou demais para responder."

    static func claudeNotFound(_ command: String) -> String {
        "Não encontrei o comando \(command) no seu shell. Confira o nome em Ajustes › IA."
    }

    static func invalidBranch(_ branch: String) -> String {
        "Nome de branch inválido: \(branch)"
    }

    static func unsafeCachePath(_ path: String) -> String {
        "O caminho de cache do PRumo tem espaço ou acento (\(path)); o PRumo não consegue abrir o terminal com segurança nesse caso."
    }

    static func terminalExit(_ status: Int32) -> String {
        "O terminal não abriu (código \(status))."
    }

    static func dirtyWorktree(_ path: String, purpose: SessionPurpose) -> String {
        let action: String
        switch purpose {
        case .review: action = dirtyReviewAction
        case .fixCI: action = dirtyCIAction
        case .resolveConflict: action = dirtyConflictAction
        case .addressComments: action = dirtyCommentsAction
        }
        return "A worktree \(path) tem alterações; finalize ou descarte antes de \(action)."
    }

    private static let dirtyReviewAction = "revisar o PR"
    private static let dirtyCIAction = "corrigir a CI"
    private static let dirtyConflictAction = "resolver o conflito"
    private static let dirtyCommentsAction = "resolver os comentários"
}
