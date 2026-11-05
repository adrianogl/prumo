import Foundation
import Testing
@testable import PRumoKit

private final class FakeRunner: ProcessRunner, @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [String] = []
    private let respond: @Sendable (String) -> (status: Int32, stdout: String, stderr: String)
    private let throwsFor: @Sendable (String) -> Bool

    init(
        respond: @escaping @Sendable (String) -> (status: Int32, stdout: String, stderr: String) = { _ in (0, "", "") },
        throwsFor: @escaping @Sendable (String) -> Bool = { _ in false }
    ) {
        self.throwsFor = throwsFor
        self.respond = respond
    }

    var commands: [String] { lock.withLock { recorded } }

    func run(_ executable: String, _ args: [String]) async throws -> (status: Int32, stdout: String, stderr: String) {
        let line = ([executable] + args).joined(separator: " ")
        lock.withLock { recorded.append(line) }
        if throwsFor(line) { throw ProcessRunnerError.timedOut }
        return respond(line)
    }
}

private final class ScriptSink: @unchecked Sendable {
    private let lock = NSLock()
    private var scripts: [(contents: String, url: URL)] = []
    private var cleanups: [(dir: URL, date: Date)] = []

    var written: [(contents: String, url: URL)] { lock.withLock { scripts } }
    var cleaned: [(dir: URL, date: Date)] { lock.withLock { cleanups } }

    func write(_ contents: String, _ url: URL) { lock.withLock { scripts.append((contents, url)) } }
    func cleanup(_ dir: URL, _ date: Date) { lock.withLock { cleanups.append((dir, date)) } }
}

private final class AskedCommands: @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [String] = []
    var values: [String] { lock.withLock { recorded } }
    func record(_ value: String) { lock.withLock { recorded.append(value) } }
}

private let home = URL(fileURLWithPath: "/h")
private let clone = URL(fileURLWithPath: "/h/Code/acme/loja")
private let sessions = URL(fileURLWithPath: "/h/Library/Caches/PRumo/sessions")
private let fixedNow = Date(timeIntervalSince1970: 1_800_000_000)
private let worktree = "/h/Code/.prumo-worktrees/loja-812"
private let ownerWorktree = "/h/Code/.prumo-worktrees/loja-812-acme"

private func launcher(
    _ runner: FakeRunner,
    sink: ScriptSink = ScriptSink(),
    settings: ClaudeSettings = .defaults,
    scanned: [String: [URL]] = ["acme/loja": [clone]],
    sessionsDir: URL = sessions,
    uuid: String = "u1",
    claude: @escaping @Sendable (String) async throws -> Bool = { _ in true }
) -> ClaudeLauncher {
    ClaudeLauncher(
        settings: settings,
        scanned: scanned,
        runner: runner,
        home: home,
        sessionsDir: sessionsDir,
        writeScript: { sink.write($0, $1) },
        cleanupOldScripts: { sink.cleanup($0, $1) },
        uuid: { uuid },
        now: { fixedNow },
        claudeLocator: claude
    )
}

@Suite struct ClaudeLauncherTests {
    @Test func reviewLaunchesWithReviewTemplateInWorktree() async throws {
        let runner = FakeRunner()
        let sink = ScriptSink()
        let launched = try await launcher(runner, sink: sink).launch(pr: .fixture(), purpose: .review)
        #expect(launched.directory.path == worktree)
        #expect(launched.clone.path == "/h/Code/acme/loja")
        #expect(sink.written.count == 1)
        #expect(sink.written[0].url.path == "/h/Library/Caches/PRumo/sessions/u1.zsh")
        #expect(sink.written[0].contents.contains("cd '\(worktree)' || exit 1\n"))
        #expect(sink.written[0].contents.contains("'claude' -- '/code-review 812'\n"))
        #expect(runner.commands.last == "/usr/bin/open -na Ghostty --args --working-directory=\(worktree) -e /bin/zsh -il /h/Library/Caches/PRumo/sessions/u1.zsh")
        #expect(runner.commands.contains("/usr/bin/git -C /h/Code/acme/loja worktree add --detach -- \(worktree) refs/prumo/pull/812"))
    }

    @Test func fixCIUsesCITemplateWithJobAndRun() async throws {
        let runner = FakeRunner()
        let sink = ScriptSink()
        let pr = PullRequest.fixture(
            ci: .failure(failedChecks: ["build"], total: 3), failedRunID: 99)
        _ = try await launcher(runner, sink: sink).launch(pr: pr, purpose: .fixCI)
        let script = sink.written[0].contents
        #expect(script.contains("A CI do PR #812 (acme/loja) falhou no job build. Leia o log com gh run view 99 --log-failed, encontre a causa e corrija."))
        #expect(!script.contains("não faça push"))
    }

