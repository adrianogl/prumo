public enum CheckoutWarning {
    public static func text(account: Account?, activeLogin: String?, accountCount: Int) -> String? {
        guard accountCount > 1, let account else { return nil }
        if activeLogin?.caseInsensitiveCompare(account.login) == .orderedSame { return nil }
        switch account.provider {
        case .github: return githubText(account: account, activeLogin: activeLogin)
        case .gitlab: return gitlabText(account: account, activeLogin: activeLogin)
        }
    }

    private static func githubText(account: Account, activeLogin: String?) -> String {
        guard let activeLogin else {
            return "O gh não está logado. Rode gh auth login antes de colar o comando."
        }
        return "A conta ativa do gh é @\(activeLogin). Rode gh auth switch --user \(account.login) antes de colar o comando."
    }

    private static func gitlabText(account: Account, activeLogin: String?) -> String {
        guard let activeLogin else {
            return "O glab não está logado em \(account.host). Rode glab auth login --hostname \(account.host) antes de colar o comando."
        }
        return "O glab está logado em \(account.host) como @\(activeLogin). Rode glab auth login --hostname \(account.host) com o token de @\(account.login) antes de colar o comando."
    }
}
