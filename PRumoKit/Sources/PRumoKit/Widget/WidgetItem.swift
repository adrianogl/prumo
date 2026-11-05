import Foundation

public struct WidgetItem: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var number: Int
    public var title: String
    public var url: URL
    public var reference: String
    public var reason: WidgetReason
    public var waitingHours: Int?

    public init(id: String, number: Int, title: String, url: URL, reference: String = "", reason: WidgetReason, waitingHours: Int? = nil) {
        self.id = id
        self.number = number
        self.title = title
        self.url = url
        self.reference = reference
        self.reason = reason
        self.waitingHours = waitingHours
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        number = try c.decode(Int.self, forKey: .number)
        title = try c.decode(String.self, forKey: .title)
        url = try c.decode(URL.self, forKey: .url)
        reason = try c.decode(WidgetReason.self, forKey: .reason)
        waitingHours = try c.decodeIfPresent(Int.self, forKey: .waitingHours)
        reference = c.decodeLossy(String.self, forKey: .reference, default: "")
    }
}
