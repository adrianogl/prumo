import Foundation

public enum ReviewState: String, Sendable, Codable, Equatable {
    case approved = "APPROVED"
    case changesRequested = "CHANGES_REQUESTED"
    case commented = "COMMENTED"
    case dismissed = "DISMISSED"
    case pending = "PENDING"
}

public struct Review: Sendable, Codable, Equatable {
    public let id: String
    public let author: String
    public let state: ReviewState
    public let submittedAt: Date

    public init(id: String, author: String, state: ReviewState, submittedAt: Date) {
        self.id = id
        self.author = author
        self.state = state
        self.submittedAt = submittedAt
    }
}
