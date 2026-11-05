import Foundation

enum SettingsMetrics {
    static let aboutLogoSize: CGFloat = 64
    static let width: CGFloat = 600
    static let aboutHeight: CGFloat = 280
    static let generalHeight: CGFloat = 380
    static let hotKeyButtonWidth: CGFloat = 110
    static let hotKeyRecorderSpacing: CGFloat = 4
    static let hotKeyFontSize: CGFloat = 12
}

enum SettingsSymbol {
    static let general = "gearshape"
    static let about = "info.circle"
}

enum SettingsText {
    static let general = "Geral"
    static let about = "Sobre"
    static let interval = "Atualizar a cada"
    static let stuckCIThreshold = "Considerar CI parado após"
    static let launchAtLogin = "Abrir ao iniciar o macOS"
    static let rowStyle = "Linha do PR"
    static let rowStyleDetailed = "Detalhada"
    static let rowStyleCompact = "Compacta"
    static let version = "Versão"
    static let iconCredit = "Símbolo pull-request do IBM Carbon, licença Apache 2.0"
    static let license = "Ver licença"
    static let hotKey = "Atalho global"
    static let hotKeyRecording = "Digite o atalho…"
    static let hotKeyRestore = "Restaurar padrão"
    static let hotKeyNeedsModifier = "Use ⌘, ⌥ ou ⌃ no atalho."
    static let hotKeyInUse = "Esse atalho já está em uso."
}

enum SettingsTab: Hashable {
    case accounts
    case general
    case notifications
    case comments
    case filters
    case claude
    case integrations
    case about
}
