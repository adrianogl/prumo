import Foundation
import Testing
@testable import PRumoKit

private final class FakeRunner: ProcessRunner, @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [String] = []
    private let respond: @Sendable (String) -> (status: Int32, stdout: String, stderr: String)

    init(respond: @escaping @Sendable (String) -> (status: Int32, stdout: String, stderr: String) = { _ in (0, "", "") }) {
        self.respond = respond
    }

    var commands: [String] { lock.withLock { recorded } }

    func run(_ executable: String, _ args: [String]) async throws -> (status: Int32, stdout: String, stderr: String) {
        let line = ([executable] + args).joined(separator: " ")
        lock.withLock { recorded.append(line) }
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

private let home = URL(fileURLWithPath: "/h")
private let clone = URL(fileURLWithPath: "/h/Code/acme/loja")
private let sessions = URL(fileURLWithPath: "/h/Library/Caches/PRumo/sessions")
private let fixedNow = Date(timeIntervalSince1970: 1_800_000_000)
private let worktree = "/h/Code/.prumo-worktrees/loja-812"

private func launcher(
    _ runner: FakeRunner,
    sink: ScriptSink = ScriptSink(),
    settings: ClaudeSettings = .defaults,
    scanned: [String: [URL]] = ["acme/loja": [clone]],
    sessionsDir: URL = sessions,
    uuid: String = "u1",
    claude: String? = "/h/.local/bin/claude"
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
        claudeLocator: { claude }
    )
}

@Suite struct ClaudeLauncherTests {
    @Test func reviewLaunchesWithReviewTemplateInWorktree() async throws {
        let runner = FakeRunner()
        let sink = ScriptSink()
        let directory = try await launcher(runner, sink: sink).launch(pr: .fixture(), purpose: .review)
        #expect(directory.path == worktree)
        #expect(sink.written.count == 1)
        #expect(sink.written[0].url.path == "/h/Library/Caches/PRumo/sessions/u1.zsh")
        #expect(sink.written[0].contents.contains("cd '\(worktree)' || exit 1\n"))
        #expect(sink.written[0].contents.contains("'/h/.local/bin/claude' '/code-review 812'\n"))
        #expect(runner.commands.last == "/usr/bin/open -na Ghostty --args --working-directory=\(worktree) -e /bin/zsh -l /h/Library/Caches/PRumo/sessions/u1.zsh")
        #expect(runner.commands.contains("/usr/bin/git -C /h/Code/acme/loja worktree add --detach \(worktree) refs/prumo/pull/812"))
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

    @Test func scriptWrittenWithClaudeAbsolutePath() async throws {
        let sink = ScriptSink()
        _ = try await launcher(FakeRunner(), sink: sink, claude: "/opt/homebrew/bin/claude")
            .launch(pr: .fixture(), purpose: .review)
        #expect(sink.written[0].contents.contains("\n'/opt/homebrew/bin/claude' '/code-review 812'\n"))
        #expect(sink.written[0].contents.contains("status=$?\n"))
    }

    @Test func invalidCachePathRejected() async {
        let runner = FakeRunner()
        let sink = ScriptSink()
        let bad = URL(fileURLWithPath: "/h/Library/Caches/PR umo/sessions")
        await #expect(throws: ClaudeLaunchError.launchFailed("Caminho de cache inválido: /h/Library/Caches/PR umo/sessions/u1.zsh")) {
            try await launcher(runner, sink: sink, sessionsDir: bad).launch(pr: .fixture(), purpose: .review)
        }
        #expect(sink.written.isEmpty)
        #expect(!runner.commands.contains { $0.hasPrefix("/usr/bin/open") })
    }

    @Test func claudeNotFoundFails() async {
        let runner = FakeRunner()
        let sink = ScriptSink()
        await #expect(throws: ClaudeLaunchError.launchFailed("Não encontrei o comando claude no PATH do seu shell.")) {
            try await launcher(runner, sink: sink, claude: nil).launch(pr: .fixture(), purpose: .review)
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

    @Test func defaultClaudeLocatorUsesInteractiveZshAndTrims() async {
        let runner = FakeRunner { $0 == "/bin/zsh -ilc command -v claude" ? (0, "/h/bin/claude\n", "") : (1, "", "") }
        let path = await ClaudeExecutableLocator.locate(runner: runner)
        #expect(path == "/h/bin/claude")
        let missing = await ClaudeExecutableLocator.locate(runner: FakeRunner { _ in (1, "", "") })
        #expect(missing == nil)
    }
}
