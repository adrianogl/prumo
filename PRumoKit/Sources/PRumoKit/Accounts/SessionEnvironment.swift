public enum SessionEnvironment {
    public static func variables(provider: ProviderKind, host: String, token: String) -> [String: String] {
        switch provider {
        case .github:
            return ["GH_TOKEN": token]
        }
    }
}
