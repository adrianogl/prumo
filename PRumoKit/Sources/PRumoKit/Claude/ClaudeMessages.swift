enum ClaudeMessages {
    static let gitTimedOut = "O git demorou demais para responder."
    static let forkNotice = " O PR vem de um fork; não faça push."
    static let shellTimedOut = "O shell demorou demais para responder ao procurar o claude."
    static let claudeNotFound = "Não encontrei o comando claude no PATH do seu shell."
    static let commandTimedOut = "O comando demorou demais para responder."

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
        let action = purpose == .resolveConflict ? dirtyConflictAction : dirtyCIAction
        return "A worktree \(path) tem alterações; finalize ou descarte antes de \(action)."
    }

    private static let dirtyCIAction = "corrigir a CI"
    private static let dirtyConflictAction = "resolver o conflito"
}
