public struct AccountTokenResolver: Sendable {
    private let tokenStore: @Sendable (String) -> TokenStore
    private let gh: GhAccountDiscovery
    private let glab: GlabAccountDiscovery

    public init(tokenStore: @escaping @Sendable (String) -> TokenStore, gh: GhAccountDiscovery, glab: GlabAccountDiscovery) {
        self.tokenStore = tokenStore
        self.gh = gh
        self.glab = glab
    }

    public func token(for account: Account) async -> String? {
        let token: String?
        switch account.origin {
        case .pasted: token = tokenStore(account.id).read()
        case .ghCLI: token = await gh.token(for: account.login)
        case .glabCLI: token = await glab.token(host: account.host)
        }
        guard let token, !token.isEmpty else { return nil }
        return token
    }
}
