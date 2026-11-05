import PRumoKit

extension PullRequest {
    func claudePurposes(in tab: PopoverTab) -> [SessionPurpose] {
        switch tab {
        case .review:
            return [.review]
        case .mine:
            var purposes: [SessionPurpose] = []
            if hasFailedCI { purposes.append(.fixCI) }
            if mergeable == .conflicting { purposes.append(.resolveConflict) }
            return purposes
        }
    }
}
