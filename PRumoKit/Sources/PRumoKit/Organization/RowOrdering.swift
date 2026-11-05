import Foundation

public enum RowOrdering {
    public static func sections(
        _ prs: [PullRequest], tab: ListTab, ordering: TabOrdering, marks: RowMarks, viewer: (PullRequest) -> String
    ) -> [RowSection] {
        let sorted = prs.sorted { precedes($0, $1, tab: tab, order: ordering.order, viewer: viewer) }
        guard ordering.groupByRepository else {
            return [RowSection(repository: nil, items: applyMarks(sorted, marks))]
        }
        let grouped = Dictionary(grouping: sorted, by: \.repositoryKey)
        return grouped.keys.sorted { $0.localizedStandardCompare($1) == .orderedAscending }.map { RowSection(repository: $0, items: applyMarks(grouped[$0] ?? [], marks)) }
    }

    private static func applyMarks(_ prs: [PullRequest], _ marks: RowMarks) -> [PullRequest] {
        func rank(_ pr: PullRequest) -> Int {
            if marks.isMuted(pr.id) { return 2 }
            return marks.isPinned(pr.id) ? 0 : 1
        }
        return [0, 1, 2].flatMap { level in prs.filter { rank($0) == level } }
    }

    private static func precedes(
        _ a: PullRequest, _ b: PullRequest, tab: ListTab, order: RowSortOrder, viewer: (PullRequest) -> String
    ) -> Bool {
        switch order {
        case .recentActivity:
            if a.updatedAt != b.updatedAt { return a.updatedAt > b.updatedAt }
        case .needsActionFirst:
            let left = needsAction(a, tab: tab, viewer: viewer(a))
            let right = needsAction(b, tab: tab, viewer: viewer(b))
            if left != right { return left }
            if a.updatedAt != b.updatedAt { return a.updatedAt > b.updatedAt }
        case .oldestFirst:
            if a.createdAt != b.createdAt { return a.createdAt < b.createdAt }
        case .newestFirst:
            if a.createdAt != b.createdAt { return a.createdAt > b.createdAt }
        case .repository:
            let byName = a.repositoryKey.localizedStandardCompare(b.repositoryKey)
            if byName != .orderedSame { return byName == .orderedAscending }
        case .diffSize:
            let left = a.additions + a.deletions
            let right = b.additions + b.deletions
            if left != right { return left > right }
        }
        if a.number != b.number { return a.number > b.number }
        let byRepository = a.repositoryKey.localizedStandardCompare(b.repositoryKey)
        if byRepository != .orderedSame { return byRepository == .orderedAscending }
        return a.id < b.id
    }

    private static func needsAction(_ pr: PullRequest, tab: ListTab, viewer: String) -> Bool {
        switch tab {
        case .review:
            return pr.reviewTarget == .you
        case .mine, .merge:
            if case .failure = pr.ci { return true }
            return ReviewSummary(pr, viewer: viewer).hasChangesRequested || pr.mergeable == .conflicting
        }
    }
}
