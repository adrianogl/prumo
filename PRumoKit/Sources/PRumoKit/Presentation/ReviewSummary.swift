public struct ReviewSummary: Equatable, Sendable {
    public let approvals: Int
    public let hasChangesRequested: Bool

    public init(_ pr: PullRequest, viewer: String) {
        let relevant = pr.reviews
            .filter { $0.author != viewer && ($0.state == .approved || $0.state == .changesRequested) }
            .sorted { $0.submittedAt < $1.submittedAt }
        var latest: [String: ReviewState] = [:]
        for review in relevant { latest[review.author] = review.state }
        let verdicts = Array(latest.values)
        approvals = verdicts.filter { $0 == .approved }.count
        hasChangesRequested = verdicts.contains(.changesRequested)
    }
}
