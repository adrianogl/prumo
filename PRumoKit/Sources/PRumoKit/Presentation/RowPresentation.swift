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
    public let commentsBadgeIndex: Int?
    public let jiraBadgeIndex: Int?
    public let accountProvider: ProviderKind?

    public init(
        dot: StatusDot, title: String, subtitle: String, badges: [Badge],
        ciFailureBadgeIndex: Int? = nil, conflictBadgeIndex: Int? = nil,
        commentsBadgeIndex: Int? = nil, jiraBadgeIndex: Int? = nil, accountProvider: ProviderKind? = nil
    ) {
        self.dot = dot
        self.title = title
        self.subtitle = subtitle
        self.badges = badges
        self.ciFailureBadgeIndex = ciFailureBadgeIndex
        self.conflictBadgeIndex = conflictBadgeIndex
        self.commentsBadgeIndex = commentsBadgeIndex
        self.jiraBadgeIndex = jiraBadgeIndex
        self.accountProvider = accountProvider
    }
}

public enum RowPresenter {
    public static func mine(
        _ pr: PullRequest, viewer: String, now: Date, jiraKey: String? = nil, commentFilter: CommentAuthorFilter = .none,
        account: AccountLabel? = nil, staleSince: Date? = nil
    ) -> RowPresentation {
        let summary = ReviewSummary(pr, viewer: viewer)
        let approvals = summary.approvals
        let hasChangesRequested = summary.hasChangesRequested

        var badges: [Badge] = []
        var ciFailureIndex: Int?
        if let ci = ciBadge(pr.ci) {
            if case .failure = pr.ci { ciFailureIndex = badges.count }
            badges.append(ci)
        }
        if approvals > 0 {
            badges.append(approvalsBadge(approvals))
        }
        var changesRequestedIndex: Int?
        if hasChangesRequested {
            changesRequestedIndex = badges.count
            badges.append(Badge(PresentationText.changesRequested, .negative))
        }
        if pr.isDraft { badges.append(Badge(PresentationText.draft, .neutral)) }
        var conflictIndex: Int?
        if pr.mergeable == .conflicting {
            conflictIndex = badges.count
            badges.append(Badge(PresentationText.conflict, .warning, .conflict))
        }
        let commentTotal = commentFilter.commentTotal(pr)
        var commentsIndex = changesRequestedIndex
        if commentTotal > 0 {
            commentsIndex = badges.count
            badges.append(Badge(String(commentTotal), .neutral, .comments))
        }
        var jiraIndex: Int?
        if let jiraKey {
            jiraIndex = badges.count
            badges.append(Badge(jiraKey, .neutral))
        }

        return RowPresentation(
            dot: dot(ci: pr.ci, hasChangesRequested: hasChangesRequested),
            title: pr.title,
            subtitle: subtitle(pr, from: pr.createdAt, now: now, account: account, staleSince: staleSince),
            badges: badges,
            ciFailureBadgeIndex: ciFailureIndex,
            conflictBadgeIndex: conflictIndex,
            commentsBadgeIndex: commentsIndex,
            jiraBadgeIndex: jiraIndex,
            accountProvider: account?.provider
        )
    }

    public static func review(
        _ pr: PullRequest, now: Date, jiraKey: String? = nil, staleLimit: TimeInterval? = nil,
        account: AccountLabel? = nil, staleSince: Date? = nil
    ) -> RowPresentation {
        let requestedAt = pr.reviewRequestedAt ?? pr.createdAt
        let waited = now.timeIntervalSince(requestedAt)
        let isStale = staleLimit.map { waited >= $0 } ?? false
        var badges = [requestBadge(pr.reviewTarget), Badge(pr.author, .neutral)]
        if isStale {
            let hours = Int(waited / PresentationMetrics.secondsPerHour)
            badges.append(Badge("\(PresentationText.waitingPrefix) \(hours)h", .warning, .clock))
        }
        if let ci = ciBadge(pr.ci) { badges.append(ci) }
        badges.append(Badge("+\(pr.additions) \(PresentationText.minus)\(pr.deletions)", .neutral))
        var jiraIndex: Int?
        if let jiraKey {
            jiraIndex = badges.count
            badges.append(Badge(jiraKey, .neutral))
        }

        return RowPresentation(
            dot: dot(ci: pr.ci, hasChangesRequested: isStale),
            title: pr.title,
            subtitle: subtitle(pr, from: requestedAt, now: now, account: account, staleSince: staleSince),
            badges: badges,
            jiraBadgeIndex: jiraIndex,
            accountProvider: account?.provider
        )
    }

