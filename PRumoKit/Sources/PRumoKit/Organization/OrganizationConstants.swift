import Foundation

public enum OrganizationConstants {
    public static let defaultStaleLimit: TimeInterval = 24 * 3600
}

enum OrganizationText {
    static let favoritesTitle = "FAVORITOS"
    static let ciPassed = "CI passou"
    static let ciRunning = "CI rodando"
    static let ciFailing = "CI falhando"
    static let approved = "Aprovado"
    static let changesRequested = "Alterações pedidas"
    static let noReview = "Sem review"
    static let noDrafts = "Sem drafts"
    static let conflicting = "Com conflito"
    static let newActivity = "Com atividade nova"
    static let pinned = "Fixados"
    static let forYou = "Para você"
    static let forTeam = "Para o time"
    static func stale(hours: Int) -> String { "Parado há +\(hours)h" }
    static func author(_ login: String) -> String { "Autor: \(login)" }
}
