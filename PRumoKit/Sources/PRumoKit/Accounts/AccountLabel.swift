public struct AccountLabel: Equatable, Sendable {
    public let provider: ProviderKind
    public let text: String

    public static func make(_ account: Account) -> AccountLabel {
        let host = account.host.lowercased()
        let text = AccountConstants.publicHosts.contains(host) ? account.login : "\(account.login) · \(account.host)"
        return AccountLabel(provider: account.provider, text: text)
    }

    public static func forRow(accountID: String, accounts: [Account]) -> AccountLabel? {
        guard accounts.count > 1, let account = accounts.first(where: { $0.id == accountID }) else { return nil }
        return make(account)
    }
}
