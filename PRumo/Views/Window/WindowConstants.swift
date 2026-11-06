import SwiftUI

enum MainWindowText {
    static let id = "main"
    static let title = "PRumo"
    static let open = "Abrir janela"
    static let openHelp = "Abrir janela (⌘O)"
    static let tabs = "Listas"
    static let views = "Visões"
    static let repositories = "Repositórios"
    static let sessions = "Sessões do Claude"
    static let allRepositories = "Todos"
    static let noSelection = "Nenhum PR selecionado"
    static let noSelectionHint = "Escolha um PR na lista para ver checks, reviews e atividade."
    static let searchPrompt = "Título, repositório ou número"
    static let updatedAgoPrefix = "atualizado"
}

enum MainWindowMetrics {
    static let minWidth: CGFloat = 900
    static let minHeight: CGFloat = 560
    static let defaultWidth: CGFloat = 1160
    static let defaultHeight: CGFloat = 720
    static let sidebarMinWidth: CGFloat = 180
    static let sidebarIdealWidth: CGFloat = 240
    static let listMinWidth: CGFloat = 280
    static let listIdealWidth: CGFloat = 330
    static let detailMinWidth: CGFloat = 420
    static let rowDotSize: CGFloat = 8
    static let rowSpacing: CGFloat = 9
    static let rowVerticalPadding: CGFloat = 6
    static let titleFontSize: CGFloat = 13
    static let subtitleFontSize: CGFloat = 11
    static let sessionDotSize: CGFloat = 7
    static let sidebarTopInset: CGFloat = 6
    static let listTitleSize: CGFloat = 22
    static let wordmarkSize: CGFloat = 17
}

enum MainWindowSymbol {
    static let open = "sidebar.left"
    static let mine = "person"
    static let review = "eye"
    static let merge = "arrow.triangle.merge"
    static let view = "line.3.horizontal.decrease.circle"
    static let repository = "folder"
    static let terminal = "apple.terminal"
}

enum MainWindowKey {
    static let open: KeyEquivalent = "o"
    static let search: KeyEquivalent = "f"
    static let refresh: KeyEquivalent = "r"
    static let mine: KeyEquivalent = "1"
    static let review: KeyEquivalent = "2"
    static let merge: KeyEquivalent = "3"
}
