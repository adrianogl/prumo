import Foundation

public struct WidgetItem: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var number: Int
    public var title: String
    public var url: URL
    public var reason: WidgetReason
    public var waitingHours: Int?

    public init(id: String, number: Int, title: String, url: URL, reason: WidgetReason, waitingHours: Int? = nil) {
        self.id = id
        self.number = number
        self.title = title
        self.url = url
        self.reason = reason
        self.waitingHours = waitingHours
    }
}
