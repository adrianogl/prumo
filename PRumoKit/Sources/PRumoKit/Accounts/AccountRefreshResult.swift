public struct AccountRefreshResult: Sendable {
    public let accountID: String
    public let snapshot: Snapshot?
    public let events: [NotificationEvent]
    public let state: ConnectionState

    public init(accountID: String, snapshot: Snapshot?, events: [NotificationEvent], state: ConnectionState) {
        self.accountID = accountID
        self.snapshot = snapshot
        self.events = events
        self.state = state
    }
}
