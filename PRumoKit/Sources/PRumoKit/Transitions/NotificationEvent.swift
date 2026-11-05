import Foundation

public enum NotificationKind: String, Codable, Sendable {
    case ciFailed, ciSucceeded, approved, changesRequested, newComment, reviewRequested
}

public struct NotificationEvent: Equatable, Sendable {
    public let kind: NotificationKind
    public let pullRequestID: String
    public let title: String
    public let body: String
    public let url: URL
    public let threadID: String
    public let failedRunID: Int?

    public init(kind: NotificationKind, pullRequestID: String, title: String, body: String, url: URL, failedRunID: Int? = nil) {
        self.kind = kind
        self.pullRequestID = pullRequestID
        self.title = title
        self.body = body
        self.url = url
        self.threadID = pullRequestID
        self.failedRunID = failedRunID
    }
}
