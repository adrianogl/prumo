import Foundation

public struct AccountStatus: Equatable, Sendable {
    public var state: ConnectionState?
    public var lastSuccess: Date?

    public var isProblem: Bool {
        guard let state else { return false }
        return state != .ok
    }

    public init(state: ConnectionState? = nil, lastSuccess: Date? = nil) {
        self.state = state
        self.lastSuccess = lastSuccess
    }
}
