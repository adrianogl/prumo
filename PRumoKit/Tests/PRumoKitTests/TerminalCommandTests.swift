import Foundation
import Testing
@testable import PRumoKit

@Suite struct TerminalCommandTests {
    let directory = URL(fileURLWithPath: "/Users/ana/Code/loja")
    let scriptPath = URL(fileURLWithPath: "/Users/ana/Library/Caches/PRumo/sessions/abc.zsh")
    static func tail() -> String {
        "rc=$?\nif [ $rc -ne 0 ]; then read -k1 \"?${claude_name} saiu com erro $rc. Pressione uma tecla.\"; fi\nexit $rc\n"
    }
    static func head(_ name: String = "claude") -> String {
        "cd '/Users/ana/Code/loja' || exit 1\nclaude_name='\(name)'\n"
    }
    let hostile = "Fix \"it\" $(rm -rf ~) `x` it's PWNED"

    @Test func scriptQuotesHostilePrompt() {
        let prompt = hostile + "\u{15}\u{3}\u{1b}\r"
        let script = TerminalCommand.scriptContents(directory: directory, prompt: prompt, extraFlags: " --model opus ")
        #expect(script == Self.head() + "'claude' --model opus -- 'Fix \"it\" $(rm -rf ~) `x` it'\\''s PWNED\n'\n" + Self.tail())
    }

    @Test func scriptUsesGivenClaudeExecutable() {
        let script = TerminalCommand.scriptContents(
            directory: directory, prompt: "oi", extraFlags: "", claudeExecutable: "/Users/ana/.local/bin/claude")
        #expect(script == Self.head("/Users/ana/.local/bin/claude") + "'/Users/ana/.local/bin/claude' -- 'oi'\n" + Self.tail())
    }

    @Test func scriptUsesConfiguredCommand() {
        let script = TerminalCommand.scriptContents(
            directory: directory, prompt: "oi", extraFlags: "", claudeExecutable: "claude-ems")
        #expect(script.contains("'claude-ems' -- "))
        #expect(script.contains("claude_name='claude-ems'\n"))
    }

    @Test func errorMessageQuotesHostileCommandName() {
        let script = TerminalCommand.scriptContents(
            directory: directory, prompt: "oi", extraFlags: "", claudeExecutable: "a'b$(x)")
        #expect(script.contains("claude_name='a'\\''b$(x)'\n"))
    }

