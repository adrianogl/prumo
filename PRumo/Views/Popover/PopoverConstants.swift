import SwiftUI

enum PopoverMetrics {
    static let width: CGFloat = 390
    static let listMaxHeight: CGFloat = 520
    static let headerIconSize: CGFloat = 20
    static let dotSize: CGFloat = 9
    static let menuBarGlyphSize: CGFloat = 16
    static let menuBarDotSize: CGFloat = 5
}

enum PopoverText {
    static let mineTab = "Meus PRs"
    static let reviewTab = "Revisar"
    static let emptyMine = "Nenhum PR aberto"
    static let emptyReview = "Nenhum review pedido"
    static let settings = "Ajustes"
    static let refresh = "Atualizar"
    static let updating = "Atualizando…"
    static let reconnect = "Conectar de novo"
    static let invalidToken = "Token inválido."
    static let onboardingWindowID = "onboarding"

    static func updatedAgo(seconds: Int) -> String {
        if seconds < 60 { return "Atualizado há \(seconds)s" }
        if seconds < 3600 { return "Atualizado há \(seconds / 60)min" }
        return "Atualizado há \(seconds / 3600)h"
    }

    static func offline(lastSuccess: String?, retryIn: Int) -> String {
        let data = lastSuccess.map { "Mostrando dados de \($0). " } ?? ""
        return "Sem conexão. \(data)Tentando de novo em \(retryIn)s."
    }

    static func rateLimited(resetAt: String?) -> String {
        resetAt.map { "Limite da API do GitHub. Volta às \($0)" } ?? "Limite da API do GitHub."
    }
}

enum PopoverTab: Hashable {
    case mine, review
}
