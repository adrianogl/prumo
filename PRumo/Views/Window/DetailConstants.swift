import SwiftUI
import PRumoKit

enum DetailText {
    static let checks = "Checks"
    static let reviews = "Reviews"
    static let activity = "Atividade"
    static let noChecks = "Nenhum check neste commit"
    static let noReviews = "Nenhum review ainda"
    static let noActivity = "Nada recente"
    static let claude = "Claude"
    static let more = "Mais ações"
    static let approved = "aprovou"
    static let changesRequested = "pediu alterações"
    static let dismissed = "review descartado"
    static let commented = "comentou"
    static let pending = "pendente"
    static let ciPassed = "CI passou"
    static let ciRunning = "CI rodando"
    static let draft = "rascunho"

    static func updated(_ age: String) -> String { "atualizado há \(age)" }

    static func ciFailed(_ checks: [String]) -> String {
        checks.isEmpty ? "CI falhou" : "CI falhou em \(checks.joined(separator: ", "))"
    }

    static func ago(_ age: String) -> String { "há \(age)" }

    static func duration(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        if total < 60 { return "\(total)s" }
        if total < 3600 { return "\(total / 60)m\(String(format: "%02d", total % 60))s" }
        return "\(total / 3600)h\(String(format: "%02d", total % 3600 / 60))m"
    }
}

enum DetailMetrics {
    static let padding: CGFloat = 24
    static let spacing: CGFloat = 14
    static let titleFontSize: CGFloat = 22
    static let sectionFontSize: CGFloat = 11
    static let rowFontSize: CGFloat = 12.5
    static let rowPadding: CGFloat = 7
    static let cardRadius: CGFloat = 9
    static let columnSpacing: CGFloat = 14
    static let stateDotSize: CGFloat = 9
}

enum DetailSymbol {
    static let success = "checkmark"
    static let failure = "xmark"
    static let running = "circle.dotted"
    static let pending = "circle"
    static let skipped = "minus"
    static let comment = "bubble.left"
    static let claude = ClaudeSymbol.tab
}

extension CheckState {
    var symbol: String {
        switch self {
        case .success: DetailSymbol.success
        case .failure: DetailSymbol.failure
        case .running: DetailSymbol.running
        case .pending: DetailSymbol.pending
        case .skipped: DetailSymbol.skipped
        }
    }

    var color: Color {
        switch self {
        case .success: Color.statusOK
        case .failure: Color.statusBad
        case .running, .pending: Color.statusIdle
        case .skipped: Color.secondary
        }
    }
}

extension ReviewState {
    var detailLabel: String {
        switch self {
        case .approved: DetailText.approved
        case .changesRequested: DetailText.changesRequested
        case .dismissed: DetailText.dismissed
        case .commented: DetailText.commented
        case .pending: DetailText.pending
        }
    }

    var detailSymbol: String {
        switch self {
        case .approved: DetailSymbol.success
        case .changesRequested: DetailSymbol.failure
        case .commented: DetailSymbol.comment
        case .dismissed, .pending: DetailSymbol.pending
        }
    }

    var detailColor: Color {
        switch self {
        case .approved: Color.statusOK
        case .changesRequested: Color.statusAttention
        case .commented, .dismissed, .pending: Color.statusIdle
        }
    }
}

extension ActivityKind {
    func text(actor: String?) -> String {
        let who = actor.map { "@\($0) " } ?? ""
        return switch self {
        case .review(let state): who + state.detailLabel
        case .comment: who + DetailText.commented
        case .ciFailed(let checks): DetailText.ciFailed(checks)
        case .ciPassed: DetailText.ciPassed
        case .ciRunning: DetailText.ciRunning
        }
    }

    var symbol: String {
        switch self {
        case .review(let state): state.detailSymbol
        case .comment: DetailSymbol.comment
        case .ciFailed: DetailSymbol.failure
        case .ciPassed: DetailSymbol.success
        case .ciRunning: DetailSymbol.running
        }
    }

    var color: Color {
        switch self {
        case .review(let state): state.detailColor
        case .comment: Color.statusIdle
        case .ciFailed: Color.statusBad
        case .ciPassed: Color.statusOK
        case .ciRunning: Color.statusIdle
        }
    }
}
