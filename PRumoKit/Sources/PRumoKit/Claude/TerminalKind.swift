public enum TerminalKind: Codable, Equatable, Sendable {
    case ghostty
    case terminal
    case iterm
    case custom(template: String)

    private enum CodingKeys: String, CodingKey {
        case kind
        case template
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(String.self, forKey: .kind)
        switch kind {
        case "ghostty": self = .ghostty
        case "terminal": self = .terminal
        case "iterm": self = .iterm
        case "custom": self = .custom(template: try container.decode(String.self, forKey: .template))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .kind, in: container, debugDescription: "Terminal desconhecido: \(kind)")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .ghostty: try container.encode("ghostty", forKey: .kind)
        case .terminal: try container.encode("terminal", forKey: .kind)
        case .iterm: try container.encode("iterm", forKey: .kind)
        case .custom(let template):
            try container.encode("custom", forKey: .kind)
            try container.encode(template, forKey: .template)
        }
    }
}
