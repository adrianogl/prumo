import Foundation

public struct ReminderState: Codable, Equatable, Sendable {
    public var initialized = false
    public var reminded: [String] = []
    public var viewer: String?
    public var baselined: [String] = []

    public init(initialized: Bool = false, reminded: [String] = [], viewer: String? = nil, baselined: [String] = []) {
        self.initialized = initialized
        self.reminded = reminded
        self.viewer = viewer
        self.baselined = baselined
    }

    private enum CodingKeys: String, CodingKey {
        case initialized, reminded, viewer, baselined
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        initialized = container.decodeLossy(Bool.self, forKey: .initialized, default: false)
        reminded = container.decodeLossy([String].self, forKey: .reminded, default: [])
        viewer = try? container.decodeIfPresent(String.self, forKey: .viewer)
        baselined = container.decodeLossy([String].self, forKey: .baselined, default: [])
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
