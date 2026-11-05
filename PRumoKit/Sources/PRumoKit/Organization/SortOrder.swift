public enum SortOrder: String, Codable, CaseIterable, Sendable {
    case recentActivity, needsActionFirst, oldestFirst, newestFirst, repository, diffSize
}
