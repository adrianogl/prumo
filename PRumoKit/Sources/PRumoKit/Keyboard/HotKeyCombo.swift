public struct HotKeyCombo: Codable, Equatable, Sendable {
    public var keyCode: UInt32
    public var key: String
    public var modifiers: Set<HotKeyModifier>

    public static let standard = HotKeyCombo(keyCode: 35, key: "P", modifiers: [.option, .command])

    public init(keyCode: UInt32, key: String, modifiers: Set<HotKeyModifier>) {
        self.keyCode = keyCode
        self.key = key
        self.modifiers = modifiers
    }

    private enum CodingKeys: String, CodingKey {
        case keyCode, key, modifiers
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let standard = HotKeyCombo.standard
        keyCode = container.decodeLossy(UInt32.self, forKey: .keyCode, default: standard.keyCode)
        key = container.decodeLossy(String.self, forKey: .key, default: standard.key)
        if container.contains(.modifiers) {
            modifiers = container.decodeLossySet(HotKeyModifier.self, forKey: .modifiers)
        } else {
            modifiers = standard.modifiers
        }
    }

    public var display: String {
        let symbols: [(HotKeyModifier, String)] = [(.control, "⌃"), (.option, "⌥"), (.shift, "⇧"), (.command, "⌘")]
        let prefix = symbols.filter { modifiers.contains($0.0) }.map(\.1).joined()
        return prefix + key.uppercased()
    }

    public var carbonModifiers: UInt32 {
        modifiers.reduce(0) { total, modifier in
            switch modifier {
            case .command: total | 256
            case .shift: total | 512
            case .option: total | 2048
            case .control: total | 4096
            }
        }
    }

    public var isValid: Bool {
        !modifiers.isDisjoint(with: [.control, .option, .command])
    }
}
