public enum BadgeTone: Equatable, Sendable {
    case positive, negative, pending, warning, neutral
}

public enum BadgeIcon: Equatable, Sendable {
    case none, comments, conflict, clock
}

public struct Badge: Equatable, Sendable {
    public let text: String
    public let tone: BadgeTone
    public let icon: BadgeIcon

    public init(_ text: String, _ tone: BadgeTone, _ icon: BadgeIcon = .none) {
        self.text = text
        self.tone = tone
        self.icon = icon
    }
}
