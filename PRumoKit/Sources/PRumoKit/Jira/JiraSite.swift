import Foundation

public struct JiraSite: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var prefix: String
    public var host: String

    public init(id: UUID = UUID(), prefix: String, host: String) {
        self.id = id
        self.prefix = prefix
        self.host = host
    }
}
