import Foundation

public struct FilterContext: Sendable {
    public let viewer: String
    public let viewers: [String: String]
    public let marks: RowMarks
    public let unseen: Set<String>
    public let staleLimit: TimeInterval
    public let now: Date

    public init(
        viewer: String,
        viewers: [String: String] = [:],
        marks: RowMarks = RowMarks(),
        unseen: Set<String> = [],
        staleLimit: TimeInterval = OrganizationConstants.defaultStaleLimit,
        now: Date
    ) {
        self.viewer = viewer
        self.viewers = viewers
        self.marks = marks
        self.unseen = unseen
        self.staleLimit = staleLimit
        self.now = now
    }

    public func viewer(for pr: PullRequest) -> String {
        viewers[pr.accountID] ?? viewer
    }
}
