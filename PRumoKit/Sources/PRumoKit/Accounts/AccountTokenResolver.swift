public struct AccountTokenResolver: Sendable {
    private let tokenStore: @Sendable (String) -> TokenStore
    private let gh: GhAccountDiscovery

    public init(tokenStore: @escaping @Sendable (String) -> TokenStore, gh: GhAccountDiscovery) {
        self.tokenStore = tokenStore
        self.gh = gh
    }

    public func token(for account: Account) async -> String? {
        let token: String?
        switch account.origin {
        case .pasted: token = tokenStore(account.id).read()
        case .ghCLI: token = await gh.token(for: account.login)
        case .glabCLI: token = nil
        }
        guard let token, !token.isEmpty else { return nil }
        return token
    }
}