    public static func merge(
        _ pr: PullRequest, viewer: String, now: Date, jiraKey: String? = nil,
        account: AccountLabel? = nil, staleSince: Date? = nil
    ) -> RowPresentation {
        let summary = ReviewSummary(pr, viewer: viewer)
        var badges: [Badge] = []
        if let ci = ciBadge(pr.ci) { badges.append(ci) }
        if summary.approvals > 0 { badges.append(approvalsBadge(summary.approvals)) }
        badges.append(Badge(PresentationText.noConflict, .positive))
        var jiraIndex: Int?
        if let jiraKey {
            jiraIndex = badges.count
            badges.append(Badge(jiraKey, .neutral))
        }

        return RowPresentation(
            dot: dot(ci: pr.ci, hasChangesRequested: false),
            title: pr.title,
            subtitle: subtitle(pr, from: pr.createdAt, now: now, account: account, staleSince: staleSince),
            badges: badges,
            jiraBadgeIndex: jiraIndex,
            accountProvider: account?.provider
        )
    }

    public static func compactLine(
        _ pr: PullRequest, tab: ListTab, viewer: String, now: Date, account: AccountLabel? = nil
    ) -> String {
        let repo = pr.repository.split(separator: "/").last.map(String.init) ?? pr.repository
        var parts = [account?.text, "\(repo) #\(pr.number)"].compactMap { $0 }
        switch tab {
        case .review:
            parts.append(pr.author)
            switch pr.reviewTarget {
            case .you: parts.append(PresentationText.forYou)
            case let .team(name): parts.append("\(PresentationText.teamPrefix) \(name)")
            }
            parts.append(RelativeAge.string(from: pr.reviewRequestedAt ?? pr.createdAt, now: now))
        case .mine, .merge:
            let summary = ReviewSummary(pr, viewer: viewer)
            if summary.hasChangesRequested {
                parts.append(PresentationText.changesRequested)
            } else if summary.approvals > 0 {
                parts.append(PresentationText.approved)
            } else {
                parts.append(PresentationText.noReview)
            }
            switch pr.ci {
            case .none: break
            case .success: parts.append(PresentationText.ciOk)
            case .pending: parts.append(PresentationText.ciRunning)
            case .failure: parts.append(PresentationText.ciFailed)
            }
            if pr.mergeable == .conflicting { parts.append(PresentationText.conflict) }
            if pr.isDraft { parts.append(PresentationText.draft) }
            parts.append(RelativeAge.string(from: pr.createdAt, now: now))
        }
        return parts.joined(separator: PresentationText.separator)
    }

    private static func subtitle(
        _ pr: PullRequest, from: Date, now: Date, account: AccountLabel?, staleSince: Date?
    ) -> String {
        let age = staleSince.map {
            "\(PresentationText.lastDataPrefix) \(RelativeAge.string(from: $0, now: now)) \(PresentationText.lastDataSuffix)"
        } ?? RelativeAge.string(from: from, now: now)
        let parts = [account?.text, "\(pr.repository) #\(pr.number)", age].compactMap { $0 }
        return parts.joined(separator: PresentationText.separator)
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

    private static func approvalsBadge(_ approvals: Int) -> Badge {
        let noun = approvals == 1 ? PresentationText.approvalSingular : PresentationText.approvalPlural
        return Badge("\(PresentationText.approvalMark) \(approvals) \(noun)", .positive)
    }

    private static func requestBadge(_ target: ReviewRequestTarget) -> Badge {
        switch target {
        case .you: Badge(PresentationText.forYou, .accent)
        case let .team(name): Badge("\(PresentationText.teamPrefix) \(name)", .neutral)
        }
    }
}
