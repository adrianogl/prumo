import Foundation
import PRumoKit
import SwiftUI

enum NotificationsSettingsMetrics {
    static let height: CGFloat = 640
    static let weekdayButtonSize: CGFloat = 26
    static let weekdaySpacing: CGFloat = 4
    static let errorSize: CGFloat = 12
    static let minutesPerHour = 60
    static let unselectedBorderOpacity = 0.5
    static let selectedBorderOpacity = 0.0
}

enum NotificationsSettingsColor {
    static let selectedForeground = Color.white
    static let error = Color.red
}

enum NotificationsSettingsSymbol {
    static let tab = "bell"
}

enum NotificationsSettingsText {
    static let tab = "Notificações"
    static let staleAfter = "Lembrar review parado após"
    static let groupByPullRequest = "Agrupar notificações de CI"
    static let workingHoursOnly = "Só em horário de trabalho"
    static let from = "Das"
    static let to = "às"
    static let invalidRange = "O fim precisa ser depois do início."
    static let noWeekdays = "Escolha ao menos um dia"
    static let weekdayLetters = ["D", "S", "T", "Q", "Q", "S", "S"]
    static let weekdayNames = ["Domingo", "Segunda", "Terça", "Quarta", "Quinta", "Sexta", "Sábado"]

    static func title(_ toggle: NotificationToggle) -> String {
        switch toggle {
        case .ci: "CI terminou nos meus PRs"
        case .approved: "Meu PR foi aprovado"
        case .changesRequested: "Alterações pedidas"
        case .newComment: "Comentário novo"
        case .reviewRequested: "Novo pedido de review"
        case .staleReview: "Review parado"
        case .readyToMerge: "PR pronto para merge"
        case .conflict: "PR entrou em conflito"
        }
    }

    static func hours(_ value: Int) -> String { "\(value) h" }
}

enum NotificationsSettingsOptions {
    static let staleReviewHours = [4, 8, 24, 48]
}
