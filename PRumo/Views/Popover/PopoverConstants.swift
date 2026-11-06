import SwiftUI

enum PopoverMetrics {
    static let width: CGFloat = 390
    static let footerFontSize: CGFloat = 11
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
    static let staleAccountOpacity: Double = 0.55
    static let providerIconSize: CGFloat = 11
    static let providerIconSpacing: CGFloat = 4
    static let pinSize: CGFloat = 10
    static let mergedIconSize: CGFloat = 11
    static let dndIconSize: CGFloat = 13
    static let dndSleepSize: CGFloat = 7
    static let dndSleepOffsetX: CGFloat = 4
    static let dndSleepOffsetY: CGFloat = -4
    static let dndFrameSize: CGFloat = 20
    static let footerSpacing: CGFloat = 4
    static let searchSpacing: CGFloat = 6
    static let searchVerticalPadding: CGFloat = 5
    static let searchBottomPadding: CGFloat = 12
    static let selectionLineWidth: CGFloat = 1.5
    static let selectionCornerRadius: CGFloat = 6
    static let jiraBadgeBackgroundOpacity: Double = 0.14
}

enum PopoverFocus: Hashable {
    case list
    case search
}

enum PopoverKey {
    static let mineTab: Character = "1"
    static let reviewTab: Character = "2"
    static let mergeTab: Character = "3"
    static let rowMenu: Character = "."
    static let openWindow: Character = "o"
    static let claude = Character(ClaudeText.shortcutKey)
    static let openJira = RowMenuKey.openJira
    static let copy = RowMenuKey.copy
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
    static let dndBell = "bell"
    static let dndSleep = "zzz"
    static let search = "magnifyingglass"
    static let clearSearch = "xmark.circle.fill"
}

enum PopoverText {
    static let mineTab = "Meus PRs"
    static let reviewTab = "Revisar"
    static let mergeTab = "Merge"
    static let openJiraHelp = "Abrir card no Jira"
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
    static let dnd = "Não perturbe"
    static let dndOneHour = "Por 1 hora"
    static let dndUntilTomorrow = "Até amanhã às 9h"
    static let dndIndefinite = "Até eu reativar"
    static let dndReactivate = "Reativar notificações"
    static let dndUntilIndefinite = "Não perturbe até você reativar"
    static let outsideWorkingHours = "Fora do horário de trabalho"
    static let footerSeparator = "·"
    static let searchPlaceholder = "Buscar por título, repositório ou número"
    static let clearSearch = "Limpar busca"
    static let keyboardHint = "↑↓ navegar · ↵ abrir · ⌘. menu · ⌘K Claude"

    static func nothingFound(query: String) -> String { "Nada encontrado para “\(query)”" }

    static func dndUntil(time: String) -> String { "Não perturbe até \(time)" }

    static func dndUntilTomorrow(time: String) -> String { "Não perturbe até amanhã às \(time)" }

    static func mergedToday(count: Int) -> String { "MERGEADOS HOJE · \(count)" }

    static func mergedAt(time: String) -> String { "merge às \(time)" }

    static func mergedSubtitle(account: String? = nil, repository: String, reference: String, time: String) -> String {
        let parts = [account, "\(repository) \(reference)", mergedAt(time: time)].compactMap { $0 }
        return parts.joined(separator: " · ")
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

    static func unexpectedResponse(provider: String, lastSuccess: String?, retryIn: Int) -> String {
        let data = lastSuccess.map { "Mostrando dados de \($0). " } ?? ""
        return "O \(provider) mandou uma resposta que o PRumo não entendeu. \(data)Tentando de novo em \(retryIn)s."
    }

    static let accountSettings = "Ajustes"
    static let accountReconnect = "Reconectar"
    static let accountOthersKeepUpdating = "Os outros PRs continuam atualizando."

    static func accountOffline(name: String, host: String, age: String?) -> String {
        let since = age.map { " há \($0)" } ?? ""
        return "\(name) (\(host)) sem acesso\(since). \(accountOthersKeepUpdating)"
    }

    static func accountInvalidToken(name: String, host: String) -> String {
        "\(name) (\(host)) com token inválido. \(accountOthersKeepUpdating)"
    }

    static func accountRateLimited(name: String, host: String, resetAt: String?) -> String {
        let until = resetAt.map { " até \($0)" } ?? ""
        return "\(name) (\(host)) no limite da API\(until)."
    }

    static func accountUnexpectedResponse(name: String, host: String) -> String {
        "\(name) (\(host)) respondeu de um jeito inesperado. Mostrando o último dado."
    }

    static func openJiraLabel(key: String) -> String { "\(openJiraHelp) \(key)" }

    static func rateLimited(provider: String, resetAt: String?) -> String {
        resetAt.map { "Limite da API do \(provider). Volta às \($0)" } ?? "Limite da API do \(provider)."
    }
}
