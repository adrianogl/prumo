import Foundation

public enum StaleReviewTracker {
    public static func key(for pr: PullRequest) -> String {
        "\(pr.id)@\(Int(start(of: pr).timeIntervalSince1970))"
    }

    public static func due(
        snapshot: Snapshot, limit: TimeInterval, reminded: Set<String>, muted: Set<String>,
        ignoreDrafts: Bool, includeTeam: Bool, now: Date
    ) -> [StaleReminder] {
        ReviewInclusion.visible(snapshot.toReview, ignoreDrafts: ignoreDrafts, includeTeam: includeTeam)
            .compactMap { pr -> StaleReminder? in
                guard !muted.contains(pr.id) else { return nil }
                let waited = now.timeIntervalSince(start(of: pr))
                let key = key(for: pr)
                guard waited >= limit, !reminded.contains(key) else { return nil }
                let hours = Int(waited / ReminderConstants.secondsPerHour)
                let event = NotificationEvent(
                    kind: .staleReview, pullRequestID: pr.id,
                    title: "\(ReminderConstants.titlePrefix) \(hours)h: #\(pr.number)",
                    body: "\(pr.author) \(ReminderConstants.bodyInfix) \(pr.title)",
                    url: pr.url, accountID: pr.accountID
                )
                return StaleReminder(key: key, event: event)
            }
    }

    private static func start(of pr: PullRequest) -> Date {
        pr.reviewRequestedAt ?? pr.createdAt
    }
}
