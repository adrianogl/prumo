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
    static let cancelAndRerun = "Cancelar e rodar o CI de novo"
    static let cancelAndRerunAlertTitle = "Não foi possível rodar o CI de novo"
    static let unauthorized = "Token inválido. Conecte de novo pelo popover."
    static let network = "Sem conexão com o GitHub."
    static let rateLimited = "Limite da API do GitHub. Tente de novo mais tarde."
    static let genericError = "O GitHub respondeu com erro."
    static let gitlabNetwork = "Sem conexão com o GitLab."
    static let gitlabRateLimited = "Limite da API do GitLab. Tente de novo mais tarde."
    static let gitlabGenericError = "O GitLab respondeu com erro."

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
            provider == .gitlab ? "O GitLab respondeu com erro (HTTP \(status))." : "O GitHub respondeu com erro (HTTP \(status))."
        case .unauthorized:
            unauthorized
        case .network:
            provider == .gitlab ? gitlabNetwork : network
        case .rateLimited:
            provider == .gitlab ? gitlabRateLimited : rateLimited
        case .graphQL(let messages) where provider == .gitlab:
            messages.isEmpty ? gitlabGenericError : messages.joined(separator: " ")
        case .graphQL, .unexpectedResponse, .cancelTimedOut:
            provider == .gitlab ? gitlabGenericError : genericError
        }
    }

    static func cancelAndRerunFailure(_ error: ProviderError, provider: ProviderKind, repository: String) -> String {
        switch error {
        case .cancelTimedOut(let runID):
            "O run \(runID) não terminou de cancelar em 30 s. Tente de novo em instantes."
        case .server(status: 403) where provider == .github:
            "O GitHub recusou: sem permissão para cancelar ou rodar de novo o CI em \(repository)."
        case .server(status: 404):
            provider == .gitlab ? "Pipeline não encontrado em \(repository)." : "Run não encontrado em \(repository)."
        default:
            rerunFailure(error, provider: provider, repository: repository, runID: 0)
        }
    }
}

enum RowMenuKey {
    static let openJira: Character = "j"
    static let copy: Character = "c"
}
