import PRumoKit

extension SessionPurpose {
    var menuTitle: String {
        switch self {
        case .review: ClaudeText.review
        case .fixCI: ClaudeText.fixCI
        case .resolveConflict: ClaudeText.resolveConflict
        }
    }

    var badgeTitle: String {
        switch self {
        case .review: ClaudeText.review
        case .fixCI: ClaudeText.fixBadge
        case .resolveConflict: ClaudeText.resolveBadge
        }
    }
}
