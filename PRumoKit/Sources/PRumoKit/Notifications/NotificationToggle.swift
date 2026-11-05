public enum NotificationToggle: String, Codable, CaseIterable, Sendable {
    case ci, approved, changesRequested, newComment, reviewRequested, staleReview, readyToMerge, conflict

    public init(kind: NotificationKind) {
        switch kind {
        case .ciFailed, .ciSucceeded: self = .ci
        case .approved: self = .approved
        case .changesRequested: self = .changesRequested
        case .newComment: self = .newComment
        case .reviewRequested: self = .reviewRequested
        case .staleReview: self = .staleReview
        case .readyToMerge: self = .readyToMerge
        case .conflict: self = .conflict
        }
    }
}
