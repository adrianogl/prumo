import Foundation
import PRumoKit

enum AccountsSettingsMetrics {
    static let height: CGFloat = 320
    static let rowSpacing: CGFloat = 10
    static let nameSpacing: CGFloat = 2
    static let providerIconSize: CGFloat = 18
    static let detailSize: CGFloat = 11
    static let stateSize: CGFloat = 11
    static let stateDotSize: CGFloat = 7
    static let stateSpacing: CGFloat = 5
    static let sheetWidth: CGFloat = 420
    static let sheetPadding: CGFloat = 18
    static let sheetSpacing: CGFloat = 12
    static let fieldSpacing: CGFloat = 4
    static let fieldLabelSize: CGFloat = 11
    static let detectedSpacing: CGFloat = 9
    static let detectedPadding: CGFloat = 10
    static let detectedCornerRadius: CGFloat = 8
    static let detectedTextSize: CGFloat = 12
    static let errorSize: CGFloat = 12
    static let buttonSpacing: CGFloat = 8
}

enum AccountsSettingsSymbol {
    static let tab = "person.2"
    static let more = "ellipsis"

    static func provider(_ kind: ProviderKind) -> String {
        switch kind {
        case .github: "chevron.left.forwardslash.chevron.right"
        }
    }
}

enum AccountsSettingsText {
    static let tab = "Contas"
    static let section = "Contas"
    static let add = "Adicionar conta…"
    static let originGh = "token do GitHub CLI"
    static let originPasted = "token pessoal no Keychain"
    static let connected = "conectada"
    static let connecting = "conectando…"
    static let offline = "sem acesso"
    static let offlinePrivateHost = "sem acesso (VPN?)"
    static let unauthorized = "token inválido"
    static let rateLimited = "limite da API"
    static let unexpectedResponse = "resposta inesperada"
    static let retry = "Tentar de novo"
    static let reconnect = "Reconectar"
    static let rename = "Renomear…"
    static let renameTitle = "Renomear conta"
    static let nickname = "Apelido"
    static let save = "Salvar"
    static let remove = "Remover…"
    static let removeConfirm = "Remover"
    static let removeMessage = "Os PRs dessa conta saem da lista e o token é apagado do Keychain."
    static let cancel = "Cancelar"
    static let sheetTitle = "Adicionar conta"
    static let use = "Usar"
    static let orPastedToken = "ou com um token pessoal:"
    static let tokenField = "Token pessoal (escopos repo e read:org)"
    static let createToken = "Criar token no GitHub"
    static let connect = "Conectar"
    static let duplicate = "Essa conta já está na lista."
    static let invalidToken = "Token inválido ou sem os escopos repo e read:org."
    static let noConnection = "Sem conexão com o GitHub."
    static let unavailable = "O GitHub não respondeu. Tente de novo em instantes."
    static let ghTokenMissing = "Não deu para ler o token do gh."
    static let keychainFailure = "Não deu para guardar o token no Keychain."

    static func detail(host: String, origin: TokenOrigin) -> String {
        "\(host) · \(origin == .ghCLI ? originGh : originPasted)"
    }

    static func rateLimitedUntil(_ time: String) -> String { "limite da API até \(time)" }
    static func removeTitle(_ name: String) -> String { "Remover \(name)?" }
    static func reconnectTitle(_ name: String) -> String { "Reconectar \(name)" }
    static func foundInGh(login: String, host: String) -> String { "Encontrei no gh: @\(login) em \(host)" }
    static func otherLogin(_ found: String, expected: String) -> String { "Esse token é de @\(found), não de @\(expected)." }
}

enum AddAccountMode: Identifiable {
    case add
    case reconnect(Account)

    var id: String {
        switch self {
        case .add: ""
        case .reconnect(let account): account.id
        }
    }

    var account: Account? {
        switch self {
        case .add: nil
        case .reconnect(let account): account
        }
    }
}
