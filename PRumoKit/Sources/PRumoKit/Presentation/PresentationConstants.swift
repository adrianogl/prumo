import Foundation

enum PresentationText {
    static let draft = "draft"
    static let conflict = "conflito"
    static let changesRequested = "alterações pedidas"
    static let now = "agora"
    static let minus = "\u{2212}"
    static let approvalMark = "✓"
    static let approvalSingular = "aprovação"
    static let approvalPlural = "aprovações"
    static let ciSuccessMark = "✓ CI"
    static let ciPendingMark = "● CI"
    static let ciFailureMark = "✗"
    static let forYou = "para você"
    static let teamPrefix = "time"
    static let noConflict = "sem conflito"
    static let approved = "aprovado"
    static let noReview = "sem review"
    static let ciOk = "CI ok"
    static let ciRunning = "CI rodando"
    static let ciFailed = "CI falhou"
    static let separator = " · "
    static let waitingPrefix = "esperando há"
}

enum PresentationMetrics {
    static let secondsPerHour: TimeInterval = 3600
}
