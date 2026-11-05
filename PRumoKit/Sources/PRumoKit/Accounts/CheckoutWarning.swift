public enum CheckoutWarning {
    public static func text(account: Account?, activeLogin: String?, accountCount: Int) -> String? {
        guard accountCount > 1, let account else { return nil }
        guard let activeLogin else {
            return "O gh não está logado. Rode gh auth login antes de colar o comando."
        }
        if activeLogin.caseInsensitiveCompare(account.login) == .orderedSame { return nil }
        return "A conta ativa do gh é @\(activeLogin). Rode gh auth switch --user \(account.login) antes de colar o comando."
    }
}
