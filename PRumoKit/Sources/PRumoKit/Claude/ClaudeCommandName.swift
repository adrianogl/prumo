public enum ClaudeCommandName {
    private static let allowed = Set("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._~/+-")

    public static func isValid(_ name: String) -> Bool {
        guard let first = name.first, first != "-" else { return false }
        return name.allSatisfy(allowed.contains)
    }
}
