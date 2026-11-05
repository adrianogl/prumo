import Foundation

public enum ConnectionState: Equatable, Sendable {
    case ok
    case offline(lastSuccess: Date?)
    case unauthorized
    case rateLimited(resetAt: Date?)
    case unexpectedResponse(lastSuccess: Date?)
}
