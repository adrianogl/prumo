import Foundation

public enum CheckState: String, Sendable, Codable, Equatable {
    case success
    case failure
    case running
    case pending
    case skipped
}

public struct CheckRun: Sendable, Codable, Equatable, Identifiable {
    public let name: String
    public let state: CheckState
    public let startedAt: Date?
    public let completedAt: Date?
    public let url: URL?

    public var id: String { name }

    public var duration: TimeInterval? {
        guard let startedAt, let completedAt, completedAt >= startedAt else { return nil }
        return completedAt.timeIntervalSince(startedAt)
    }

    public init(name: String, state: CheckState, startedAt: Date? = nil, completedAt: Date? = nil, url: URL? = nil) {
        self.name = name
        self.state = state
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.url = url
    }
}
