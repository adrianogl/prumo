public enum NotificationSubtitles {
    public static func make(accounts: [Account]) -> [String: String] {
        guard accounts.count > 1 else { return [:] }
        return Dictionary(uniqueKeysWithValues: accounts.map { ($0.id, AccountLabel.make($0).text) })
    }
}