    @Test func forkFixCIAppendsNoPushWarning() async throws {
        let sink = ScriptSink()
        let pr = PullRequest.fixture(ci: .failure(failedChecks: ["build"], total: 3), isCrossRepository: true, failedRunID: 99)
        _ = try await launcher(FakeRunner(), sink: sink).launch(pr: pr, purpose: .fixCI)
        #expect(sink.written[0].contents.contains("e corrija. O PR vem de um fork; não faça push.'\n"))
    }

    @Test func resolveConflictUsesConflictTemplateInBranchWorktree() async throws {
        let sink = ScriptSink()
        let runner = FakeRunner()
        let pr = PullRequest.fixture(mergeable: .conflicting, baseRefName: "develop")
        _ = try await launcher(runner, sink: sink).launch(pr: pr, purpose: .resolveConflict)
        let script = sink.written[0].contents
        #expect(script.contains("O PR #812 (acme/loja) está em conflito com develop. Atualize a branch com git fetch origin develop e git merge origin/develop, resolva os conflitos mantendo a intenção das duas partes, rode os testes e faça commit do merge.'\n"))
        #expect(runner.commands.contains("/usr/bin/git -C /h/Code/acme/loja worktree add -B feat/carrinho -- \(worktree) refs/remotes/origin/feat/carrinho"))
        #expect(!script.contains("não faça push"))
    }

    @Test func forkResolveConflictIsDetachedWithNoPushNotice() async throws {
        let sink = ScriptSink()
        let runner = FakeRunner()
        let pr = PullRequest.fixture(mergeable: .conflicting, isCrossRepository: true)
        _ = try await launcher(runner, sink: sink).launch(pr: pr, purpose: .resolveConflict)
        #expect(sink.written[0].contents.contains("faça commit do merge. O PR vem de um fork; não faça push.'\n"))
        #expect(runner.commands.contains("/usr/bin/git -C /h/Code/acme/loja worktree add --detach -- \(worktree) refs/prumo/pull/812"))
    }

    @Test func addressCommentsUsesCommentsTemplateInBranchWorktree() async throws {
        let sink = ScriptSink()
        let runner = FakeRunner()
        _ = try await launcher(runner, sink: sink).launch(pr: .fixture(commentCount: 2), purpose: .addressComments)
        let script = sink.written[0].contents
        #expect(script.contains("O PR #812 (acme/loja) recebeu comentários de review. Leia os comentários com gh pr view 812 --comments e gh api repos/acme/loja/pulls/812/comments, aplique as alterações pedidas que fizerem sentido, rode os testes e faça commit. Não responda nem resolva as conversas no GitHub; me mostre um resumo do que mudou e do que você não aplicou.'\n"))
        #expect(runner.commands.contains("/usr/bin/git -C /h/Code/acme/loja worktree add -B feat/carrinho -- \(worktree) refs/remotes/origin/feat/carrinho"))
        #expect(!script.contains("não faça push"))
    }

    @Test func forkAddressCommentsIsDetachedWithNoPushNotice() async throws {
        let sink = ScriptSink()
        let runner = FakeRunner()
        let pr = PullRequest.fixture(commentCount: 2, isCrossRepository: true)
        _ = try await launcher(runner, sink: sink).launch(pr: pr, purpose: .addressComments)
        #expect(sink.written[0].contents.contains("do que você não aplicou. O PR vem de um fork; não faça push.'\n"))
        #expect(runner.commands.contains("/usr/bin/git -C /h/Code/acme/loja worktree add --detach -- \(worktree) refs/prumo/pull/812"))
    }

