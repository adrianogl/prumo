public enum ReviewRequestTarget: Codable, Equatable, Sendable {
    case you
    case team(name: String)
}
