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
    public static func scriptContents(
        directory: URL,
        prompt: String,
        extraFlags: String,
        claudeExecutable: String = "claude"
    ) -> String {
        let flags = extraFlags.trimmingCharacters(in: .whitespacesAndNewlines)
        let claude = ([ShellQuote.single(claudeExecutable)] + (flags.isEmpty ? [] : [flags]) + [ShellQuote.single(sanitize(prompt))])
            .joined(separator: " ")
        return [
            "cd \(ShellQuote.single(directory.path)) || exit 1",
            claude,
            "rc=$?",
            "if [ $rc -ne 0 ]; then read -k1 \"?claude saiu com erro $rc. Pressione uma tecla.\"; fi",
            "exit $rc",
            "",
        ].joined(separator: "\n")
    }

    public static func build(kind: TerminalKind, directory: URL, scriptPath: URL) -> LaunchCommand {
        let dir = directory.path
        let runLine = "/bin/zsh -il \(ShellQuote.single(scriptPath.path))"
        switch kind {
        case .ghostty:
            return LaunchCommand(
                executable: "/usr/bin/open",
                arguments: ["-na", "Ghostty", "--args", "--working-directory=\(dir)",
                            "-e", "/bin/zsh", "-il", scriptPath.path])
        case .terminal:
            return LaunchCommand(
                executable: "/usr/bin/osascript",
                arguments: [
                    "-e", "tell application \"Terminal\" to do script \"\(ShellQuote.appleScriptString(runLine))\"",
                    "-e", "tell application \"Terminal\" to activate",
                ])
        case .iterm:
            return LaunchCommand(
                executable: "/usr/bin/osascript",
                arguments: [
                    "-e", "tell application \"iTerm\"",
                    "-e", "activate",
                    "-e", "create window with default profile",
                    "-e", "tell current session of current window to write text \"\(ShellQuote.appleScriptString(runLine))\"",
                    "-e", "end tell",
                ])
        case .custom(let template):
            let resolved = substitute(template, values: ["{dir}": ShellQuote.single(dir), "{cmd}": runLine])
            return LaunchCommand(executable: "/bin/zsh", arguments: ["-lc", resolved])
        }
    }

    private static func sanitize(_ prompt: String) -> String {
        let normalized = prompt
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        var scalars = String.UnicodeScalarView()
        for scalar in normalized.unicodeScalars {
            let v = scalar.value
            let isControl = v < 0x20 || v == 0x7F || (0x80...0x9F).contains(v)
            if isControl && scalar != "\n" && scalar != "\t" { continue }
            scalars.append(scalar)
        }
        return String(scalars)
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
