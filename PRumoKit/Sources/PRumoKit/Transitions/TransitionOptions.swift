public struct TransitionOptions: Equatable, Sendable {
    public var ignoreDraftReviews: Bool

    public init(ignoreDraftReviews: Bool = true) {
        self.ignoreDraftReviews = ignoreDraftReviews
    }
}
