public struct NotificationPreferences: Codable, Equatable, Sendable {
    public var disabled: Set<NotificationToggle>
    public var groupByPullRequest: Bool
    public var staleReviewHours: Int
    public var dnd: DoNotDisturb
    public var workingHours: WorkingHours

    public init(
        disabled: Set<NotificationToggle> = [],
        groupByPullRequest: Bool = true,
        staleReviewHours: Int = 24,
        dnd: DoNotDisturb = .off,
        workingHours: WorkingHours = WorkingHours()
    ) {
        self.disabled = disabled
        self.groupByPullRequest = groupByPullRequest
        self.staleReviewHours = staleReviewHours
        self.dnd = dnd
        self.workingHours = workingHours
    }

    private enum CodingKeys: String, CodingKey {
        case disabled, groupByPullRequest, staleReviewHours, dnd, workingHours
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = NotificationPreferences()
        disabled = c.decodeLossySet(NotificationToggle.self, forKey: .disabled)
        groupByPullRequest = c.decodeLossy(Bool.self, forKey: .groupByPullRequest, default: defaults.groupByPullRequest)
        staleReviewHours = c.decodeLossy(Int.self, forKey: .staleReviewHours, default: defaults.staleReviewHours)
        dnd = c.decodeLossy(DoNotDisturb.self, forKey: .dnd, default: defaults.dnd)
        workingHours = c.decodeLossy(WorkingHours.self, forKey: .workingHours, default: defaults.workingHours)
    }

    public func isEnabled(_ kind: NotificationKind) -> Bool {
        !disabled.contains(NotificationToggle(kind: kind))
    }
}
