public enum RowSortOrder: String, Codable, CaseIterable, Sendable {
    case recentActivity, needsActionFirst, oldestFirst, newestFirst, repository, diffSize
}
