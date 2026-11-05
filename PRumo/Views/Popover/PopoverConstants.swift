import SwiftUI

enum PopoverMetrics {
    static let width: CGFloat = 390
    static let listMaxHeight: CGFloat = 520
    static let headerIconSize: CGFloat = 26
    static let badgeSpacing: CGFloat = 5
    static let badgeLineSpacing: CGFloat = 4
    static let dotSize: CGFloat = 9
    static let menuBarGlyphSize: CGFloat = 15
    static let menuBarDotSize: CGFloat = 5
    static let menuReserve: CGFloat = 26
    static let newDotSize: CGFloat = 7
    static let mutedOpacity: Double = 0.55
    static let pinSize: CGFloat = 10
    static let mergedIconSize: CGFloat = 11
}

enum PopoverSymbol {
    static let refresh = "arrow.clockwise"
    static let settings = "gearshape"
    static let warning = "exclamationmark.triangle"
    static let comments = "bubble.left.and.bubble.right"
    static let conflict = "arrow.triangle.merge"
    static let clock = "clock"
    static let menuBarGlyph = "MenuBarGlyph"
    static let appLogo = "AppLogo"
    static let pinned = "pin.fill"
    static let muted = "pause.fill"
    static let merged = "checkmark"
}

enum PopoverText {
    static let mineTab = "Meus PRs"
    static let reviewTab = "Revisar"
    static let mergeTab = "Merge"
    static let emptyMine = "Nenhum PR aberto"
    static let emptyReview = "Nenhum review pedido"
    static let emptyMerge = "Nenhum PR pronto para merge"
    static let clockFormat = "HH:mm"
    static let dayMonthFormat = "dd/MM"
    static let settings = "Ajustes"
    static let refresh = "Atualizar"
    static let updating = "Atualizando…"
    static let reconnect = "Conectar de novo"
    static let invalidToken = "Token inválido."
    static let connectPrompt = "Conecte sua conta do GitHub"
    static let connectAction = "Conectar"
    static let onboardingWindowID = "onboarding"

    static func mergedToday(count: Int) -> String { "MERGEADOS HOJE · \(count)" }

    static func mergedAt(time: String) -> String { "merge às \(time)" }

    static func mergedSubtitle(repository: String, number: Int, time: String) -> String {
        "\(repository) #\(number) · \(mergedAt(time: time))"
    }

    static func mutedOn(date: String) -> String { "Silenciado em \(date)" }

    static func updatedAgo(seconds: Int) -> String {
        if seconds < 60 { return "Atualizado há \(seconds)s" }
        if seconds < 3600 { return "Atualizado há \(seconds / 60)min" }
        return "Atualizado há \(seconds / 3600)h"
    }

    static func offline(lastSuccess: String?, retryIn: Int) -> String {
        let data = lastSuccess.map { "Mostrando dados de \($0). " } ?? ""
        return "Sem conexão. \(data)Tentando de novo em \(retryIn)s."
    }

    static func unexpectedResponse(lastSuccess: String?, retryIn: Int) -> String {
        let data = lastSuccess.map { "Mostrando dados de \($0). " } ?? ""
        return "O GitHub mandou uma resposta que o PRumo não entendeu. \(data)Tentando de novo em \(retryIn)s."
    }

    static func rateLimited(resetAt: String?) -> String {
        resetAt.map { "Limite da API do GitHub. Volta às \($0)" } ?? "Limite da API do GitHub."
    }
}
