public struct TransitionOptions: Equatable, Sendable {
    public var ignoreDraftReviews: Bool
    public var includeTeamRequests: Bool
    public var ignoredCommentAuthors: Set<String>

    public init(ignoreDraftReviews: Bool = true, includeTeamRequests: Bool = true, ignoredCommentAuthors: Set<String> = []) {
        self.ignoreDraftReviews = ignoreDraftReviews
        self.includeTeamRequests = includeTeamRequests
        self.ignoredCommentAuthors = ignoredCommentAuthors
    }
}
