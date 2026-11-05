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
        includeTeamRequests: Bool = false,
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
        filter = try c.decodeIfPresent(RowFilter.self, forKey: .filter) ?? .empty
        orderings = try c.decodeIfPresent([String: TabOrdering].self, forKey: .orderings) ?? [:]
        views = try c.decodeIfPresent([SavedView].self, forKey: .views) ?? []
        favorites = try c.decodeIfPresent(Set<String>.self, forKey: .favorites) ?? []
        knownRepositories = try c.decodeIfPresent(Set<String>.self, forKey: .knownRepositories) ?? []
        hideEmptyRepositories = try c.decodeIfPresent(Bool.self, forKey: .hideEmptyRepositories) ?? false
        rowStyle = try c.decodeIfPresent(RowStyle.self, forKey: .rowStyle) ?? .detailed
        ignoreDraftsInReview = try c.decodeIfPresent(Bool.self, forKey: .ignoreDraftsInReview) ?? true
        includeTeamRequests = try c.decodeIfPresent(Bool.self, forKey: .includeTeamRequests) ?? false
        marks = try c.decodeIfPresent(RowMarks.self, forKey: .marks) ?? RowMarks()
    }

    public func ordering(for tab: ListTab) -> TabOrdering {
        orderings[tab.rawValue] ?? TabOrdering()
    }

    public mutating func setOrdering(_ ordering: TabOrdering, for tab: ListTab) {
        orderings[tab.rawValue] = ordering
    }
}
