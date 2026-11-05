public struct PipelineResult: Equatable, Sendable {
    public let deliver: [NotificationEvent]
    public let reminders: ReminderState

    public init(deliver: [NotificationEvent], reminders: ReminderState) {
        self.deliver = deliver
        self.reminders = reminders
    }
}
