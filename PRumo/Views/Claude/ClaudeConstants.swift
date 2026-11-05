import CoreGraphics

enum ClaudeMetrics {
    static let markSize: CGFloat = 11
    static let menuButtonSize: CGFloat = 22
    static let spinnerScale: CGFloat = 0.5
    static let menuIconSize: CGFloat = 14
}

enum ClaudeSymbol {
    static let mark = "AIMark"
    static let tab = "sparkles"
    static let more = "ellipsis"
}

enum ClaudeText {
    static func wrongClone(_ repository: String) -> String {
        "A pasta escolhida não é um clone de \(repository)."
    }

    static let review = "Revisar com Claude"
    static let fixCI = "Corrigir CI com Claude"
    static let fixBadge = "corrigir"
    static let resolveConflict = "Resolver conflito com Claude"
    static let resolveBadge = "resolver"
    static let addressComments = "Resolver comentários com Claude"
    static let moreActions = "Mais ações"
    static let shortcutKey = "k"
    static let alertTitle = "Não foi possível abrir o Claude"
    static let alertOK = "OK"
    static let customTerminalEmpty = "Configure o comando do terminal personalizado em Ajustes › IA."
    static let chooseClonePrompt = "Usar esta pasta"
    static let worktreePrefix = "Não consegui preparar a worktree: "

    static func cloneQuestion(_ repository: String) -> String {
        "Onde está o clone de \(repository)?"
    }
}
