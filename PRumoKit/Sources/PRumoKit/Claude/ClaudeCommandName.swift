public enum ClaudeCommandName {
    private static let allowed = Set("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._~/+-")
    private static let blocked: Set<String> = ["eval", "source", "exec", "builtin", "command", "noglob"]

    public static func isValid(_ name: String) -> Bool {
        guard let first = name.first, first != "-" else { return false }
        guard name.allSatisfy(allowed.contains) else { return false }
        guard !name.allSatisfy({ $0 == "." || $0 == "/" }) else { return false }
        return !blocked.contains(name)
    }
}
