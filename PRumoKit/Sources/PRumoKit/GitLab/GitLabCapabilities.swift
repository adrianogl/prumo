public struct GitLabCapabilities: Codable, Equatable, Sendable {
    public var hasReviewState: Bool
    public var hasDetailedMergeStatus: Bool

    public init(hasReviewState: Bool, hasDetailedMergeStatus: Bool) {
        self.hasReviewState = hasReviewState
        self.hasDetailedMergeStatus = hasDetailedMergeStatus
    }

    public static let minimal = GitLabCapabilities(hasReviewState: false, hasDetailedMergeStatus: false)

    private enum CodingKeys: String, CodingKey {
        case hasReviewState, hasDetailedMergeStatus
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        hasReviewState = try container.decodeIfPresent(Bool.self, forKey: .hasReviewState) ?? false
        hasDetailedMergeStatus = try container.decodeIfPresent(Bool.self, forKey: .hasDetailedMergeStatus) ?? false
    }
}
