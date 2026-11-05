import Foundation

enum FiltersSettingsMetrics {
    static let height: CGFloat = 480
    static let hintSize: CGFloat = 11
}

enum FiltersSettingsSymbol {
    static let tab = "line.3.horizontal.decrease.circle"
    static let remove = "minus.circle"
}

enum FiltersSettingsText {
    static let tab = "Filtros"
    static let ignoreDrafts = "Ignorar drafts em Revisar"
    static let ignoreDraftsHint = "Desligado, os drafts com review pedido aparecem em Revisar."
    static let includeTeam = "Incluir reviews pedidos ao time"
    static let includeTeamHint = "Ligado, o pedido ao time vale como pedido a você: aparece na lista, notifica e entra no contador."
    static let views = "Visões salvas"
    static let noViews = "Nenhuma visão salva"
    static let viewName = "Nome da visão"
    static let remove = "Remover"
    static let muted = "PRs silenciados"
    static let noMuted = "Nenhum PR silenciado"
    static let unmute = "Reativar"

    static func mutedTitle(_ pr: MutedTitleParts) -> String {
        "\(pr.repository) #\(pr.number) · \(pr.title)"
    }

    static func mutedOn(_ date: Date) -> String {
        "Silenciado em \(date.formatted(.dateTime.day(.twoDigits).month(.twoDigits).locale(Locale(identifier: "pt_BR"))))"
    }
}

struct MutedTitleParts {
    let repository: String
    let number: Int
    let title: String
}
