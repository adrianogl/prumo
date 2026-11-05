import PRumoKit

enum TerminalChoice: CaseIterable, Identifiable {
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
        }
    }

    var label: String {
        switch self {
        case .ghostty: ClaudeSettingsText.ghostty
        case .terminal: ClaudeSettingsText.terminalApp
        case .iterm: ClaudeSettingsText.iterm
        case .custom: ClaudeSettingsText.custom
        }
    }
}
