import Foundation

public enum ActivityKind: Equatable, Sendable {
    case review(ReviewState)
    case comment
    case ciFailed(checks: [String])
    case ciPassed
    case ciRunning
}

public struct ActivityItem: Equatable, Sendable, Identifiable {
    public let id: String
    public let kind: ActivityKind
    public let actor: String?
    public let date: Date
    public let url: URL?

    public init(id: String, kind: ActivityKind, actor: String?, date: Date, url: URL?) {
        self.id = id
        self.kind = kind
        self.actor = actor
        self.date = date
        self.url = url
    }
}

public enum PullRequestActivity {
    static let ciItemID = "ci"
    public static let defaultLimit = 20

    public static func items(for pr: PullRequest, limit: Int = defaultLimit) -> [ActivityItem] {
        let reviews = pr.reviews
            .filter { $0.state != .pending && !($0.state == .commented && !$0.isComment) }
            .map { ActivityItem(id: $0.id, kind: .review($0.state), actor: $0.author, date: $0.submittedAt, url: $0.url) }
        let comments = pr.comments
            .map { ActivityItem(id: $0.id, kind: .comment, actor: $0.author, date: $0.createdAt, url: $0.url) }
        let all = reviews + comments + [ciItem(pr)].compactMap { $0 }
        return Array(all.sorted { $0.date > $1.date }.prefix(limit))
    }

    private static func ciItem(_ pr: PullRequest) -> ActivityItem? {
        let finished = pr.checks.compactMap(\.completedAt).max()
        switch pr.ci {
        case .none:
            return nil
        case .pending:
            guard let since = pr.ciPendingSince else { return nil }
            return ActivityItem(id: ciItemID, kind: .ciRunning, actor: nil, date: since, url: pr.checksURL)
        case .success:
            guard let finished else { return nil }
            return ActivityItem(id: ciItemID, kind: .ciPassed, actor: nil, date: finished, url: pr.checksURL)
        case .failure(let failed, _):
            let date = pr.checks.filter { $0.state == .failure }.compactMap(\.completedAt).max() ?? finished
            guard let date else { return nil }
            return ActivityItem(id: ciItemID, kind: .ciFailed(checks: failed), actor: nil, date: date, url: pr.checksURL)
        }
    }
}
