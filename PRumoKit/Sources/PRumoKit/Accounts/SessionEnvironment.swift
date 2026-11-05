public enum SessionEnvironment {
    public static func variables(provider: ProviderKind, host: String, token: String, isOAuth: Bool) -> [String: String] {
        switch provider {
        case .github:
            return ["GH_TOKEN": token]
        case .gitlab:
            return [isOAuth ? "OAUTH_TOKEN" : "GITLAB_TOKEN": token, "GITLAB_HOST": "https://\(host)"]
        }
    }
}
