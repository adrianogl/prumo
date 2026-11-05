import Foundation

public enum RowFiltering {
    public static func apply(
        _ prs: [PullRequest], filter: RowFilter, tab: ListTab, context: FilterContext
    ) -> [PullRequest] {
        prs.filter { matches($0, filter: filter, tab: tab, context: context) }
    }

    private static func matches(
        _ pr: PullRequest, filter: RowFilter, tab: ListTab, context: FilterContext
    ) -> Bool {
        matchesRepository(pr, filter)
            && matchesCI(pr, filter)
            && matchesReview(pr, filter, viewer: context.viewer(for: pr))
            && matchesState(pr, filter, context: context)
            && matchesRequest(pr, filter, tab: tab, context: context)
            && matchesAuthor(pr, filter)
    }

    private static func matchesRepository(_ pr: PullRequest, _ filter: RowFilter) -> Bool {
        filter.repositories.isEmpty || filter.repositories.contains(pr.repository)
    }

    private static func matchesCI(_ pr: PullRequest, _ filter: RowFilter) -> Bool {
        guard !filter.ci.isEmpty else { return true }
        let kind: CIFilter
        switch pr.ci {
        case .success, .none: kind = .passed
        case .pending: kind = .running
        case .failure: kind = .failing
        }
        return filter.ci.contains(kind)
    }

    private static func matchesReview(_ pr: PullRequest, _ filter: RowFilter, viewer: String) -> Bool {
        guard !filter.review.isEmpty else { return true }
        let summary = ReviewSummary(pr, viewer: viewer)
        let kind: ReviewFilter
        if summary.hasChangesRequested {
            kind = .changesRequested
        } else if summary.approvals > 0 {
            kind = .approved
        } else {
            kind = .noReview
        }
        return filter.review.contains(kind)
    }

    private static func matchesState(_ pr: PullRequest, _ filter: RowFilter, context: FilterContext) -> Bool {
        if filter.state.contains(.noDrafts) && pr.isDraft { return false }
        let alternatives = filter.state.subtracting([.noDrafts])
        guard !alternatives.isEmpty else { return true }
        return alternatives.contains { state in
            switch state {
            case .conflicting: pr.mergeable == .conflicting
            case .newActivity: context.unseen.contains(pr.id)
            case .pinned: context.marks.isPinned(pr.id)
            case .noDrafts: false
            }
        }
    }

    private static func matchesRequest(
        _ pr: PullRequest, _ filter: RowFilter, tab: ListTab, context: FilterContext
    ) -> Bool {
        guard tab == .review, !filter.request.isEmpty else { return true }
        return filter.request.contains { request in
            switch request {
            case .forYou:
                pr.reviewTarget == .you
            case .forTeam:
                if case .team = pr.reviewTarget { true } else { false }
            case .stale:
                context.now.timeIntervalSince(pr.reviewRequestedAt ?? pr.createdAt) >= context.staleLimit
            }
        }
    }

    private static func matchesAuthor(_ pr: PullRequest, _ filter: RowFilter) -> Bool {
        guard !filter.authors.isEmpty else { return true }
        return filter.authors.contains { $0.caseInsensitiveCompare(pr.author) == .orderedSame }
    }
}
