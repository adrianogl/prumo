public struct ClaudeSettings: Codable, Equatable, Sendable {
    public var reviewTemplate: String
    public var ciTemplate: String
    public var extraFlags: String
    public var terminal: TerminalKind
    public var clonesRoot: String
    public var worktreesRoot: String
    public var cloneOverrides: [String: String]
    public var removeWorktreeOnClose: Bool

    public init(
        reviewTemplate: String = ClaudeDefaults.reviewTemplate,
        ciTemplate: String = ClaudeDefaults.ciTemplate,
        extraFlags: String = ClaudeDefaults.extraFlags,
        terminal: TerminalKind = ClaudeDefaults.terminal,
        clonesRoot: String = ClaudeDefaults.clonesRoot,
        worktreesRoot: String = ClaudeDefaults.worktreesRoot,
        cloneOverrides: [String: String] = [:],
        removeWorktreeOnClose: Bool = ClaudeDefaults.removeWorktreeOnClose
    ) {
        self.reviewTemplate = reviewTemplate
        self.ciTemplate = ciTemplate
        self.extraFlags = extraFlags
        self.terminal = terminal
        self.clonesRoot = clonesRoot
        self.worktreesRoot = worktreesRoot
        self.cloneOverrides = cloneOverrides
        self.removeWorktreeOnClose = removeWorktreeOnClose
    }

    public static let defaults = ClaudeSettings()
}
