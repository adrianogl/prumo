import SwiftUI

enum WidgetText {
    static let kind = "PRumoWidget"
    static let displayName = "PRumo"
    static let description = "Reviews pendentes, CI falhando e PRs prontos para merge."
    static let toReview = "para revisar"
    static let ciFailing = "CI falhando"
    static let readyToMerge = "prontos p/ merge"
    static let readyItem = "pronto para merge"
    static let empty = "Nada pedindo ação"
    static let disconnected = "Conecte sua conta no PRumo"
    static let updatedAt = "Atualizado às"
}

enum WidgetMetrics {
    static let wordmarkSize: CGFloat = 13
    static let padding: CGFloat = 2
    static let smallSpacing: CGFloat = 6
    static let mediumSpacing: CGFloat = 8
    static let counterNumberSize: CGFloat = 26
    static let smallCounterNumberSize: CGFloat = 30
    static let counterLabelSize: CGFloat = 11
    static let rowSpacing: CGFloat = 5
    static let rowFontSize: CGFloat = 12
    static let dotSize: CGFloat = 7
    static let dotSpacing: CGFloat = 7
    static let footerSize: CGFloat = 10
    static let counterSpacing: CGFloat = 16
    static let numberLabelSpacing: CGFloat = 1
    static let reloadInterval: TimeInterval = 30 * 60
    static let staleLimit: TimeInterval = 3600
    static let maxRows = 3
}

enum WidgetPlaceholder {
    static let items: [(number: Int, title: String, hours: Int?)] = [
        (809, "feat(pedido): filtro por status", nil),
        (798, "reserva por pedido", 26),
        (812, "", nil)
    ]
}
