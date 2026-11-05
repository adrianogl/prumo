import Foundation

public struct Snapshot: Sendable, Codable, Equatable {
    public let viewer: String
    public let mine: [PullRequest]
    public let toReview: [PullRequest]
    public let mergedToday: [MergedPullRequest]
    public let fetchedAt: Date

    public init(
        viewer: String,
        mine: [PullRequest],
        toReview: [PullRequest],
        mergedToday: [MergedPullRequest] = [],
        fetchedAt: Date
    ) {
        self.viewer = viewer
        self.mine = mine
        self.toReview = toReview
        self.mergedToday = mergedToday
        self.fetchedAt = fetchedAt
    }

    private enum CodingKeys: String, CodingKey {
        case viewer, mine, toReview, mergedToday, fetchedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        viewer = try container.decode(String.self, forKey: .viewer)
        mine = try container.decode([PullRequest].self, forKey: .mine)
        toReview = try container.decode([PullRequest].self, forKey: .toReview)
        mergedToday = try container.decodeIfPresent([MergedPullRequest].self, forKey: .mergedToday) ?? []
        fetchedAt = try container.decode(Date.self, forKey: .fetchedAt)
    }
}
