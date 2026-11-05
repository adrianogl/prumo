import Foundation

enum ClaudeSettingsMetrics {
    static let height: CGFloat = 640
    static let hintSize: CGFloat = 11
    static let templateLines = 2...4
}

enum ClaudeSettingsText {
    static let tab = "Claude"
    static let reviewTemplate = "Revisar PR"
    static let reviewVariables = "Variáveis: {numero} {url} {repo} {branch} {titulo}"
    static let ciTemplate = "Corrigir CI"
    static let ciVariables = "Variáveis: as de cima + {job} {run}"
    static let conflictTemplate = "Resolver conflito"
    static let conflictVariables = "Variáveis: {numero} {url} {repo} {branch} {base} {titulo}"
    static let commentsTemplate = "Resolver comentários"
    static let commentsVariables = "Variáveis: {numero} {url} {repo} {branch} {titulo}"
    static let flags = "Flags do claude"
    static let flagsPlaceholder = "--model opus"
    static let terminal = "Terminal"
    static let ghostty = "Ghostty"
    static let terminalApp = "Terminal"
    static let iterm = "iTerm"
    static let custom = "Personalizado"
    static let customTemplate = "Template do terminal"
    static let customHint = "Use {dir} e {cmd}. Não coloque {cmd} entre aspas."
    static let clonesRoot = "Pasta dos clones"
    static let worktreesRoot = "Pasta das worktrees"
    static let choose = "Escolher…"
    static let chooseFolderPrompt = "Escolher"
    static let clonesHeader = "Clones encontrados"
    static let clonesHint = "Busca automática em %@ pelo remote do repositório"
    static let scanning = "Buscando…"
    static let rescan = "Buscar de novo"
    static let addManually = "+ Adicionar manualmente"
    static let changePath = "Trocar…"
    static let noClones = "Nenhum clone encontrado"
    static let notGitHubRepository = "Essa pasta não é um clone de um repositório do GitHub"
    static let removeWorktree = "Apagar worktree quando o PR fechar"
    static let arrow = "→"
}