    @Test(arguments: [(0, Int32(0)), (3, Int32(3))])
    func scriptRunsUnderZshWithStub(stubExit: Int, expected: Int32) throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("prumo-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let stub = dir.appendingPathComponent("claude-stub")
        try "#!/bin/sh\n[ \"$#\" -eq 2 ] || exit 98\n[ \"$1\" = \"--\" ] || exit 97\nexit \(stubExit)\n".write(to: stub, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: stub.path)
        let script = dir.appendingPathComponent("session.zsh")
        try TerminalCommand.scriptContents(
            directory: dir, prompt: hostile, extraFlags: "", claudeExecutable: stub.path
        ).write(to: script, atomically: true, encoding: .utf8)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-f", script.path]
        process.standardInput = FileHandle.nullDevice
        let errors = Pipe()
        process.standardError = errors
        process.standardOutput = Pipe()
        try process.run()
        let stderr = errors.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        #expect(process.terminationStatus == expected)
        if expected == 0 { #expect(stderr.isEmpty) }
    }

    @Test func scriptSanitizesControls() {
        let script = TerminalCommand.scriptContents(
            directory: directory, prompt: "a\r\nb\rc\td\u{0}\u{7f}\u{85}e", extraFlags: "")
        #expect(script == Self.head() + "'claude' -- 'a\nb\nc\tde'\n" + Self.tail())
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
                        "-e", "/bin/zsh", "-il", scriptPath.path]))
    }

    @Test func terminalAppleScriptTypesOnlyRunLine() {
        let command = TerminalCommand.build(kind: .terminal, directory: directory, scriptPath: scriptPath)
        #expect(command == LaunchCommand(
            executable: "/usr/bin/osascript",
            arguments: [
                "-e", "tell application \"Terminal\" to do script \"/bin/zsh -il '\(scriptPath.path)'\"",
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
                "-e", "tell current session of current window to write text \"/bin/zsh -il '\(scriptPath.path)'\"",
                "-e", "end tell",
            ]))
    }

    @Test func customTemplateSubstitutesQuoted() {
        let spaced = URL(fileURLWithPath: "/Users/ana/Code/minha loja")
        let command = TerminalCommand.build(
            kind: .custom(template: "kitty --directory {dir} -e {cmd}"), directory: spaced, scriptPath: scriptPath)
        #expect(command == LaunchCommand(
            executable: "/bin/zsh",
            arguments: ["-lc", "kitty --directory '/Users/ana/Code/minha loja' -e /bin/zsh -il '\(scriptPath.path)'"]))
    }

    @Test func customTemplateWithQuotedCmdStillSafe() {
        let command = TerminalCommand.build(
            kind: .custom(template: "sh -c \"{cmd}\""), directory: directory, scriptPath: scriptPath)
        #expect(command.arguments == ["-lc", "sh -c \"/bin/zsh -il '\(scriptPath.path)'\""])
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
        #expect(script == Self.head() + "'claude' -- 'oi'\n" + Self.tail())
    }

    @Test func shellQuoteHelpers() {
        #expect(ShellQuote.single("a'b") == "'a'\\''b'")
        #expect(ShellQuote.appleScriptString("a\\b\"c") == "a\\\\b\\\"c")
    }

    @Test func scriptDeletesItselfFirst() {
        let script = TerminalCommand.scriptContents(
            directory: directory, prompt: "oi", extraFlags: "",
            environment: ["GH_TOKEN": "t"], scriptPath: URL(fileURLWithPath: "/tmp/s/abc.zsh"))
        #expect(script.components(separatedBy: "\n").first == "rm -f -- '/tmp/s/abc.zsh'")
        #expect(script == "rm -f -- '/tmp/s/abc.zsh'\nexport GH_TOKEN='t'\n" + Self.head() + "'claude' -- 'oi'\n" + Self.tail())
    }

    @Test func tokenExportedQuoted() {
        let script = TerminalCommand.scriptContents(
            directory: directory, prompt: "oi", extraFlags: "", environment: ["GH_TOKEN": "ab'c"])
        #expect(script == "export GH_TOKEN='ab'\\''c'\n" + Self.head() + "'claude' -- 'oi'\n" + Self.tail())
    }

    @Test func exportsSortedByName() {
        let script = TerminalCommand.scriptContents(
            directory: directory, prompt: "oi", extraFlags: "",
            environment: ["GITLAB_TOKEN": "b", "GITLAB_HOST": "a"])
        #expect(script.hasPrefix("export GITLAB_HOST='a'\nexport GITLAB_TOKEN='b'\ncd "))
    }

    @Test func invalidEnvNameSkipped() {
        let script = TerminalCommand.scriptContents(
            directory: directory, prompt: "oi", extraFlags: "",
            environment: ["GH TOKEN": "x", "gh_token": "y", "1A": "z", "A=B": "w", "": "v"])
        #expect(script == Self.head() + "'claude' -- 'oi'\n" + Self.tail())
    }

    @Test func noEnvironmentKeepsScriptUnchanged() {
        let script = TerminalCommand.scriptContents(directory: directory, prompt: "oi", extraFlags: "")
        #expect(script == Self.head() + "'claude' -- 'oi'\n" + Self.tail())
        #expect(!script.contains("export"))
        #expect(!script.contains("rm -f"))
    }

    @Test func hostileTokenReachesClaudeLiterally() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("prumo-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let output = dir.appendingPathComponent("token.out")
        let stub = dir.appendingPathComponent("claude-stub")
        try "#!/bin/sh\nprintf %s \"$GH_TOKEN\" > \(ShellQuote.single(output.path))\nexit 0\n"
            .write(to: stub, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: stub.path)
        let token = "a'b\"c$(touch PWNED)`x`$HOME\nd;e\\f"
        let script = dir.appendingPathComponent("session.zsh")
        try TerminalCommand.scriptContents(
            directory: dir, prompt: "oi", extraFlags: "", claudeExecutable: stub.path,
            environment: ["GH_TOKEN": token], scriptPath: script
        ).write(to: script, atomically: true, encoding: .utf8)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-f", script.path]
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        try process.run()
        process.waitUntilExit()
        #expect(process.terminationStatus == 0)
        #expect(try String(contentsOf: output, encoding: .utf8) == token)
        #expect(!FileManager.default.fileExists(atPath: script.path))
        #expect(!FileManager.default.fileExists(atPath: dir.appendingPathComponent("PWNED").path))
    }

    @Test func tokenNeverInLaunchArguments() {
        let token = "ghp_SECRETTOKEN123"
        let kinds: [TerminalKind] = [.ghostty, .terminal, .iterm, .custom(template: "x {dir} {cmd}")]
        for kind in kinds {
            let command = TerminalCommand.build(kind: kind, directory: directory, scriptPath: scriptPath)
            let all = [command.executable] + command.arguments
            #expect(!all.contains { $0.contains(token) })
            #expect(!all.contains { $0.contains("GH_TOKEN") })
        }
    }

    @Test func githubEnvironmentHasGhToken() {
        #expect(SessionEnvironment.variables(provider: .github, host: "github.com", token: "t1", isOAuth: false) == ["GH_TOKEN": "t1"])
    }

    @Test func gitlabEnvironmentHasTokenAndHost() {
        #expect(
            SessionEnvironment.variables(provider: .gitlab, host: "gitlab.empresa.com", token: "t2", isOAuth: false)
                == ["GITLAB_TOKEN": "t2", "GITLAB_HOST": "https://gitlab.empresa.com"])
    }

    @Test func gitlabOAuthEnvironmentUsesOAuthToken() {
        #expect(
            SessionEnvironment.variables(provider: .gitlab, host: "gitlab.com", token: "t3", isOAuth: true)
                == ["OAUTH_TOKEN": "t3", "GITLAB_HOST": "https://gitlab.com"])
    }

    @Test func gitlabPromptWithShellTextStaysQuoted() {
        let pr = PullRequest.fixture(
            title: "`id` $(rm -rf ~) 'x'", repository: "grupo/app", headRefName: "feat/$(whoami)", provider: .gitlab)
        let prompt = PromptTemplate.render("MR !{numero} {titulo} {branch}", values: PromptValues.review(pr))
        let script = TerminalCommand.scriptContents(directory: directory, prompt: prompt, extraFlags: "")
        let lines = script.components(separatedBy: "\n")
        #expect(script.components(separatedBy: "$(rm -rf ~)").count == 2)
        #expect(script.components(separatedBy: "$(whoami)").count == 2)
        #expect(!lines.contains { $0.hasPrefix("`id`") || $0.hasPrefix("$(") || $0.hasPrefix("feat/") })
        #expect(script.contains("'claude' -- 'MR !812 `id` $(rm -rf ~) '\\''x'\\'' feat/$(whoami)'\n"))
    }

    @Test func gitlabSessionScriptKeepsTokenAndHostileTitleConfined() {
        let pr = PullRequest.fixture(title: "`id` $(rm -rf ~) 'x'", repository: "grupo/app", provider: .gitlab)
        let prompt = PromptTemplate.render("MR !{numero} {titulo}", values: PromptValues.review(pr))
        let environment = SessionEnvironment.variables(
            provider: .gitlab, host: "gitlab.empresa.com", token: "glpat-$(id)'z", isOAuth: true)
        let script = TerminalCommand.scriptContents(
            directory: directory, prompt: prompt, extraFlags: "", environment: environment, scriptPath: scriptPath)
        let lines = script.components(separatedBy: "\n")
        #expect(lines.first == "rm -f -- '/Users/ana/Library/Caches/PRumo/sessions/abc.zsh'")
        #expect(lines.filter { $0.contains("glpat-") } == ["export OAUTH_TOKEN='glpat-$(id)'\\''z'"])
        #expect(lines.contains("export GITLAB_HOST='https://gitlab.empresa.com'"))
        #expect(lines.filter { $0.contains("`id`") || $0.contains("rm -rf") }
            == ["'claude' -- 'MR !812 `id` $(rm -rf ~) '\\''x'\\'''"])
    }
}
