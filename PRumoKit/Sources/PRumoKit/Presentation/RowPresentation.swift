import Foundation

public enum StatusDot: Equatable, Sendable {
    case ok, running, failed, attention
}

public struct RowPresentation: Equatable, Sendable {
    public let dot: StatusDot
    public let title: String
    public let subtitle: String
    public let badges: [Badge]
    public let ciFailureBadgeIndex: Int?
    public let conflictBadgeIndex: Int?

    public init(
        dot: StatusDot, title: String, subtitle: String, badges: [Badge],
        ciFailureBadgeIndex: Int? = nil, conflictBadgeIndex: Int? = nil
    ) {
        self.dot = dot
        self.title = title
        self.subtitle = subtitle
        self.badges = badges
        self.ciFailureBadgeIndex = ciFailureBadgeIndex
        self.conflictBadgeIndex = conflictBadgeIndex
    }
}

public enum RowPresenter {
    public static func mine(_ pr: PullRequest, viewer: String, now: Date) -> RowPresentation {
        let verdicts = latestVerdicts(pr.reviews, excluding: viewer)
        let approvals = verdicts.filter { $0 == .approved }.count
        let hasChangesRequested = verdicts.contains(.changesRequested)

        var badges: [Badge] = []
        var ciFailureIndex: Int?
        if let ci = ciBadge(pr.ci) {
            if case .failure = pr.ci { ciFailureIndex = badges.count }
            badges.append(ci)
        }
        if approvals > 0 {
            badges.append(Badge("\(PresentationText.approvalMark) \(approvals) \(approvals == 1 ? PresentationText.approvalSingular : PresentationText.approvalPlural)", .positive))
        }
        if hasChangesRequested { badges.append(Badge(PresentationText.changesRequested, .negative)) }
        if pr.isDraft { badges.append(Badge(PresentationText.draft, .neutral)) }
        var conflictIndex: Int?
        if pr.mergeable == .conflicting {
            conflictIndex = badges.count
            badges.append(Badge(PresentationText.conflict, .warning, .conflict))
        }
        let commentTotal = pr.commentCount + pr.reviews.filter(\.isComment).count
        if commentTotal > 0 { badges.append(Badge(String(commentTotal), .neutral, .comments)) }

        return RowPresentation(
            dot: dot(ci: pr.ci, hasChangesRequested: hasChangesRequested),
            title: pr.title,
            subtitle: subtitle(pr, from: pr.createdAt, now: now),
            badges: badges,
            ciFailureBadgeIndex: ciFailureIndex,
            conflictBadgeIndex: conflictIndex
        )
    }

    public static func review(_ pr: PullRequest, now: Date) -> RowPresentation {
        var badges = [Badge(pr.author, .neutral)]
        if let ci = ciBadge(pr.ci) { badges.append(ci) }
        badges.append(Badge("+\(pr.additions) \(PresentationText.minus)\(pr.deletions)", .neutral))

        return RowPresentation(
            dot: dot(ci: pr.ci, hasChangesRequested: false),
            title: pr.title,
            subtitle: subtitle(pr, from: pr.reviewRequestedAt ?? pr.createdAt, now: now),
            badges: badges
        )
    }

    private static func subtitle(_ pr: PullRequest, from: Date, now: Date) -> String {
        "\(pr.repository) #\(pr.number) · \(RelativeAge.string(from: from, now: now))"
    }

    private static func dot(ci: CIStatus, hasChangesRequested: Bool) -> StatusDot {
        if case .failure = ci { return .failed }
        if hasChangesRequested { return .attention }
        if case .pending = ci { return .running }
        return .ok
    }

    private static func ciBadge(_ ci: CIStatus) -> Badge? {
        switch ci {
        case .none: nil
        case let .success(total): Badge("\(PresentationText.ciSuccessMark) \(total)/\(total)", .positive)
        case let .pending(done, total): Badge("\(PresentationText.ciPendingMark) \(done)/\(total)", .pending)
        case let .failure(failed, total): Badge("\(PresentationText.ciFailureMark) \(failed.first ?? "CI \(total)")", .negative)
        }
    }

    private static func latestVerdicts(_ reviews: [Review], excluding viewer: String) -> [ReviewState] {
        let relevant = reviews
            .filter { $0.author != viewer && ($0.state == .approved || $0.state == .changesRequested) }
            .sorted { $0.submittedAt < $1.submittedAt }
        var latest: [String: ReviewState] = [:]
        for review in relevant { latest[review.author] = review.state }
        return Array(latest.values)
    }
}
