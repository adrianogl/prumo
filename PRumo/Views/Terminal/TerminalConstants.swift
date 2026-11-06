import SwiftUI
import PRumoKit

enum TerminalText {
    static let closeTitle = "Encerrar a sessão do Claude?"
    static let closeMessage = "O processo ainda está rodando. Fechar a aba encerra a sessão."
    static let closeConfirm = "Encerrar"
    static let cancel = "Cancelar"
    static let replaceTitle = "Já existe uma sessão do Claude neste PR"
    static let replaceConfirm = "Encerrar e abrir a nova"
    static let quitTitle = "Há sessões do Claude rodando"
    static let quitMessage = "Encerrar o PRumo fecha todas as sessões abertas no terminal."
    static let quitConfirm = "Encerrar o PRumo"
    static let closeTab = "Fechar aba"
    static let togglePanel = "Mostrar ou recolher o terminal (⌘J)"
    static let nextSession = "Próxima sessão (⌃Tab)"
    static let running = "rodando"
    static let attention = "esperando resposta"

    static func exited(_ code: Int32) -> String { "encerrada (código \(code))" }

    static func exitedBanner(_ code: Int32) -> String {
        "\r\n\u{1B}[2m[sessão encerrada (código \(code))]\u{1B}[0m\r\n"
    }

    static func replaceMessage(current: String) -> String {
        "A sessão atual (\(current)) ainda está rodando. Abrir outra encerra a atual."
    }

    static func tabTitle(_ info: TerminalSessionInfo) -> String {
        "\(info.reference) · \(info.purpose.badgeTitle)"
    }
}

enum TerminalMetrics {
    static let fontSize: CGFloat = 12
    static let termName = "xterm-256color"
    static let signalExitCode: Int32 = 128
    static let panelMinHeight: CGFloat = 180
    static let panelIdealHeight: CGFloat = 300
    static let detailMinHeight: CGFloat = 200
    static let tabBarHeight: CGFloat = 30
    static let tabDotSize: CGFloat = 6
    static let tabSpacing: CGFloat = 2
}

enum TerminalSymbol {
    static let close = "xmark"
    static let collapse = "chevron.down"
    static let expand = "chevron.up"
    static let indicator = "apple.terminal"
}

enum TerminalKey {
    static let togglePanel: KeyEquivalent = "j"
    static let nextSession: KeyEquivalent = .tab
}

extension TerminalSessionStatus {
    var color: Color {
        switch self {
        case .running: Color.statusOK
        case .attention: Color.statusAttention
        case .exited: Color.statusIdle
        }
    }

    var label: String {
        switch self {
        case .running: TerminalText.running
        case .attention: TerminalText.attention
        case .exited(let code): TerminalText.exited(code)
        }
    }
}
