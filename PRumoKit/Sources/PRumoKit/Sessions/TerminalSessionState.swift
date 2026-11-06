import Foundation

public enum TerminalSessionStatus: Equatable, Sendable {
    case running
    case attention
    case exited(code: Int32)

    public var isAlive: Bool {
        if case .exited = self { return false }
        return true
    }
}

public struct TerminalSessionInfo: Equatable, Sendable, Identifiable {
    public let id: UUID
    public let pullRequestID: String
    public let reference: String
    public let purpose: SessionPurpose
    public let directory: URL
    public let startedAt: Date
    public internal(set) var status: TerminalSessionStatus

    public init(
        id: UUID = UUID(), pullRequestID: String, reference: String, purpose: SessionPurpose,
        directory: URL, startedAt: Date, status: TerminalSessionStatus = .running
    ) {
        self.id = id
        self.pullRequestID = pullRequestID
        self.reference = reference
        self.purpose = purpose
        self.directory = directory
        self.startedAt = startedAt
        self.status = status
    }
}

public enum SessionOpenDecision: Equatable, Sendable {
    case create
    case focus(UUID)
    case askToReplace(UUID)
}
