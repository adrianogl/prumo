import Foundation
import Testing
@testable import PRumoKit

private final class RecordingRunner: ProcessRunner, @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [String] = []
    private let results: [String: (status: Int32, stdout: String, stderr: String)]

    init(results: [String: (status: Int32, stdout: String, stderr: String)] = [:]) {
        self.results = results
    }

    private func record(_ line: String) {
        lock.withLock { recorded.append(line) }
    }

    var commands: [String] {
        lock.lock()
        defer { lock.unlock() }
        return recorded
    }

    func run(_ executable: String, _ args: [String]) async throws -> (status: Int32, stdout: String, stderr: String) {
        let line = ([executable] + args).joined(separator: " ")
        record(line)
        return results[line] ?? (0, "", "")
    }
}

private let clone = URL(fileURLWithPath: "/code/loja")
private let root = URL(fileURLWithPath: "/wt")
private let target = "/wt/loja-812"

private func manager(_ runner: RecordingRunner, existing: Set<String> = []) -> WorktreeManager {
    WorktreeManager(runner: runner, worktreesRoot: root, exists: { existing.contains($0.path) })
}

@Suite struct WorktreeManagerTests {
    @Test func fixCIOnOwnBranchCreatesTrackingWorktree() async throws {
        let runner = RecordingRunner()
        let path = try await manager(runner).prepare(pr: .fixture(), clone: clone, purpose: .fixCI)
        #expect(path.path == target)
        #expect(runner.commands == [
            "/usr/bin/git -C /code/loja worktree list --porcelain",
            "/usr/bin/git -C /code/loja fetch origin feat/carrinho",
            "/usr/bin/git -C /code/loja worktree add \(target) -B feat/carrinho origin/feat/carrinho",
            "/usr/bin/git -C \(target) branch --set-upstream-to=origin/feat/carrinho"
        ])
    }

    @Test func reviewUsesDetachedPullHead() async throws {
        let runner = RecordingRunner()
        let path = try await manager(runner).prepare(pr: .fixture(), clone: clone, purpose: .review)
        #expect(path.path == target)
        #expect(runner.commands == [
            "/usr/bin/git -C /code/loja worktree list --porcelain",
            "/usr/bin/git -C /code/loja fetch origin pull/812/head",
            "/usr/bin/git -C /code/loja worktree add --detach \(target) FETCH_HEAD"
        ])
    }

    @Test func forkPRAlwaysDetached() async throws {
        let porcelain = "worktree /code/loja\nHEAD abc\nbranch refs/heads/feat/carrinho\n"
        let runner = RecordingRunner(results: [
            "/usr/bin/git -C /code/loja worktree list --porcelain": (0, porcelain, "")
        ])
        let pr = PullRequest.fixture(isCrossRepository: true)
        let path = try await manager(runner).prepare(pr: pr, clone: clone, purpose: .fixCI)
        #expect(path.path == target)
        #expect(runner.commands.contains("/usr/bin/git -C /code/loja fetch origin pull/812/head"))
        #expect(runner.commands.contains("/usr/bin/git -C /code/loja worktree add --detach \(target) FETCH_HEAD"))
        #expect(!runner.commands.contains { $0.contains("-B") })
    }

    @Test func branchAlreadyCheckedOutReturnsExistingPath() async throws {
        let porcelain = """
        worktree /code/loja
        HEAD abc
        branch refs/heads/main

        worktree /code/loja-other
        HEAD def
        branch refs/heads/feat/carrinho

        """
        let runner = RecordingRunner(results: [
            "/usr/bin/git -C /code/loja worktree list --porcelain": (0, porcelain, "")
        ])
        let path = try await manager(runner).prepare(pr: .fixture(), clone: clone, purpose: .fixCI)
        #expect(path.path == "/code/loja-other")
        #expect(runner.commands == ["/usr/bin/git -C /code/loja worktree list --porcelain"])
    }

    @Test func existingTargetIsReusedAndFetched() async throws {
        let runner = RecordingRunner()
        let path = try await manager(runner, existing: [target]).prepare(pr: .fixture(), clone: clone, purpose: .review)
        #expect(path.path == target)
        #expect(runner.commands == ["/usr/bin/git -C \(target) fetch"])
    }

    @Test func gitFailureSurfacesStderr() async {
        let runner = RecordingRunner(results: [
            "/usr/bin/git -C /code/loja fetch origin pull/812/head": (128, "", "fatal: sem rede\n")
        ])
        await #expect(throws: WorktreeError.gitFailed("fatal: sem rede")) {
            try await manager(runner).prepare(pr: .fixture(), clone: clone, purpose: .review)
        }
    }

    @Test func gitFailureFallsBackToStdoutWhenStderrEmpty() async {
        let runner = RecordingRunner(results: [
            "/usr/bin/git -C /code/loja fetch origin pull/812/head": (1, "saiu pelo stdout\n", "")
        ])
        await #expect(throws: WorktreeError.gitFailed("saiu pelo stdout")) {
            try await manager(runner).prepare(pr: .fixture(), clone: clone, purpose: .review)
        }
    }

    @Test func dirtyWorktreeIsKept() async {
        let runner = RecordingRunner(results: [
            "/usr/bin/git -C \(target) status --porcelain": (0, " M a.swift\n", "")
        ])
        let removed = await manager(runner).removeIfClean(path: URL(fileURLWithPath: target), clone: clone)
        #expect(!removed)
        #expect(runner.commands == ["/usr/bin/git -C \(target) status --porcelain"])
    }

    @Test func cleanWorktreeIsRemoved() async {
        let runner = RecordingRunner()
        let removed = await manager(runner).removeIfClean(path: URL(fileURLWithPath: target), clone: clone)
        #expect(removed)
        #expect(runner.commands == [
            "/usr/bin/git -C \(target) status --porcelain",
            "/usr/bin/git -C /code/loja worktree remove \(target)"
        ])
    }

    @Test func removeFailureReturnsFalse() async {
        let runner = RecordingRunner(results: [
            "/usr/bin/git -C /code/loja worktree remove \(target)": (1, "", "erro")
        ])
        let removed = await manager(runner).removeIfClean(path: URL(fileURLWithPath: target), clone: clone)
        #expect(!removed)
    }
}
