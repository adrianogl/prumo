import Foundation

enum ClaudeSettingsMetrics {
    static let height: CGFloat = 640
    static let hintSize: CGFloat = 11
    static let templateLines = 2...4
}

enum ClaudeSettingsText {
    static let tab = "IA"
    static let provider = "Provedor"
    static let reviewTemplate = "Revisar PR"
    static let reviewVariables = "Variáveis: {numero} {url} {repo} {branch} {titulo}"
    static let ciTemplate = "Corrigir CI"
    static let ciVariables = "Variáveis: as de cima + {job} {run}"
    static let conflictTemplate = "Resolver conflito"
    static let conflictVariables = "Variáveis: {numero} {url} {repo} {branch} {base} {titulo}"
    static let commentsTemplate = "Resolver comentários"
    static let commentsVariables = "Variáveis: {numero} {url} {repo} {branch} {titulo}"
    static let gitlabReviewTemplate = "Revisar MR"
    static let gitlabCiTemplate = "Corrigir pipeline"
    static let gitlabCiVariables = "Variáveis: as de cima + {job} {run} {jobid}"
    static let command = "Comando do claude"
    static let commandPlaceholder = "claude"
    static let commandHint = "Nome da função, alias ou caminho, como claude-ems. Roda no seu zsh."
    static let commandInvalid = "Use só o nome ou o caminho, sem espaços nem opções. As flags vão no campo abaixo."
    static let flags = "Flags do claude"
    static let flagsPlaceholder = "--model opus"
    static let terminal = "Terminal"
    static let ghostty = "Ghostty"
    static let terminalApp = "Terminal"
    static let iterm = "iTerm"
    static let custom = "Personalizado"
    static let embedded = "Dentro do PRumo"
    static let customTemplate = "Template do terminal"
    static let customHint = "Use {dir} e {cmd}. Não coloque {cmd} entre aspas."
    static let clonesRoot = "Pasta dos clones"
    static let worktreesRoot = "Pasta das worktrees"
    static let choose = "Escolher…"
    static let chooseFolderPrompt = "Escolher"
    static let clones = "Clones"
    static let clonesSummary = "%ld em %@ · %ld nos seus PRs"
    static let scanningClones = "Procurando clones…"
    static let manageClones = "Gerenciar…"
    static let noClones = "Nenhum clone encontrado"
    static let removeWorktree = "Apagar worktree quando o PR fechar"
}
