public struct TabOrdering: Codable, Equatable, Sendable {
    public var order: RowSortOrder
    public var groupByRepository: Bool

    public init(order: RowSortOrder = .recentActivity, groupByRepository: Bool = false) {
        self.order = order
        self.groupByRepository = groupByRepository
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        order = c.decodeLossy(RowSortOrder.self, forKey: .order, default: .recentActivity)
        groupByRepository = c.decodeLossy(Bool.self, forKey: .groupByRepository, default: false)
    }
}
