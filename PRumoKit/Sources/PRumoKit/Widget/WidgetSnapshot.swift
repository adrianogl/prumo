import Foundation

public struct WidgetSnapshot: Codable, Equatable, Sendable {
    public var connected: Bool
    public var toReview: Int
    public var ciFailing: Int
    public var readyToMerge: Int
    public var items: [WidgetItem]
    public var updatedAt: Date

    public init(
        connected: Bool = true, toReview: Int = 0, ciFailing: Int = 0, readyToMerge: Int = 0,
        items: [WidgetItem] = [], updatedAt: Date = Date(timeIntervalSince1970: 0)
    ) {
        self.connected = connected
        self.toReview = toReview
        self.ciFailing = ciFailing
        self.readyToMerge = readyToMerge
        self.items = items
        self.updatedAt = updatedAt
    }

    public static let disconnected = WidgetSnapshot(connected: false)

    private enum CodingKeys: String, CodingKey {
        case connected, toReview, ciFailing, readyToMerge, items, updatedAt
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        connected = c.decodeLossy(Bool.self, forKey: .connected, default: true)
        toReview = c.decodeLossy(Int.self, forKey: .toReview, default: 0)
        ciFailing = c.decodeLossy(Int.self, forKey: .ciFailing, default: 0)
        readyToMerge = c.decodeLossy(Int.self, forKey: .readyToMerge, default: 0)
        items = c.decodeLossyArray(WidgetItem.self, forKey: .items)
        updatedAt = c.decodeLossy(Date.self, forKey: .updatedAt, default: Date(timeIntervalSince1970: 0))
    }
}
