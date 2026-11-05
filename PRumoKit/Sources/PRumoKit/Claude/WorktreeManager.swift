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

        if exists(target) {
            try await git(["-C", target.path, "fetch"])
            return target
        }

        if !pr.isCrossRepository {
            let listing = try await git(["-C", clone.path, "worktree", "list", "--porcelain"])
            if let existing = Self.path(ofWorktreeWithBranch: pr.headRefName, in: listing) {
                return existing
            }
        }

        if purpose == .fixCI && !pr.isCrossRepository {
            try await git(["-C", clone.path, "fetch", "origin", pr.headRefName])
            try await git(["-C", clone.path, "worktree", "add", target.path, "-B", pr.headRefName, "origin/\(pr.headRefName)"])
            try await git(["-C", target.path, "branch", "--set-upstream-to=origin/\(pr.headRefName)"])
        } else {
            try await git(["-C", clone.path, "fetch", "origin", "pull/\(pr.number)/head"])
            try await git(["-C", clone.path, "worktree", "add", "--detach", target.path, "FETCH_HEAD"])
        }
        return target
    }

    public func removeIfClean(path: URL, clone: URL) async -> Bool {
        do {
            let status = try await git(["-C", path.path, "status", "--porcelain"])
            guard status.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
            try await git(["-C", clone.path, "worktree", "remove", path.path])
            return true
        } catch {
            return false
        }
    }

    @discardableResult
    private func git(_ args: [String]) async throws(WorktreeError) -> String {
        let result: (status: Int32, stdout: String, stderr: String)
        do {
            result = try await runner.run(Self.git, args)
        } catch {
            throw .gitFailed(String(describing: error))
        }
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
            for line in block.split(separator: "\n") {
                if line.hasPrefix("worktree ") {
                    path = String(line.dropFirst("worktree ".count))
                } else if line.hasPrefix("branch refs/heads/") {
                    blockBranch = String(line.dropFirst("branch refs/heads/".count))
                }
            }
            if let path, blockBranch == branch {
                return URL(fileURLWithPath: path)
            }
        }
        return nil
    }
}
