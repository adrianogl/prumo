import Foundation

public struct PendingRun: Sendable, Codable, Equatable {
    public let id: Int
    public let since: Date

    public init(id: Int, since: Date) {
        self.id = id
        self.since = since
    }
}
