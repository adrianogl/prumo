import Foundation
import Testing
@testable import PRumoKit

@Suite struct TerminalCommandTests {
    let directory = URL(fileURLWithPath: "/Users/ana/Code/loja")

    @Test func ghosttyArguments() {
        let command = TerminalCommand.build(kind: .ghostty, directory: directory, line: "claude 'oi'")
        #expect(command == LaunchCommand(
            executable: "/usr/bin/open",
            arguments: ["-na", "Ghostty", "--args", "--working-directory=/Users/ana/Code/loja",
                        "-e", "/bin/zsh", "-lc", "claude 'oi'"]))
    }

    @Test func terminalAppleScriptEscapes() {
        let line = TerminalCommand.claudeLine(prompt: "diz \"oi\"", extraFlags: "")
        let command = TerminalCommand.build(kind: .terminal, directory: directory, line: line)
        #expect(command == LaunchCommand(
            executable: "/usr/bin/osascript",
            arguments: [
                "-e", "tell application \"Terminal\" to do script \"cd '/Users/ana/Code/loja' && claude 'diz \\\"oi\\\"'\"",
                "-e", "tell application \"Terminal\" to activate",
            ]))
    }

    @Test func itermAppleScript() {
        let command = TerminalCommand.build(kind: .iterm, directory: directory, line: "claude 'oi'")
        #expect(command == LaunchCommand(
            executable: "/usr/bin/osascript",
            arguments: [
                "-e", "tell application \"iTerm\"",
                "-e", "activate",
                "-e", "create window with default profile",
                "-e", "tell current session of current window to write text \"cd '/Users/ana/Code/loja' && claude 'oi'\"",
                "-e", "end tell",
            ]))
    }

    @Test func customTemplateSubstitutesQuoted() {
        let spaced = URL(fileURLWithPath: "/Users/ana/Code/minha loja")
        let command = TerminalCommand.build(
            kind: .custom(template: "kitty --directory {dir} -e zsh -c {cmd}"),
            directory: spaced, line: "claude 'oi'")
        #expect(command == LaunchCommand(
            executable: "/bin/zsh",
            arguments: ["-lc", "kitty --directory '/Users/ana/Code/minha loja' -e zsh -c 'claude '\\''oi'\\'''"]))
    }

    @Test func quotesSingleQuoteDollarAndBacktick() {
        let prompt = "Fix \"it\" $(rm -rf ~) `x` it's"
        let line = TerminalCommand.claudeLine(prompt: prompt, extraFlags: "--model opus")
        #expect(line == "claude --model opus 'Fix \"it\" $(rm -rf ~) `x` it'\\''s'")
        #expect(ShellQuote.single("a'b") == "'a'\\''b'")
        #expect(ShellQuote.appleScriptString("a\\b\"c") == "a\\\\b\\\"c")
    }

    @Test func emptyFlagsNoDoubleSpace() {
        #expect(TerminalCommand.claudeLine(prompt: "oi", extraFlags: "") == "claude 'oi'")
        #expect(TerminalCommand.claudeLine(prompt: "oi", extraFlags: "  \n ") == "claude 'oi'")
        #expect(TerminalCommand.claudeLine(prompt: "oi", extraFlags: " --x ") == "claude --x 'oi'")
    }
}
