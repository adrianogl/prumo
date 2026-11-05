public struct OrganizationSettings: Codable, Equatable, Sendable {
    public var filter: RowFilter
    public var orderings: [String: TabOrdering]
    public var views: [SavedView]
    public var favorites: Set<String>
    public var knownRepositories: Set<String>
    public var hideEmptyRepositories: Bool
    public var rowStyle: RowStyle
    public var ignoreDraftsInReview: Bool
    public var includeTeamRequests: Bool
    public var marks: RowMarks

    public static let defaults = OrganizationSettings()

    public init(
        filter: RowFilter = .empty,
        orderings: [String: TabOrdering] = [:],
        views: [SavedView] = [],
        favorites: Set<String> = [],
        knownRepositories: Set<String> = [],
        hideEmptyRepositories: Bool = false,
        rowStyle: RowStyle = .detailed,
        ignoreDraftsInReview: Bool = true,
        includeTeamRequests: Bool = true,
        marks: RowMarks = RowMarks()
    ) {
        self.filter = filter
        self.orderings = orderings
        self.views = views
        self.favorites = favorites
        self.knownRepositories = knownRepositories
        self.hideEmptyRepositories = hideEmptyRepositories
        self.rowStyle = rowStyle
        self.ignoreDraftsInReview = ignoreDraftsInReview
        self.includeTeamRequests = includeTeamRequests
        self.marks = marks
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        filter = c.decodeLossy(RowFilter.self, forKey: .filter, default: .empty)
        orderings = c.decodeLossyDictionary(TabOrdering.self, forKey: .orderings)
        views = c.decodeLossyArray(SavedView.self, forKey: .views)
        favorites = c.decodeLossy(Set<String>.self, forKey: .favorites, default: [])
        knownRepositories = c.decodeLossy(Set<String>.self, forKey: .knownRepositories, default: [])
        hideEmptyRepositories = c.decodeLossy(Bool.self, forKey: .hideEmptyRepositories, default: false)
        rowStyle = c.decodeLossy(RowStyle.self, forKey: .rowStyle, default: .detailed)
        ignoreDraftsInReview = c.decodeLossy(Bool.self, forKey: .ignoreDraftsInReview, default: true)
        includeTeamRequests = c.decodeLossy(Bool.self, forKey: .includeTeamRequests, default: true)
        marks = c.decodeLossy(RowMarks.self, forKey: .marks, default: RowMarks())
    }

    public func ordering(for tab: ListTab) -> TabOrdering {
        orderings[tab.rawValue] ?? TabOrdering()
    }

    public mutating func setOrdering(_ ordering: TabOrdering, for tab: ListTab) {
        orderings[tab.rawValue] = ordering
    }
}
