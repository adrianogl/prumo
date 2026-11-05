public struct TransitionOptions: Equatable, Sendable {
    public var ignoreDraftReviews: Bool
    public var includeTeamRequests: Bool

    public init(ignoreDraftReviews: Bool = true, includeTeamRequests: Bool = true) {
        self.ignoreDraftReviews = ignoreDraftReviews
        self.includeTeamRequests = includeTeamRequests
    }
}
