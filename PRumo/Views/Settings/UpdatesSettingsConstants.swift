import Foundation

enum UpdatesSettingsMetrics {
    static let height: CGFloat = 440
    static let notesHeight: CGFloat = 140
    static let noteSize: CGFloat = 11
    static let rowSpacing: CGFloat = 8
}

enum UpdatesSettingsSymbol {
    static let tab = "arrow.down.circle"
    static let tabWithUpdate = "arrow.down.circle.fill"
    static let upToDate = "checkmark.circle"
    static let available = "arrow.down.circle.fill"
    static let failed = "exclamationmark.triangle"
}

enum UpdatesSettingsText {
    static let tab = "Atualizações"
    static let badge = "●"
    static let installedPrefix = "Versão instalada:"
    static let checking = "Verificando…"
    static let upToDate = "Você está na versão mais recente."
    static let availablePrefix = "Disponível: PRumo"
    static let failed = "Não foi possível verificar."
    static let checkNow = "Verificar agora"
    static let autoCheck = "Verificar automaticamente"
    static let autoCheckNote = "Ao abrir o app e a cada 24 h."
    static let lastCheckPrefix = "Última verificação:"
    static let install = "Instalar e reabrir"
    static let installing = "Instalando…"
    static let viewRelease = "Ver release"
    static let notInstallable = "Esta versão não tem instalador. Baixe pela página do release."
    static let installFailedTitle = "Não foi possível instalar"
    static let openRelease = "Abrir página do release"
    static let unknownVersion = "desconhecida"
    static let failureNotWritable = "O PRumo não tem permissão para substituir o app na pasta onde ele está."
    static let failureDownload = "Não foi possível baixar a versão nova."
    static let failureChecksum = "O arquivo baixado não confere. Nada foi instalado."
    static let failureMount = "Não foi possível abrir o DMG da versão nova."
    static let failureCopy = "Não foi possível copiar o app novo."
    static let failureReplace = "Não foi possível substituir o app atual."
    static let failureRelaunch = "A versão nova foi instalada, mas o PRumo não conseguiu reabrir. Abra o app de novo."
    static let failureNotInstallable = "Esta versão não tem instalador."
}
