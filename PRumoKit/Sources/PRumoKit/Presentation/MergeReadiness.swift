public enum MergeReadiness {
    public static func isReady(_ pr: PullRequest, viewer: String) -> Bool {
        if let mergeReady = pr.mergeReady {
            return mergeReady && !pr.isDraft && ciAllowsMerge(pr.ci)
        }
        guard !pr.isDraft, pr.mergeable == .mergeable, ciAllowsMerge(pr.ci) else { return false }
        switch pr.reviewDecision {
        case .approved:
            return true
        case nil:
            let summary = ReviewSummary(pr, viewer: viewer)
            return summary.approvals >= 1 && !summary.hasChangesRequested
        case .changesRequested, .reviewRequired:
            return false
        }
    }

    private static func ciAllowsMerge(_ ci: CIStatus) -> Bool {
        switch ci {
        case .none, .success: true
        case .pending, .failure: false
        }
    }
}
