public struct Account: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public var provider: ProviderKind
    public var host: String
    public var login: String
    public var nickname: String
    public var origin: TokenOrigin

    public init(
        id: String,
        provider: ProviderKind = .github,
        host: String = AccountConstants.githubHost,
        login: String,
        nickname: String = "",
        origin: TokenOrigin
    ) {
        self.id = id
        self.provider = provider
        self.host = host
        self.login = login
        self.nickname = nickname
        self.origin = origin
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        provider = try c.decode(ProviderKind.self, forKey: .provider)
        login = try c.decode(String.self, forKey: .login)
        host = c.decodeLossy(String.self, forKey: .host, default: AccountConstants.githubHost)
        nickname = c.decodeLossy(String.self, forKey: .nickname, default: "")
        origin = c.decodeLossy(TokenOrigin.self, forKey: .origin, default: .pasted)
    }

    public var displayName: String {
        nickname.isEmpty ? "@\(login)" : "\(nickname) · @\(login)"
    }

    public var isPublicHost: Bool {
        AccountConstants.publicHosts.contains(host.lowercased())
    }

    public func isSameIdentity(as other: Account) -> Bool {
        provider == other.provider
            && host.caseInsensitiveCompare(other.host) == .orderedSame
            && login.caseInsensitiveCompare(other.login) == .orderedSame
    }
}
