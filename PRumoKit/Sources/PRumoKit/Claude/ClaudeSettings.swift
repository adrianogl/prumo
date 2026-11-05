public struct ClaudeSettings: Codable, Equatable, Sendable {
    public var reviewTemplate: String
    public var ciTemplate: String
    public var conflictTemplate: String
    public var extraFlags: String
    public var terminal: TerminalKind
    public var clonesRoot: String
    public var worktreesRoot: String
    public var cloneOverrides: [String: String]
    public var removeWorktreeOnClose: Bool

    public init(
        reviewTemplate: String = ClaudeDefaults.reviewTemplate,
        ciTemplate: String = ClaudeDefaults.ciTemplate,
        conflictTemplate: String = ClaudeDefaults.conflictTemplate,
        extraFlags: String = ClaudeDefaults.extraFlags,
        terminal: TerminalKind = ClaudeDefaults.terminal,
        clonesRoot: String = ClaudeDefaults.clonesRoot,
        worktreesRoot: String = ClaudeDefaults.worktreesRoot,
        cloneOverrides: [String: String] = [:],
        removeWorktreeOnClose: Bool = ClaudeDefaults.removeWorktreeOnClose
    ) {
        self.reviewTemplate = reviewTemplate
        self.ciTemplate = ciTemplate
        self.conflictTemplate = conflictTemplate
        self.extraFlags = extraFlags
        self.terminal = terminal
        self.clonesRoot = clonesRoot
        self.worktreesRoot = worktreesRoot
        self.cloneOverrides = cloneOverrides
        self.removeWorktreeOnClose = removeWorktreeOnClose
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        reviewTemplate = try container.decodeIfPresent(String.self, forKey: .reviewTemplate) ?? ClaudeDefaults.reviewTemplate
        ciTemplate = try container.decodeIfPresent(String.self, forKey: .ciTemplate) ?? ClaudeDefaults.ciTemplate
        conflictTemplate = try container.decodeIfPresent(String.self, forKey: .conflictTemplate) ?? ClaudeDefaults.conflictTemplate
        extraFlags = try container.decodeIfPresent(String.self, forKey: .extraFlags) ?? ClaudeDefaults.extraFlags
        terminal = try container.decodeIfPresent(TerminalKind.self, forKey: .terminal) ?? ClaudeDefaults.terminal
        clonesRoot = try container.decodeIfPresent(String.self, forKey: .clonesRoot) ?? ClaudeDefaults.clonesRoot
        worktreesRoot = try container.decodeIfPresent(String.self, forKey: .worktreesRoot) ?? ClaudeDefaults.worktreesRoot
        cloneOverrides = try container.decodeIfPresent([String: String].self, forKey: .cloneOverrides) ?? [:]
        removeWorktreeOnClose = try container.decodeIfPresent(Bool.self, forKey: .removeWorktreeOnClose)
            ?? ClaudeDefaults.removeWorktreeOnClose
    }

    public static let defaults = ClaudeSettings()
}
