import Foundation

public struct LaunchCommand: Equatable, Sendable {
    public let executable: String
    public let arguments: [String]

    public init(executable: String, arguments: [String]) {
        self.executable = executable
        self.arguments = arguments
    }
}

public enum TerminalCommand {
    public static func claudeLine(prompt: String, extraFlags: String) -> String {
        let flags = extraFlags.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = ["claude"] + (flags.isEmpty ? [] : [flags]) + [ShellQuote.single(prompt)]
        return parts.joined(separator: " ")
    }

    public static func build(kind: TerminalKind, directory: URL, line: String) -> LaunchCommand {
        let dir = directory.path
        let cdLine = "cd \(ShellQuote.single(dir)) && \(line)"
        switch kind {
        case .ghostty:
            return LaunchCommand(
                executable: "/usr/bin/open",
                arguments: ["-na", "Ghostty", "--args", "--working-directory=\(dir)",
                            "-e", "/bin/zsh", "-lc", line])
        case .terminal:
            return LaunchCommand(
                executable: "/usr/bin/osascript",
                arguments: [
                    "-e", "tell application \"Terminal\" to do script \"\(ShellQuote.appleScriptString(cdLine))\"",
                    "-e", "tell application \"Terminal\" to activate",
                ])
        case .iterm:
            return LaunchCommand(
                executable: "/usr/bin/osascript",
                arguments: [
                    "-e", "tell application \"iTerm\"",
                    "-e", "activate",
                    "-e", "create window with default profile",
                    "-e", "tell current session of current window to write text \"\(ShellQuote.appleScriptString(cdLine))\"",
                    "-e", "end tell",
                ])
        case .custom(let template):
            let resolved = substitute(template, values: ["{dir}": ShellQuote.single(dir), "{cmd}": ShellQuote.single(line)])
            return LaunchCommand(executable: "/bin/zsh", arguments: ["-lc", resolved])
        }
    }

    private static func substitute(_ template: String, values: [String: String]) -> String {
        var result = ""
        var rest = Substring(template)
        while !rest.isEmpty {
            if let (token, value) = values.first(where: { rest.hasPrefix($0.key) }) {
                result += value
                rest = rest.dropFirst(token.count)
            } else {
                result.append(rest.removeFirst())
            }
        }
        return result
    }
}
