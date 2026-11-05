import Foundation

public struct ClaudeLauncher: Sendable {
    static let forkNotice = " O PR vem de um fork; não faça push."
    static let safePathCharacters = Set("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789/._-")

    private let settings: ClaudeSettings
    private let scanned: [String: [URL]]
    private let runner: ProcessRunner
    private let home: URL
    private let sessionsDir: URL
    private let writeScript: @Sendable (String, URL) throws -> Void
    private let cleanupOldScripts: @Sendable (URL, Date) -> Void
    private let uuid: @Sendable () -> String
    private let now: @Sendable () -> Date
    private let exists: @Sendable (URL) -> Bool
    private let claudeLocator: @Sendable () async throws -> Bool

    public init(
        settings: ClaudeSettings,
        scanned: [String: [URL]],
        runner: ProcessRunner,
        home: URL = FileManager.default.homeDirectoryForCurrentUser,
        sessionsDir: URL? = nil,
        writeScript: @escaping @Sendable (String, URL) throws -> Void = { try SessionScriptFiles.write($0, to: $1) },
        cleanupOldScripts: @escaping @Sendable (URL, Date) -> Void = { SessionScriptFiles.cleanup(in: $0, now: $1) },
        uuid: @escaping @Sendable () -> String = { UUID().uuidString },
        now: @escaping @Sendable () -> Date = { Date() },
        exists: @escaping @Sendable (URL) -> Bool = { FileManager.default.fileExists(atPath: $0.path) },
        claudeLocator: (@Sendable () async throws -> Bool)? = nil
    ) {
        self.settings = settings
        self.scanned = scanned
        self.runner = runner
        self.home = home
        self.sessionsDir = sessionsDir ?? SessionScriptFiles.defaultSessionsDirectory(home: home)
        self.writeScript = writeScript
        self.cleanupOldScripts = cleanupOldScripts
        self.uuid = uuid
        self.now = now
        self.exists = exists
        self.claudeLocator = claudeLocator ?? {
            try await ClaudeExecutableLocator.cached(runner: SystemProcessRunner(timeout: .seconds(15)))
        }
    }

    public func launch(pr: PullRequest, purpose: SessionPurpose) async throws(ClaudeLaunchError) -> URL {
        let overrides = settings.cloneOverrides.reduce(into: [String: URL]()) {
            $0[$1.key.lowercased()] = expand($1.value)
        }
        guard let clone = CloneResolver.pick(repository: pr.repository, scanned: scanned, overrides: overrides) else {
            throw .cloneNotFound(repository: pr.repository)
        }

        let scriptURL = sessionsDir.appendingPathComponent("\(uuid()).zsh")
        guard !scriptURL.path.isEmpty, scriptURL.path.allSatisfy(Self.safePathCharacters.contains) else {
            throw .launchFailed("O caminho de cache do PRumo tem espaço ou acento (\(scriptURL.path)); o PRumo não consegue abrir o terminal com segurança nesse caso.")
        }
        let claudeFound: Bool
        do {
            claudeFound = try await claudeLocator()
        } catch ProcessRunnerError.timedOut {
            throw .launchFailed("O shell demorou demais para responder ao procurar o claude.")
        } catch {
            throw .launchFailed(Self.message(for: error))
        }
        guard claudeFound else {
            throw .launchFailed("Não encontrei o comando claude no PATH do seu shell.")
        }

        let worktrees = WorktreeManager(runner: runner, worktreesRoot: expand(settings.worktreesRoot), exists: exists)
        let repoName = pr.repository.split(separator: "/").last.map(String.init) ?? pr.repository
        let expectedTarget = expand(settings.worktreesRoot).appendingPathComponent("\(repoName)-\(pr.number)")
        let preexisting = exists(expectedTarget)
        let directory: URL
        do {
            directory = try await worktrees.prepare(pr: pr, clone: clone, purpose: purpose)
        } catch {
            switch error {
            case .gitFailed(let message): throw .worktree(message)
            }
        }
        let created = !preexisting && directory.standardizedFileURL.path == expectedTarget.standardizedFileURL.path

        var prompt: String
        switch purpose {
        case .review:
            prompt = PromptTemplate.render(settings.reviewTemplate, values: PromptValues.review(pr))
        case .fixCI:
            prompt = PromptTemplate.render(settings.ciTemplate, values: PromptValues.ci(pr))
            if pr.isCrossRepository { prompt += Self.forkNotice }
        }

        let script = TerminalCommand.scriptContents(
            directory: directory, prompt: prompt, extraFlags: settings.extraFlags)
        cleanupOldScripts(sessionsDir, now())
        do {
            try writeScript(script, scriptURL)
        } catch {
            await discard(created: created, worktrees: worktrees, directory: directory, clone: clone, number: pr.number)
            throw .launchFailed(Self.message(for: error))
        }

        let command = TerminalCommand.build(kind: settings.terminal, directory: directory, scriptPath: scriptURL)
        let failure: String?
        do {
            let result = try await runner.run(command.executable, command.arguments)
            if result.status == 0 {
                failure = nil
            } else {
                let stderr = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
                failure = stderr.isEmpty ? "O terminal não abriu (código \(result.status))." : stderr
            }
        } catch {
            failure = Self.message(for: error)
        }
        if let failure {
            await discard(created: created, worktrees: worktrees, directory: directory, clone: clone, number: pr.number)
            throw .launchFailed(failure)
        }
        return directory
    }

    private func discard(created: Bool, worktrees: WorktreeManager, directory: URL, clone: URL, number: Int) async {
        guard created else { return }
        _ = await worktrees.removeIfClean(path: directory, clone: clone, number: number)
    }

    private static func message(for error: Error) -> String {
        if let runnerError = error as? ProcessRunnerError, runnerError == .timedOut {
            return "O comando demorou demais para responder."
        }
        return error.localizedDescription
    }

    private func expand(_ path: String) -> URL {
        if path == "~" { return home }
        if path.hasPrefix("~/") { return home.appendingPathComponent(String(path.dropFirst(2))) }
        return URL(fileURLWithPath: path)
    }
}
