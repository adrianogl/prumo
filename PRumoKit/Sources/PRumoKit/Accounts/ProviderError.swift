import Foundation

public enum ProviderError: Error, Equatable {
    case unauthorized
    case rateLimited(resetAt: Date?)
    case network
    case server(status: Int)
    case graphQL(messages: [String])
    case unexpectedResponse
}
