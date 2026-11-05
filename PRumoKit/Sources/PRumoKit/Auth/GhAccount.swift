public struct GhAccount: Equatable, Sendable {
    public let host: String
    public let login: String
    public let isActive: Bool

    public init(host: String, login: String, isActive: Bool) {
        self.host = host
        self.login = login
        self.isActive = isActive
    }
}
