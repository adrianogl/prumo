import SwiftUI

enum OnboardingMetrics {
    static let width: CGFloat = 400
    static let iconSize: CGFloat = 96
}

enum OnboardingSymbol {
    static let found = "checkmark.circle.fill"
    static let notifications = "bell.badge"
}

enum OnboardingText {
    static let windowTitle = "Bem-vindo ao PRumo"
    static let id = PopoverText.onboardingWindowID
    static let tagline = "Seus PRs e reviews na barra de menu."
    static func foundGh(_ login: String) -> String { "Encontrei o GitHub CLI logado como @\(login)" }
    static let useThisAccount = "Usar esta conta"
    static let useOtherToken = "Usar outro token"
    static let useToken = "Usar um token"
    static let checking = "Procurando o GitHub CLI…"
    static let tokenPrompt = "Cole um Personal Access Token"
    static let tokenPlaceholder = "ghp_…"
    static let scopes = "Escopos: repo, read:org. Fica guardado no Keychain."
    static let createToken = "Criar token no GitHub ↗"
    static let back = "Voltar"
    static let connect = "Conectar"
    static let invalidToken = "Token inválido ou sem os escopos necessários."
    static let offline = "Não consegui falar com o GitHub. Confira a conexão e tente de novo."
    static let unexpectedResponse = "O GitHub mandou uma resposta que o PRumo não entendeu. Tente de novo em instantes."
    static let unavailable = "O GitHub não respondeu. Tente de novo em instantes."
    static let keychainFailure = "Não consegui guardar o token no Keychain."
    static let notificationsTitle = "Notificações"
    static let notificationsBody = "O PRumo avisa quando um PR recebe review, comentário ou muda o resultado do CI."
    static let allowNotifications = "Permitir notificações"
    static let skip = "Agora não"
    static let readyTitle = "Tudo pronto"
    static let launchAtLogin = "Abrir ao iniciar o macOS"
    static let ignoreDrafts = "Ignorar drafts em Revisar"
    static let readyNote = "O PRumo fica no canto da barra de menu. Na primeira leitura não dispara notificação pelo que já existe; só pelo que mudar depois."
    static let otherAccounts = "Para acompanhar outras contas, use Ajustes › Contas."
    static let start = "Começar"
}
