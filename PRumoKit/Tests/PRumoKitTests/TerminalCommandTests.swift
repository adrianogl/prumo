import Foundation
import Testing
@testable import PRumoKit

@Suite struct TerminalCommandTests {
    let directory = URL(fileURLWithPath: "/Users/ana/Code/loja")
    let scriptPath = URL(fileURLWithPath: "/Users/ana/Library/Caches/PRumo/sessions/abc.zsh")
    static let tail = "status=$?\n[ $status -ne 0 ] && read -k1 \"?claude saiu com erro $status. Pressione uma tecla.\"\n"
    let hostile = "Fix \"it\" $(rm -rf ~) `x` it's PWNED"

    @Test func scriptQuotesHostilePrompt() {
        let prompt = hostile + "\u{15}\u{3}\u{1b}\r"
        let script = TerminalCommand.scriptContents(directory: directory, prompt: prompt, extraFlags: " --model opus ")
        #expect(script == "cd '/Users/ana/Code/loja' || exit 1\n'claude' --model opus 'Fix \"it\" $(rm -rf ~) `x` it'\\''s PWNED\n'\n" + Self.tail)
    }

    @Test func scriptUsesGivenClaudeExecutable() {
        let script = TerminalCommand.scriptContents(
            directory: directory, prompt: "oi", extraFlags: "", claudeExecutable: "/Users/ana/.local/bin/claude")
        #expect(script == "cd '/Users/ana/Code/loja' || exit 1\n'/Users/ana/.local/bin/claude' 'oi'\n" + Self.tail)
    }

    @Test func scriptSanitizesControls() {
        let script = TerminalCommand.scriptContents(
            directory: directory, prompt: "a\r\nb\rc\td\u{0}\u{7f}\u{85}e", extraFlags: "")
        #expect(script == "cd '/Users/ana/Code/loja' || exit 1\n'claude' 'a\nb\nc\tde'\n" + Self.tail)
    }

    @Test func scriptRoundTripsThroughZsh() throws {
        let value = hostile + "\n\ttail"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-fc", "printf %s " + ShellQuote.single(value)]
        let pipe = Pipe()
        process.standardOutput = pipe
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        #expect(String(decoding: data, as: UTF8.self) == value)
    }

    @Test func ghosttyArguments() {
        let command = TerminalCommand.build(kind: .ghostty, directory: directory, scriptPath: scriptPath)
        #expect(command == LaunchCommand(
            executable: "/usr/bin/open",
            arguments: ["-na", "Ghostty", "--args", "--working-directory=/Users/ana/Code/loja",
                        "-e", "/bin/zsh", "-l", scriptPath.path]))
    }

    @Test func terminalAppleScriptTypesOnlyRunLine() {
        let command = TerminalCommand.build(kind: .terminal, directory: directory, scriptPath: scriptPath)
        #expect(command == LaunchCommand(
            executable: "/usr/bin/osascript",
            arguments: [
                "-e", "tell application \"Terminal\" to do script \"/bin/zsh -l '\(scriptPath.path)'\"",
                "-e", "tell application \"Terminal\" to activate",
            ]))
    }

    @Test func itermAppleScriptTypesOnlyRunLine() {
        let command = TerminalCommand.build(kind: .iterm, directory: directory, scriptPath: scriptPath)
        #expect(command == LaunchCommand(
            executable: "/usr/bin/osascript",
            arguments: [
                "-e", "tell application \"iTerm\"",
                "-e", "activate",
                "-e", "create window with default profile",
                "-e", "tell current session of current window to write text \"/bin/zsh -l '\(scriptPath.path)'\"",
                "-e", "end tell",
            ]))
    }

    @Test func customTemplateSubstitutesQuoted() {
        let spaced = URL(fileURLWithPath: "/Users/ana/Code/minha loja")
        let command = TerminalCommand.build(
            kind: .custom(template: "kitty --directory {dir} -e {cmd}"), directory: spaced, scriptPath: scriptPath)
        #expect(command == LaunchCommand(
            executable: "/bin/zsh",
            arguments: ["-lc", "kitty --directory '/Users/ana/Code/minha loja' -e /bin/zsh -l '\(scriptPath.path)'"]))
    }

    @Test func customTemplateWithQuotedCmdStillSafe() {
        let command = TerminalCommand.build(
            kind: .custom(template: "sh -c \"{cmd}\""), directory: directory, scriptPath: scriptPath)
        #expect(command.arguments == ["-lc", "sh -c \"/bin/zsh -l '\(scriptPath.path)'\""])
    }

    @Test func noKindCarriesPromptText() {
        let kinds: [TerminalKind] = [.ghostty, .terminal, .iterm, .custom(template: "x {dir} {cmd}")]
        for kind in kinds {
            let command = TerminalCommand.build(kind: kind, directory: directory, scriptPath: scriptPath)
            let all = ([command.executable] + command.arguments).joined(separator: " ")
            #expect(all.contains(scriptPath.path))
            #expect(!all.contains("PWNED"))
        }
    }

    @Test func emptyFlagsNoDoubleSpace() {
        let script = TerminalCommand.scriptContents(directory: directory, prompt: "oi", extraFlags: " \n ")
        #expect(script == "cd '/Users/ana/Code/loja' || exit 1\n'claude' 'oi'\n" + Self.tail)
    }

    @Test func shellQuoteHelpers() {
        #expect(ShellQuote.single("a'b") == "'a'\\''b'")
        #expect(ShellQuote.appleScriptString("a\\b\"c") == "a\\\\b\\\"c")
    }
}
