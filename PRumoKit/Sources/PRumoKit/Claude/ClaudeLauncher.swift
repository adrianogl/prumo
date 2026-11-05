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
    private let claudeLocator: @Sendable () async -> String?

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
        claudeLocator: (@Sendable () async -> String?)? = nil
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
        self.claudeLocator = claudeLocator ?? { await ClaudeExecutableLocator.cached(runner: runner) }
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
            throw .launchFailed("Caminho de cache inválido: \(scriptURL.path)")
        }
        guard let claude = await claudeLocator() else {
            throw .launchFailed("Não encontrei o comando claude no PATH do seu shell.")
        }

        let directory: URL
        do {
            directory = try await WorktreeManager(runner: runner, worktreesRoot: expand(settings.worktreesRoot))
                .prepare(pr: pr, clone: clone, purpose: purpose)
        } catch {
            guard case .gitFailed(let message) = error else { throw .worktree(String(describing: error)) }
            throw .worktree(message)
        }

        var prompt: String
        switch purpose {
        case .review:
            prompt = PromptTemplate.render(settings.reviewTemplate, values: PromptValues.review(pr))
        case .fixCI:
            prompt = PromptTemplate.render(settings.ciTemplate, values: PromptValues.ci(pr))
            if pr.isCrossRepository { prompt += Self.forkNotice }
        }

        let script = TerminalCommand.scriptContents(
            directory: directory, prompt: prompt, extraFlags: settings.extraFlags, claudeExecutable: claude)
        cleanupOldScripts(sessionsDir, now())
        do {
            try writeScript(script, scriptURL)
        } catch {
            throw .launchFailed(error.localizedDescription)
        }

        let command = TerminalCommand.build(kind: settings.terminal, directory: directory, scriptPath: scriptURL)
        do {
            let result = try await runner.run(command.executable, command.arguments)
            guard result.status == 0 else {
                throw ClaudeLaunchError.launchFailed(result.stderr.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        } catch let error as ClaudeLaunchError {
            throw error
        } catch {
            throw .launchFailed(String(describing: error))
        }
        return directory
    }

    private func expand(_ path: String) -> URL {
        if path == "~" { return home }
        if path.hasPrefix("~/") { return home.appendingPathComponent(String(path.dropFirst(2))) }
        return URL(fileURLWithPath: path)
    }
}
