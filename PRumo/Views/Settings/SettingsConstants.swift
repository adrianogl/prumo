import Foundation

enum SettingsMetrics {
    static let aboutLogoSize: CGFloat = 64
    static let width: CGFloat = 420
    static let height: CGFloat = 220
    static let aboutHeight: CGFloat = 280
}

enum SettingsSymbol {
    static let account = "person.crop.circle"
    static let general = "gearshape"
    static let about = "info.circle"
}

enum SettingsText {
    static let account = "Conta"
    static let general = "Geral"
    static let about = "Sobre"
    static let login = "Conectado como"
    static let notConnected = "Não conectado"
    static let origin = "Origem do token"
    static let originGh = "GitHub CLI"
    static let originPasted = "Token no Keychain"
    static let disconnect = "Desconectar"
    static let interval = "Atualizar a cada"
    static let launchAtLogin = "Abrir ao iniciar o macOS"
    static let version = "Versão"
    static let iconCredit = "Símbolo pull-request do IBM Carbon, licença Apache 2.0"
    static let license = "Ver licença"
}

enum SettingsTab: Hashable {
    case account
    case general
    case claude
    case about
}
