import Foundation

public struct WorktreeManager: Sendable {
    private static let git = "/usr/bin/git"

    private let runner: ProcessRunner
    private let worktreesRoot: URL
    private let exists: @Sendable (URL) -> Bool

    public init(
        runner: ProcessRunner,
        worktreesRoot: URL,
        exists: @escaping @Sendable (URL) -> Bool = { FileManager.default.fileExists(atPath: $0.path) }
    ) {
        self.runner = runner
        self.worktreesRoot = worktreesRoot
        self.exists = exists
    }

    public func prepare(pr: PullRequest, clone: URL, purpose: SessionPurpose) async throws(WorktreeError) -> URL {
        let branch = pr.headRefName
        guard !branch.hasPrefix("-") else {
            throw .gitFailed(ClaudeMessages.invalidBranch(branch))
        }
        let target = try await resolveTarget(pr: pr, clone: clone)
        let ownBranch = purpose != .review && !pr.isCrossRepository
        let ref = Self.pullRef(pr.number)

        if exists(target) {
            if !ownBranch {
                try await fetchPullRef(pr.number, clone: clone)
                let status = try await git(["-C", target.path, "status", "--porcelain"])
                if status.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    try await git(["-C", target.path, "checkout", "--detach", ref])
                }
                return target
            }
            let onBranch = try await run(["-C", target.path, "symbolic-ref", "-q", "HEAD"]).status == 0
            if onBranch {
                try await git(["-C", target.path, "fetch", "origin", Self.branchRefspec(branch)])
                return target
            }
            if await isRemovable(path: target, clone: clone) {
                try await git(["-C", clone.path, "worktree", "remove", target.path])
            } else {
                throw .gitFailed(ClaudeMessages.dirtyWorktree(target.path, purpose: purpose))
            }
        }

        try await git(["-C", clone.path, "worktree", "prune"])

        if !pr.isCrossRepository {
            let listing = try await git(["-C", clone.path, "worktree", "list", "--porcelain"])
            if let existing = Self.path(ofWorktreeWithBranch: branch, in: listing) {
                return existing
            }
        }

        if ownBranch {
            let local = "refs/heads/\(branch)"
            let remote = "refs/remotes/origin/\(branch)"
            try await git(["-C", clone.path, "fetch", "origin", Self.branchRefspec(branch)])
            let present = try await run(["-C", clone.path, "rev-parse", "--verify", "--quiet", local]).status == 0
            var reset = true
            if present {
                reset = try await run(["-C", clone.path, "merge-base", "--is-ancestor", local, remote]).status == 0
            }
            if reset {
                try await addWorktree(["-B", branch, "--", target.path, remote], target: target, clone: clone)
            } else {
                try await addWorktree(["--", target.path, branch], target: target, clone: clone)
            }
            try await git(["-C", target.path, "branch", "--set-upstream-to=\(remote)"])
        } else {
            try await fetchPullRef(pr.number, clone: clone)
            try await addWorktree(["--detach", "--", target.path, ref], target: target, clone: clone)
        }
        return target
    }

    public static func targetName(repository: String, number: Int) -> String {
        let repoName = repository.split(separator: "/").last.map(String.init) ?? repository
        return "\(repoName)-\(number)"
    }

    public static func ownerTargetName(repository: String, number: Int) -> String {
        let owner = repository.split(separator: "/").first.map(String.init) ?? repository
        return "\(targetName(repository: repository, number: number))-\(owner)"
    }

    public func removeIfClean(path: URL, clone: URL, number: Int) async -> Bool {
        guard await isRemovable(path: path, clone: clone) else { return false }
        do {
            try await git(["-C", clone.path, "worktree", "remove", path.path])
        } catch {
            return false
        }
        _ = try? await runner.run(Self.git, ["-C", clone.path, "update-ref", "-d", Self.pullRef(number)])
        return true
    }

    private static func pullRef(_ number: Int) -> String {
        "refs/prumo/pull/\(number)"
    }

    private static func branchRefspec(_ branch: String) -> String {
        "+refs/heads/\(branch):refs/remotes/origin/\(branch)"
    }

    private func resolveTarget(pr: PullRequest, clone: URL) async throws(WorktreeError) -> URL {
        let target = worktreesRoot.appendingPathComponent(Self.targetName(repository: pr.repository, number: pr.number))
        guard exists(target) else { return target }
        let targetDir = try? await commonDir(of: target)
        let cloneDir = try await commonDir(of: clone)
        if let targetDir, targetDir == cloneDir { return target }
        return worktreesRoot.appendingPathComponent(Self.ownerTargetName(repository: pr.repository, number: pr.number))
    }

    private func commonDir(of directory: URL) async throws(WorktreeError) -> String {
        try await git(["-C", directory.path, "rev-parse", "--path-format=absolute", "--git-common-dir"])
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func addWorktree(_ args: [String], target: URL, clone: URL) async throws(WorktreeError) {
        do {
            try await git(["-C", clone.path, "worktree", "add"] + args)
        } catch {
            _ = try? await runner.run(Self.git, ["-C", clone.path, "worktree", "remove", "--force", target.path])
            _ = try? await runner.run(Self.git, ["-C", clone.path, "worktree", "prune"])
            throw error
        }
    }

    private func fetchPullRef(_ number: Int, clone: URL) async throws(WorktreeError) {
        try await git(["-C", clone.path, "fetch", "origin", "+pull/\(number)/head:\(Self.pullRef(number))"])
    }

    private func isRemovable(path: URL, clone: URL) async -> Bool {
        let rootPath = worktreesRoot.standardizedFileURL.path
        guard path.standardizedFileURL.path.hasPrefix(rootPath + "/") else { return false }
        do {
            let status = try await git(["-C", path.path, "status", "--porcelain"])
            guard status.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
            let unpushed = try await git(["-C", path.path, "rev-list", "HEAD", "--not", "--remotes", "--glob=refs/prumo/pull/*"])
            return unpushed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        } catch {
            return false
        }
    }

    private func run(_ args: [String]) async throws(WorktreeError) -> (status: Int32, stdout: String, stderr: String) {
        do {
            return try await runner.run(Self.git, args)
        } catch ProcessRunnerError.timedOut {
            throw .gitFailed(ClaudeMessages.gitTimedOut)
        } catch {
            throw .gitFailed(String(describing: error))
        }
    }

    @discardableResult
    private func git(_ args: [String]) async throws(WorktreeError) -> String {
        let result = try await run(args)
        guard result.status == 0 else {
            let stderr = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            let message = stderr.isEmpty ? result.stdout.trimmingCharacters(in: .whitespacesAndNewlines) : stderr
            throw .gitFailed(message)
        }
        return result.stdout
    }

    private static func path(ofWorktreeWithBranch branch: String, in porcelain: String) -> URL? {
        let blocks = porcelain.components(separatedBy: "\n\n")
        for block in blocks {
            var path: String?
            var blockBranch: String?
            var prunable = false
            for line in block.split(separator: "\n") {
                if line.hasPrefix("prunable") { prunable = true }
                if line.hasPrefix("worktree ") {
                    path = String(line.dropFirst("worktree ".count))
                } else if line.hasPrefix("branch refs/heads/") {
                    blockBranch = String(line.dropFirst("branch refs/heads/".count))
                }
            }
            if let path, !prunable, blockBranch == branch {
                return URL(fileURLWithPath: path)
            }
        }
        return nil
    }
}
