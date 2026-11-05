public struct AccountPart: Equatable, Sendable {
    public let accountID: String
    public let snapshot: Snapshot

    public init(accountID: String, snapshot: Snapshot) {
        self.accountID = accountID
        self.snapshot = snapshot
    }
}
