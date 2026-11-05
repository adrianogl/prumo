import Foundation

public struct ReminderState: Codable, Equatable, Sendable {
    public var initialized = false
    public var reminded: [String] = []

    public init(initialized: Bool = false, reminded: [String] = []) {
        self.initialized = initialized
        self.reminded = reminded
    }

    private enum CodingKeys: String, CodingKey {
        case initialized, reminded
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        initialized = container.decodeLossy(Bool.self, forKey: .initialized, default: false)
        reminded = container.decodeLossy([String].self, forKey: .reminded, default: [])
    }

    public mutating func insert(_ keys: [String]) {
        for key in keys where !reminded.contains(key) {
            reminded.append(key)
        }
        if reminded.count > ReminderConstants.maxKeys {
            reminded.removeFirst(reminded.count - ReminderConstants.maxKeys)
        }
    }
}
