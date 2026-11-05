public struct TokenResolver: Sendable {
    private let store: TokenStore
    private let gh: GhCLITokenSource

    public init(store: TokenStore, gh: GhCLITokenSource) {
        self.store = store
        self.gh = gh
    }

    public func resolve() async -> (token: String, origin: TokenOrigin)? {
        if let stored = store.read(), !stored.isEmpty {
            return (stored, .pasted)
        }
        if let token = await gh.token() {
            return (token, .ghCLI)
        }
        return nil
    }
}
