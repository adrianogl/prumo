import SwiftUI
import PRumoKit

enum RowMenuText {
    static let openInBrowser = "Abrir no navegador"
    static let copyLink = "Copiar link"
    static let pin = "Fixar no topo"
    static let unpin = "Desafixar"
    static let mute = "Silenciar este PR"
    static let unmute = "Reativar notificações"
    static let rerunFailedJobs = "Re-rodar job que falhou"
    static let rerunAlertTitle = "Não foi possível re-rodar o job"
    static let unauthorized = "Token inválido. Conecte de novo pelo popover."
    static let network = "Sem conexão com o GitHub."
    static let rateLimited = "Limite da API do GitHub. Tente de novo mais tarde."
    static let genericError = "O GitHub respondeu com erro."

    static func openJira(_ key: String) -> String {
        "Abrir card no Jira: \(key)"
    }

    static func rerunFailedJobs(_ jobName: String) -> String {
        jobName.isEmpty ? rerunFailedJobs : "\(rerunFailedJobs): \(jobName)"
    }

    static func copyCheckout(_ command: String) -> String {
        "Copiar \(command)"
    }

    static let gitlabMissingApiScope = "O token desta conta não tem o escopo api."

    static func rerunFailure(_ error: ProviderError, provider: ProviderKind, repository: String, runID: Int) -> String {
        switch error {
        case .server(status: 403) where provider == .gitlab:
            gitlabMissingApiScope
        case .server(status: 403):
            "O GitHub recusou: sem permissão para re-rodar jobs em \(repository) ou o run ainda está rodando."
        case .server(status: 404):
            "Run \(runID) não encontrado em \(repository)."
        case .server(let status):
            "O GitHub respondeu com erro (HTTP \(status))."
        case .unauthorized:
            unauthorized
        case .network:
            network
        case .rateLimited:
            rateLimited
        case .graphQL, .unexpectedResponse:
            genericError
        }
    }
}

enum RowMenuKey {
    static let openJira: Character = "j"
    static let copy: Character = "c"
}
