import Foundation

public struct Snapshot: Sendable, Codable, Equatable {
    public let viewer: String
    public let mine: [PullRequest]
    public let toReview: [PullRequest]
    public let mergedToday: [MergedPullRequest]
    public let fetchedAt: Date
    public let accountViewers: [String: String]

    public init(
        viewer: String,
        mine: [PullRequest],
        toReview: [PullRequest],
        mergedToday: [MergedPullRequest] = [],
        fetchedAt: Date,
        accountViewers: [String: String] = [:]
    ) {
        self.viewer = viewer
        self.mine = mine
        self.toReview = toReview
        self.mergedToday = mergedToday
        self.fetchedAt = fetchedAt
        self.accountViewers = accountViewers
    }

    private enum CodingKeys: String, CodingKey {
        case viewer, mine, toReview, mergedToday, fetchedAt, accountViewers
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        viewer = try container.decode(String.self, forKey: .viewer)
        mine = try container.decode([PullRequest].self, forKey: .mine)
        toReview = try container.decode([PullRequest].self, forKey: .toReview)
        mergedToday = try container.decodeIfPresent([MergedPullRequest].self, forKey: .mergedToday) ?? []
        fetchedAt = try container.decode(Date.self, forKey: .fetchedAt)
        accountViewers = container.decodeLossyDictionary(String.self, forKey: .accountViewers)
    }

    public func viewer(for pr: PullRequest) -> String {
        accountViewers[pr.accountID] ?? viewer
    }

    public func stamped(accountID: String) -> Snapshot {
        Snapshot(
            viewer: viewer,
            mine: mine.map { $0.with(accountID: accountID) },
            toReview: toReview.map { $0.with(accountID: accountID) },
            mergedToday: mergedToday.map {
                MergedPullRequest(
                    id: $0.id, number: $0.number, title: $0.title, url: $0.url, repository: $0.repository,
                    mergedAt: $0.mergedAt, accountID: accountID
                )
            },
            fetchedAt: fetchedAt,
            accountViewers: [accountID: viewer]
        )
    }

    public func keepingKnownMergeable(from old: Snapshot?) -> Snapshot {
        guard let old else { return self }
        return Snapshot(
            viewer: viewer,
            mine: Self.inheriting(mine, from: old.mine),
            toReview: Self.inheriting(toReview, from: old.toReview),
            mergedToday: mergedToday,
            fetchedAt: fetchedAt,
            accountViewers: accountViewers
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
