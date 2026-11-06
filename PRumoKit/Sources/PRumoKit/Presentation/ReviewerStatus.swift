public enum ReviewerStatus {
    public static func latest(_ reviews: [Review]) -> [Review] {
        var latest: [String: Review] = [:]
        for review in reviews where review.state != .pending && review.state != .commented {
            if let current = latest[review.author], current.submittedAt >= review.submittedAt { continue }
            latest[review.author] = review
        }
        return latest.values.sorted { $0.submittedAt > $1.submittedAt }
    }
}
