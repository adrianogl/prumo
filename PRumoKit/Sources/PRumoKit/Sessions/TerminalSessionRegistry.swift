import Foundation

public struct TerminalSessionRegistry: Equatable, Sendable {
    public private(set) var sessions: [TerminalSessionInfo] = []
    public private(set) var focusedID: UUID?

    public init() {}

    public var focused: TerminalSessionInfo? {
        focusedID.flatMap(session(id:))
    }

    public var hasLiveSessions: Bool {
        sessions.contains { $0.status.isAlive }
    }

    public func session(id: UUID) -> TerminalSessionInfo? {
        sessions.first { $0.id == id }
    }

    public func session(forPullRequest pullRequestID: String) -> TerminalSessionInfo? {
        sessions.first { $0.pullRequestID == pullRequestID }
    }

    public func decision(forPullRequest pullRequestID: String, purpose: SessionPurpose) -> SessionOpenDecision {
        guard let existing = session(forPullRequest: pullRequestID), existing.status.isAlive else { return .create }
        return existing.purpose == purpose ? .focus(existing.id) : .askToReplace(existing.id)
    }

    public mutating func add(_ session: TerminalSessionInfo) {
        sessions.removeAll { $0.pullRequestID == session.pullRequestID }
        sessions.append(session)
        focusedID = session.id
    }

    public mutating func focus(_ id: UUID) {
        guard let index = index(of: id) else { return }
        focusedID = id
        if sessions[index].status == .attention { sessions[index].status = .running }
    }

    public mutating func focus(pullRequest pullRequestID: String) {
        guard let id = session(forPullRequest: pullRequestID)?.id else { return }
        focus(id)
    }

    public mutating func bell(_ id: UUID) {
        guard let index = index(of: id), sessions[index].status == .running, focusedID != id else { return }
        sessions[index].status = .attention
    }

    public mutating func exited(_ id: UUID, code: Int32) {
        guard let index = index(of: id) else { return }
        sessions[index].status = .exited(code: code)
    }

    public mutating func close(_ id: UUID) {
        guard let index = index(of: id) else { return }
        sessions.remove(at: index)
        guard focusedID == id else { return }
        focusedID = sessions.isEmpty ? nil : sessions[min(index, sessions.count - 1)].id
    }

    public func next(after id: UUID?) -> UUID? {
        guard !sessions.isEmpty else { return nil }
        guard let id, let index = index(of: id) else { return sessions[0].id }
        return sessions[(index + 1) % sessions.count].id
    }

    private func index(of id: UUID) -> Int? {
        sessions.firstIndex { $0.id == id }
    }
}
