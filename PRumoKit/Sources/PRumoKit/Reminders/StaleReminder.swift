public struct StaleReminder: Equatable, Sendable {
    public let key: String
    public let event: NotificationEvent

    public init(key: String, event: NotificationEvent) {
        self.key = key
        self.event = event
    }
}
