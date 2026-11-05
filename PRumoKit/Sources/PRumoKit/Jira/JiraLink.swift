import Foundation

public struct JiraLink: Equatable, Sendable {
    public let key: String
    public let url: URL?

    public init(key: String, url: URL?) {
        self.key = key
        self.url = url
    }
}
