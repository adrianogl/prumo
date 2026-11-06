import Foundation

public enum UpdateError: Error, Equatable {
    case network
    case rateLimited
    case server(status: Int)
    case unexpectedResponse
}
