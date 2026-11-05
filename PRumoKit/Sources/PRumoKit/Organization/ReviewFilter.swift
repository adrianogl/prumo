public enum ReviewFilter: String, Codable, CaseIterable, Sendable {
    case approved, changesRequested, noReview
}
