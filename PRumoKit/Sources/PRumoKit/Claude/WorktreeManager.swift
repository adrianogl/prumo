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
        let repoName = pr.repository.split(separator: "/").last.map(String.init) ?? pr.repository
        let target = worktreesRoot.appendingPathComponent("\(repoName)-\(pr.number)")
        let ownBranch = purpose == .fixCI && !pr.isCrossRepository
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
                try await git(["-C", target.path, "fetch", "origin", pr.headRefName])
                return target
            }
            if await isRemovable(path: target, clone: clone) {
                try await git(["-C", clone.path, "worktree", "remove", target.path])
            } else {
                throw .gitFailed("A worktree \(target.path) tem alterações; finalize ou descarte antes de corrigir a CI.")
            }
        }

        if !pr.isCrossRepository {
            let listing = try await git(["-C", clone.path, "worktree", "list", "--porcelain"])
            if let existing = Self.path(ofWorktreeWithBranch: pr.headRefName, in: listing) {
                return existing
            }
        }

        if ownBranch {
            let branch = pr.headRefName
            try await git(["-C", clone.path, "fetch", "origin", branch])
            let present = try await run(["-C", clone.path, "rev-parse", "--verify", "--quiet", "refs/heads/\(branch)"]).status == 0
            var reset = true
            if present {
                reset = try await run(["-C", clone.path, "merge-base", "--is-ancestor", branch, "origin/\(branch)"]).status == 0
            }
            if reset {
                try await git(["-C", clone.path, "worktree", "add", target.path, "-B", branch, "origin/\(branch)"])
            } else {
                try await git(["-C", clone.path, "worktree", "add", target.path, branch])
            }
            try await git(["-C", target.path, "branch", "--set-upstream-to=origin/\(branch)"])
        } else {
            try await fetchPullRef(pr.number, clone: clone)
            try await git(["-C", clone.path, "worktree", "add", "--detach", target.path, ref])
        }
        return target
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
