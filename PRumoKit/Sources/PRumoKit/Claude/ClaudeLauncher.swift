import Foundation

public struct ClaudeLauncher: Sendable {
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

    public func launch(pr: PullRequest, purpose: SessionPurpose) async throws(ClaudeLaunchError) -> LaunchResult {
        let overrides = settings.cloneOverrides.reduce(into: [String: URL]()) {
            $0[$1.key.lowercased()] = expand($1.value)
        }
        guard let clone = CloneResolver.pick(repository: pr.repository, scanned: scanned, overrides: overrides) else {
            throw .cloneNotFound(repository: pr.repository)
        }

        let scriptURL = sessionsDir.appendingPathComponent("\(uuid()).zsh")
        guard !scriptURL.path.isEmpty, scriptURL.path.allSatisfy(Self.safePathCharacters.contains) else {
            throw .launchFailed(ClaudeMessages.unsafeCachePath(scriptURL.path))
        }
        let claudeFound: Bool
        do {
            claudeFound = try await claudeLocator()
        } catch ProcessRunnerError.timedOut {
            throw .launchFailed(ClaudeMessages.shellTimedOut)
        } catch {
            throw .launchFailed(Self.message(for: error))
        }
        guard claudeFound else {
            throw .launchFailed(ClaudeMessages.claudeNotFound)
        }

        let worktreesRoot = expand(settings.worktreesRoot)
        let worktrees = WorktreeManager(runner: runner, worktreesRoot: worktreesRoot, exists: exists)
        let candidates = [
            WorktreeManager.targetName(repository: pr.repository, number: pr.number),
            WorktreeManager.ownerTargetName(repository: pr.repository, number: pr.number),
        ].map { worktreesRoot.appendingPathComponent($0).standardizedFileURL.path }
        let preexisting = Set(candidates.filter { exists(URL(fileURLWithPath: $0)) })
        let directory: URL
        do {
            directory = try await worktrees.prepare(pr: pr, clone: clone, purpose: purpose)
        } catch {
            switch error {
            case .gitFailed(let message): throw .worktree(message)
            }
        }
        let directoryPath = directory.standardizedFileURL.path
        let created = candidates.contains(directoryPath) && !preexisting.contains(directoryPath)

        var prompt: String
        switch purpose {
        case .review:
            prompt = PromptTemplate.render(settings.reviewTemplate, values: PromptValues.review(pr))
        case .fixCI:
            prompt = PromptTemplate.render(settings.ciTemplate, values: PromptValues.ci(pr))
            if pr.isCrossRepository { prompt += ClaudeMessages.forkNotice }
        case .resolveConflict:
            prompt = PromptTemplate.render(settings.conflictTemplate, values: PromptValues.conflict(pr))
            if pr.isCrossRepository { prompt += ClaudeMessages.forkNotice }
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
        let result: (status: Int32, stdout: String, stderr: String)
        do {
            result = try await runner.run(command.executable, command.arguments)
        } catch {
            throw .launchFailed(Self.message(for: error))
        }
        if result.status != 0 {
            await discard(created: created, worktrees: worktrees, directory: directory, clone: clone, number: pr.number)
            let stderr = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            throw .launchFailed(stderr.isEmpty ? ClaudeMessages.terminalExit(result.status) : stderr)
        }
        return LaunchResult(directory: directory, clone: clone)
    }

    private func discard(created: Bool, worktrees: WorktreeManager, directory: URL, clone: URL, number: Int) async {
        guard created else { return }
        _ = await worktrees.removeIfClean(path: directory, clone: clone, number: number)
    }

    private static func message(for error: Error) -> String {
        if let runnerError = error as? ProcessRunnerError, runnerError == .timedOut {
            return ClaudeMessages.commandTimedOut
        }
        return error.localizedDescription
    }

    private func expand(_ path: String) -> URL {
        if path == "~" { return home }
        if path.hasPrefix("~/") { return home.appendingPathComponent(String(path.dropFirst(2))) }
        return URL(fileURLWithPath: path)
    }
}
