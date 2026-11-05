import Foundation

public struct Snapshot: Sendable, Codable, Equatable {
    public let viewer: String
    public let mine: [PullRequest]
    public let toReview: [PullRequest]
    public let fetchedAt: Date

    public init(viewer: String, mine: [PullRequest], toReview: [PullRequest], fetchedAt: Date) {
        self.viewer = viewer
        self.mine = mine
        self.toReview = toReview
        self.fetchedAt = fetchedAt
    }
}
