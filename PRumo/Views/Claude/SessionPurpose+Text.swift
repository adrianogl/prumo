import PRumoKit

extension SessionPurpose {
    var menuTitle: String {
        switch self {
        case .review: ClaudeText.review
        case .fixCI: ClaudeText.fixCI
        case .resolveConflict: ClaudeText.resolveConflict
        case .addressComments: ClaudeText.addressComments
        }
    }

    var badgeTitle: String {
        switch self {
        case .review: ClaudeText.review
        case .fixCI: ClaudeText.fixBadge
        case .resolveConflict: ClaudeText.resolveBadge
        case .addressComments: ClaudeText.resolveBadge
        }
    }
}
