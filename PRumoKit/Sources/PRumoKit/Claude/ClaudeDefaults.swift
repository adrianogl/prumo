public enum ClaudeDefaults {
    public static let reviewTemplate = "/code-review {numero}"
    public static let ciTemplate =
        "A CI do PR #{numero} ({repo}) falhou no job {job}. Leia o log com gh run view {run} --log-failed, encontre a causa e corrija."
    public static let conflictTemplate =
        "O PR #{numero} ({repo}) está em conflito com {base}. Atualize a branch com git fetch origin {base} e git merge origin/{base}, resolva os conflitos mantendo a intenção das duas partes, rode os testes e faça commit do merge."
    public static let commentsTemplate =
        "O PR #{numero} ({repo}) recebeu comentários de review. Leia os comentários com gh pr view {numero} --comments e gh api repos/{repo}/pulls/{numero}/comments, aplique as alterações pedidas que fizerem sentido, rode os testes e faça commit. Não responda nem resolva as conversas no GitHub; me mostre um resumo do que mudou e do que você não aplicou."
    public static let command = "claude"
    public static let extraFlags = ""
    public static let terminal = TerminalKind.ghostty
    public static let clonesRoot = "~/Code"
    public static let worktreesRoot = "~/Code/.prumo-worktrees"
    public static let removeWorktreeOnClose = true
}
