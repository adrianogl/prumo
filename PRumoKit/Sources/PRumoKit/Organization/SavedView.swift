import Foundation

public struct SavedView: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var filter: RowFilter

    public init(id: UUID = UUID(), name: String, filter: RowFilter) {
        self.id = id
        self.name = name
        self.filter = filter
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = c.decodeLossy(String.self, forKey: .name, default: "")
        filter = c.decodeLossy(RowFilter.self, forKey: .filter, default: .empty)
    }
}
