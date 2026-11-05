import Foundation

public struct GlabAccount: Equatable, Sendable {
    public let host: String
    public let login: String?
    public let isOAuth: Bool
    public let expiresAt: Date?

    public init(host: String, login: String?, isOAuth: Bool = false, expiresAt: Date? = nil) {
        self.host = host
        self.login = login
        self.isOAuth = isOAuth
        self.expiresAt = expiresAt
    }
}
