public enum ClaudeDefaults {
    public static let reviewTemplate = "/code-review {numero}"
    public static let ciTemplate =
        "A CI do PR #{numero} ({repo}) falhou no job {job}. Leia o log com gh run view {run} --log-failed, encontre a causa e corrija."
    public static let extraFlags = ""
    public static let terminal = TerminalKind.ghostty
    public static let clonesRoot = "~/Code"
    public static let worktreesRoot = "~/Code/.prumo-worktrees"
    public static let removeWorktreeOnClose = true
}
