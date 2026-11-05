import Foundation

enum IntegrationsSettingsMetrics {
    static let height: CGFloat = 300
    static let hintSize: CGFloat = 11
    static let prefixWidth: CGFloat = 72
}

enum IntegrationsSettingsSymbol {
    static let tab = "link"
    static let remove = "minus.circle"
}

enum IntegrationsSettingsText {
    static let tab = "Integrações"
    static let jira = "Jira"
    static let jiraNote = "Chaves reconhecidas no título ou na branch do PR."
    static let prefix = "Prefixo"
    static let prefixPlaceholder = "ON"
    static let site = "Site"
    static let sitePlaceholder = "empresa.atlassian.net"
    static let noSite = "Sem site: a chave aparece na linha, mas não abre."
    static let addPrefix = "Adicionar prefixo"
    static let remove = "Remover"
}
