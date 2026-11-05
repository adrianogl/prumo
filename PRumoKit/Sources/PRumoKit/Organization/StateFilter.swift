public enum StateFilter: String, Codable, CaseIterable, Sendable {
    case noDrafts, conflicting, newActivity, pinned
}
