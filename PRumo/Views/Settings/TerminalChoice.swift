import PRumoKit

enum TerminalChoice: CaseIterable, Identifiable {
    case embedded
    case ghostty
    case terminal
    case iterm
    case custom

    var id: Self { self }

    init(_ kind: TerminalKind) {
        switch kind {
        case .ghostty: self = .ghostty
        case .terminal: self = .terminal
        case .iterm: self = .iterm
        case .custom: self = .custom
        case .embedded: self = .embedded
        }
    }

    var label: String {
        switch self {
        case .ghostty: ClaudeSettingsText.ghostty
        case .terminal: ClaudeSettingsText.terminalApp
        case .iterm: ClaudeSettingsText.iterm
        case .custom: ClaudeSettingsText.custom
        case .embedded: ClaudeSettingsText.embedded
        }
    }
}
