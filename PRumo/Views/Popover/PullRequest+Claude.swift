import PRumoKit

extension PullRequest {
    func claudePurposes(in tab: ListTab, offersComments: Bool) -> [SessionPurpose] {
        switch tab {
        case .review:
            return [.review]
        case .mine, .merge:
            var purposes: [SessionPurpose] = []
            if hasFailedCI { purposes.append(.fixCI) }
            if mergeable == .conflicting { purposes.append(.resolveConflict) }
            if offersComments { purposes.append(.addressComments) }
            return purposes
        }
    }
}