    @Test func missingCloneThrowsCloneNotFound() async {
        let runner = FakeRunner()
        let sink = ScriptSink()
        await #expect(throws: ClaudeLaunchError.cloneNotFound(repository: "acme/loja")) {
            try await launcher(runner, sink: sink, scanned: [:]).launch(pr: .fixture(), purpose: .review)
        }
        #expect(runner.commands.isEmpty)
        #expect(sink.written.isEmpty)
    }

    @Test func overrideWithTildeIsExpandedAgainstHome() async throws {
        let runner = FakeRunner()
        var settings = ClaudeSettings.defaults
        settings.cloneOverrides = ["acme/loja": "~/Outro/loja"]
        _ = try await launcher(runner, settings: settings, scanned: [:]).launch(pr: .fixture(), purpose: .review)
        #expect(runner.commands.contains { $0.hasPrefix("/usr/bin/git -C /h/Outro/loja ") })
    }

    @Test func worktreeFailureIsMapped() async {
        let runner = FakeRunner { $0.contains("fetch origin") ? (1, "", "boom") : (0, "", "") }
        await #expect(throws: ClaudeLaunchError.worktree("boom")) {
            try await launcher(runner).launch(pr: .fixture(), purpose: .review)
        }
    }

    @Test func launchFailureSurfacesStderr() async {
        let runner = FakeRunner { $0.hasPrefix("/usr/bin/open") ? (1, "", "Ghostty não encontrado") : (0, "", "") }
        await #expect(throws: ClaudeLaunchError.launchFailed("Ghostty não encontrado")) {
            try await launcher(runner).launch(pr: .fixture(), purpose: .review)
        }
    }

    @Test func scriptCallsClaudeByName() async throws {
        let sink = ScriptSink()
        _ = try await launcher(FakeRunner(), sink: sink).launch(pr: .fixture(), purpose: .review)
        #expect(sink.written[0].contents.contains("\n'claude' -- '/code-review 812'\nrc=$?\n"))
    }

    @Test func invalidCachePathRejected() async {
        let runner = FakeRunner()
        let sink = ScriptSink()
        let bad = URL(fileURLWithPath: "/h/Library/Caches/PR umo/sessions")
        await #expect(throws: ClaudeLaunchError.launchFailed("O caminho de cache do PRumo tem espaço ou acento (/h/Library/Caches/PR umo/sessions/u1.zsh); o PRumo não consegue abrir o terminal com segurança nesse caso.")) {
            try await launcher(runner, sink: sink, sessionsDir: bad).launch(pr: .fixture(), purpose: .review)
        }
        #expect(sink.written.isEmpty)
        #expect(!runner.commands.contains { $0.hasPrefix("/usr/bin/open") })
        #expect(!runner.commands.contains { $0.contains("worktree add") })
    }

    @Test func claudeNotFoundFails() async {
        let runner = FakeRunner()
        let sink = ScriptSink()
        await #expect(throws: ClaudeLaunchError.launchFailed("Não encontrei o comando claude no seu shell. Confira o nome em Ajustes › IA.")) {
            try await launcher(runner, sink: sink, claude: { _ in false }).launch(pr: .fixture(), purpose: .review)
        }
        #expect(sink.written.isEmpty)
        #expect(!runner.commands.contains { $0.contains("worktree add") })
    }

    @Test func oldScriptsCleanedOnLaunch() async throws {
        let sink = ScriptSink()
        _ = try await launcher(FakeRunner(), sink: sink).launch(pr: .fixture(), purpose: .review)
        #expect(sink.cleaned.count == 1)
        #expect(sink.cleaned[0].dir == sessions)
        #expect(sink.cleaned[0].date == fixedNow)
    }

    @Test func launchFailureRemovesCreatedWorktree() async {
        let runner = FakeRunner { $0.hasPrefix("/usr/bin/open") ? (1, "", "x") : (0, "", "") }
        await #expect(throws: ClaudeLaunchError.launchFailed("x")) {
            try await launcher(runner).launch(pr: .fixture(), purpose: .review)
        }
        #expect(runner.commands.contains("/usr/bin/git -C /h/Code/.prumo-worktrees/loja-812 status --porcelain"))
        #expect(runner.commands.contains("/usr/bin/git -C /h/Code/acme/loja worktree remove \(worktree)"))
    }

    @Test func writeFailureRemovesCreatedWorktree() async {
        let runner = FakeRunner()
        let failing = ClaudeLauncher(
            settings: .defaults, scanned: ["acme/loja": [clone]], runner: runner, home: home,
            sessionsDir: sessions, writeScript: { _, _ in throw CocoaError(.fileWriteNoPermission) },
            cleanupOldScripts: { _, _ in }, uuid: { "u1" }, now: { fixedNow }, claudeLocator: { _ in true })
        await #expect(throws: ClaudeLaunchError.self) {
            try await failing.launch(pr: .fixture(), purpose: .review)
        }
        #expect(runner.commands.contains("/usr/bin/git -C /h/Code/acme/loja worktree remove \(worktree)"))
    }

    @Test func emptyStderrGetsReadableMessage() async {
        let runner = FakeRunner { $0.hasPrefix("/usr/bin/open") ? (2, "", "") : (0, "", "") }
        await #expect(throws: ClaudeLaunchError.launchFailed("O terminal não abriu (código 2).")) {
            try await launcher(runner).launch(pr: .fixture(), purpose: .review)
        }
    }

    @Test func locatorTimeoutIsReported() async {
        let timing = ClaudeLauncher(
            settings: .defaults, scanned: ["acme/loja": [clone]], runner: FakeRunner(), home: home,
            sessionsDir: sessions, writeScript: { _, _ in }, cleanupOldScripts: { _, _ in },
            uuid: { "u1" }, now: { fixedNow }, claudeLocator: { _ in throw ProcessRunnerError.timedOut })
        await #expect(throws: ClaudeLaunchError.launchFailed("O shell demorou demais para responder ao procurar o claude.")) {
            try await timing.launch(pr: .fixture(), purpose: .review)
        }
    }

    @Test func locatorChecksWhenceClaude() async throws {
        let ok = FakeRunner { $0 == "/bin/zsh -ilc whence -- 'claude'" ? (0, "claude () {...}\n", "") : (1, "", "") }
        #expect(try await ClaudeExecutableLocator.isAvailable(command: "claude", runner: ok))
        #expect(try await !ClaudeExecutableLocator.isAvailable(command: "claude", runner: FakeRunner { _ in (1, "", "") }))
        #expect(try await !ClaudeExecutableLocator.isAvailable(command: "claude", runner: FakeRunner { _ in (0, "\n", "") }))
    }

    @Test func locatorQuotesConfiguredCommand() async throws {
        let runner = FakeRunner { _ in (0, "claude-ems () {...}\n", "") }
        #expect(try await ClaudeExecutableLocator.isAvailable(command: "claude-ems", runner: runner))
        #expect(runner.commands == ["/bin/zsh -ilc whence -- 'claude-ems'"])
    }

    @Test func cachedLocatorIsPerCommandName() async throws {
        let first = FakeRunner { _ in (0, "x\n", "") }
        #expect(try await ClaudeExecutableLocator.cached(command: "cache-probe-a", runner: first))
        let missing = FakeRunner { _ in (1, "", "") }
        #expect(try await ClaudeExecutableLocator.cached(command: "cache-probe-a", runner: missing))
        #expect(missing.commands.isEmpty)
        #expect(try await !ClaudeExecutableLocator.cached(command: "cache-probe-b", runner: missing))
        #expect(missing.commands.count == 1)
    }

    @Test func launcherChecksConfiguredCommand() async throws {
        let asked = AskedCommands()
        let sink = ScriptSink()
        let settings = ClaudeSettings(command: " claude-ems ")
        _ = try await launcher(FakeRunner(), sink: sink, settings: settings, claude: { asked.record($0); return true })
            .launch(pr: .fixture(), purpose: .review)
        #expect(asked.values == ["claude-ems"])
        #expect(sink.written[0].contents.contains("'claude-ems' -- "))

        await #expect(throws: ClaudeLaunchError.launchFailed("Não encontrei o comando claude-ems no seu shell. Confira o nome em Ajustes › IA.")) {
            try await launcher(FakeRunner(), settings: settings, claude: { _ in false }).launch(pr: .fixture(), purpose: .review)
        }
    }

    @Test func tildeInCommandExpandsToHome() async throws {
        let asked = AskedCommands()
        let sink = ScriptSink()
        let settings = ClaudeSettings(command: "~/bin/claude-ems")
        _ = try await launcher(FakeRunner(), sink: sink, settings: settings, claude: { asked.record($0); return true })
            .launch(pr: .fixture(), purpose: .review)
        #expect(asked.values == ["/h/bin/claude-ems"])
        #expect(sink.written[0].contents.contains("'/h/bin/claude-ems' -- "))
    }

    @Test func launchTimeoutKeepsCreatedWorktree() async {
        let runner = FakeRunner(throwsFor: { $0.hasPrefix("/usr/bin/open") })
        await #expect(throws: ClaudeLaunchError.launchFailed("O comando demorou demais para responder.")) {
            try await launcher(runner).launch(pr: .fixture(), purpose: .review)
        }
        #expect(!runner.commands.contains { $0.contains("worktree remove") })
    }

    @Test func writeFailureRemovesOwnerSuffixedWorktree() async {
        let runner = FakeRunner { line in
            line == "/usr/bin/git -C \(worktree) rev-parse --path-format=absolute --git-common-dir"
                ? (0, "/h/Code/outra/loja/.git\n", "") : (0, "", "")
        }
        let failing = ClaudeLauncher(
            settings: .defaults, scanned: ["acme/loja": [clone]], runner: runner, home: home,
            sessionsDir: sessions, writeScript: { _, _ in throw CocoaError(.fileWriteNoPermission) },
            cleanupOldScripts: { _, _ in }, uuid: { "u1" }, now: { fixedNow },
            exists: { $0.path == worktree }, claudeLocator: { _ in true })
        await #expect(throws: ClaudeLaunchError.self) {
            try await failing.launch(pr: .fixture(), purpose: .review)
        }
        #expect(runner.commands.contains("/usr/bin/git -C /h/Code/acme/loja worktree add --detach -- \(ownerWorktree) refs/prumo/pull/812"))
        #expect(runner.commands.contains("/usr/bin/git -C /h/Code/acme/loja worktree remove \(ownerWorktree)"))
        #expect(!runner.commands.contains("/usr/bin/git -C /h/Code/acme/loja worktree remove \(worktree)"))
    }
}
