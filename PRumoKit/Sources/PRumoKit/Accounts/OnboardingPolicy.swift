public enum OnboardingPolicy {
    public static func needsOnboarding(accounts: [Account], tokens: [String: String]) -> Bool {
        guard let first = accounts.first else { return true }
        return accounts.count == 1 && first.provider == .github && first.origin == .pasted && tokens[first.id] == nil
    }

    public static func onboardingReplacesAccounts(_ accounts: [Account]) -> Bool {
        accounts.count <= 1 && accounts.allSatisfy { $0.provider == .github }
    }

    public static func recovery(for account: Account) -> AccountRecovery {
        switch (account.provider, account.origin) {
        case (.github, _): .onboarding
        case (.gitlab, .glabCLI): .reconnect
        case (.gitlab, _): .settings
        }
    }
}
