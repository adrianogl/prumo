public enum TabSource {
    public static func pullRequests(_ snapshot: Snapshot, tab: ListTab, settings: OrganizationSettings) -> [PullRequest] {
        switch tab {
        case .mine:
            snapshot.mine
        case .review:
            ReviewInclusion.visible(
                snapshot.toReview, ignoreDrafts: settings.ignoreDraftsInReview,
                includeTeam: settings.includeTeamRequests)
        case .merge:
            snapshot.mine.filter { MergeReadiness.isReady($0, viewer: snapshot.viewer(for: $0)) }
        }
    }
}
