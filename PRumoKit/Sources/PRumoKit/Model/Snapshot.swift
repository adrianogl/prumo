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

    public func keepingKnownMergeable(from old: Snapshot?) -> Snapshot {
        guard let old else { return self }
        return Snapshot(
            viewer: viewer,
            mine: Self.inheriting(mine, from: old.mine),
            toReview: Self.inheriting(toReview, from: old.toReview),
            mergedToday: mergedToday,
            fetchedAt: fetchedAt
        )
    }

    private static func inheriting(_ prs: [PullRequest], from old: [PullRequest]) -> [PullRequest] {
        let known = Dictionary(old.filter { $0.mergeable != .unknown }.map { ($0.id, $0.mergeable) }, uniquingKeysWith: { first, _ in first })
        return prs.map { pr in
            guard pr.mergeable == .unknown, let value = known[pr.id] else { return pr }
            return pr.with(mergeable: value)
        }
    }
}
