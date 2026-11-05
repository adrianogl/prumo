import Foundation

public enum WidgetSummary {
    private static let maxItems = 3
    private static let secondsPerHour: TimeInterval = 3600

    public static func make(
        snapshot: Snapshot, ignoreDrafts: Bool, includeTeam: Bool, muted: Set<String>,
        staleLimit: TimeInterval, now: Date
    ) -> WidgetSnapshot {
        let failing = snapshot.mine.filter { pr in
            if case .failure = pr.ci { return true }
            return false
        }
        let ready = snapshot.mine.filter { MergeReadiness.isReady($0, viewer: snapshot.viewer) }

        let failingItems = failing
            .filter { !muted.contains($0.id) }
            .sorted { $0.updatedAt > $1.updatedAt }
            .map { item($0, reason: .ciFailing) }

        let staleItems = ReviewInclusion.visible(snapshot.toReview, ignoreDrafts: ignoreDrafts, includeTeam: includeTeam)
            .filter { !muted.contains($0.id) }
            .map { (pr: $0, waited: now.timeIntervalSince(waitStart($0))) }
            .filter { $0.waited >= staleLimit }
            .sorted { $0.waited > $1.waited }
            .map { item($0.pr, reason: .staleReview, waitingHours: Int($0.waited / secondsPerHour)) }

        let readyItems = ready
            .filter { !muted.contains($0.id) }
            .sorted { $0.updatedAt > $1.updatedAt }
            .map { item($0, reason: .readyToMerge) }

        return WidgetSnapshot(
            connected: true,
            toReview: Counters.reviewBadge(snapshot, ignoreDrafts: ignoreDrafts, includeTeam: includeTeam),
            ciFailing: failing.count,
            readyToMerge: Counters.readyToMerge(snapshot),
            items: Array((failingItems + staleItems + readyItems).prefix(maxItems)),
            updatedAt: now
        )
    }

    private static func waitStart(_ pr: PullRequest) -> Date {
        pr.reviewRequestedAt ?? pr.createdAt
    }

    private static func item(_ pr: PullRequest, reason: WidgetReason, waitingHours: Int? = nil) -> WidgetItem {
        WidgetItem(id: pr.id, number: pr.number, title: pr.title, url: pr.url, reason: reason, waitingHours: waitingHours)
    }
}
