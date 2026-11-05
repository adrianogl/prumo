public struct RowFilter: Codable, Equatable, Sendable {
    public var repositories: Set<String>
    public var ci: Set<CIFilter>
    public var review: Set<ReviewFilter>
    public var state: Set<StateFilter>
    public var request: Set<RequestFilter>
    public var authors: Set<String>

    public static let empty = RowFilter()

    public var criteriaCount: Int {
        ci.count + review.count + state.count + request.count + authors.count
    }

    public init(
        repositories: Set<String> = [],
        ci: Set<CIFilter> = [],
        review: Set<ReviewFilter> = [],
        state: Set<StateFilter> = [],
        request: Set<RequestFilter> = [],
        authors: Set<String> = []
    ) {
        self.repositories = repositories
        self.ci = ci
        self.review = review
        self.state = state
        self.request = request
        self.authors = authors
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        repositories = c.decodeLossy(Set<String>.self, forKey: .repositories, default: [])
        ci = c.decodeLossySet(CIFilter.self, forKey: .ci)
        review = c.decodeLossySet(ReviewFilter.self, forKey: .review)
        state = c.decodeLossySet(StateFilter.self, forKey: .state)
        request = c.decodeLossySet(RequestFilter.self, forKey: .request)
        authors = c.decodeLossy(Set<String>.self, forKey: .authors, default: [])
    }
}
