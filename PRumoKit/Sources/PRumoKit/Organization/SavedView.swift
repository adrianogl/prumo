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
}
