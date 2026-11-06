import PRumoKit

extension AppModel {
    var reviewBadgeCount: Int {
        guard let snapshot else { return 0 }
        return Counters.reviewBadge(
            snapshot, ignoreDrafts: organization.settings.ignoreDraftsInReview,
            includeTeam: organization.settings.includeTeamRequests)
    }
}
