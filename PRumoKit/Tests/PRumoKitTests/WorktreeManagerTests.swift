import Foundation
import Testing
@testable import PRumoKit

private final class RecordingRunner: ProcessRunner, @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [String] = []
    private let results: [String: (status: Int32, stdout: String, stderr: String)]
    private let throwing: Set<String>

    init(results: [String: (status: Int32, stdout: String, stderr: String)] = [:], throwing: Set<String> = []) {
        self.results = results
        self.throwing = throwing
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
        if throwing.contains(line) { throw ProcessRunnerError.timedOut }
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
            "/usr/bin/git -C /code/loja worktree prune",
            "/usr/bin/git -C /code/loja worktree list --porcelain",
            "/usr/bin/git -C /code/loja fetch origin +refs/heads/feat/carrinho:refs/remotes/origin/feat/carrinho",
            "/usr/bin/git -C /code/loja rev-parse --verify --quiet refs/heads/feat/carrinho",
            "/usr/bin/git -C /code/loja merge-base --is-ancestor refs/heads/feat/carrinho refs/remotes/origin/feat/carrinho",
            "/usr/bin/git -C /code/loja worktree add -B feat/carrinho -- \(target) refs/remotes/origin/feat/carrinho",
            "/usr/bin/git -C \(target) branch --set-upstream-to=refs/remotes/origin/feat/carrinho"
        ])
    }

    @Test func reviewUsesDetachedPullHead() async throws {
        let runner = RecordingRunner()
        let path = try await manager(runner).prepare(pr: .fixture(), clone: clone, purpose: .review)
        #expect(path.path == target)
        #expect(runner.commands == [
            "/usr/bin/git -C /code/loja worktree prune",
            "/usr/bin/git -C /code/loja worktree list --porcelain",
            "/usr/bin/git -C /code/loja fetch origin +pull/812/head:refs/prumo/pull/812",
            "/usr/bin/git -C /code/loja worktree add --detach -- \(target) refs/prumo/pull/812"
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
        #expect(runner.commands.contains("/usr/bin/git -C /code/loja fetch origin +pull/812/head:refs/prumo/pull/812"))
        #expect(runner.commands.contains("/usr/bin/git -C /code/loja worktree add --detach -- \(target) refs/prumo/pull/812"))
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
        #expect(runner.commands == [
            "/usr/bin/git -C /code/loja worktree prune",
            "/usr/bin/git -C /code/loja worktree list --porcelain"
        ])
    }

    @Test func existingTargetIsReusedAndFetched() async throws {
        let runner = RecordingRunner()
        let path = try await manager(runner, existing: [target]).prepare(pr: .fixture(), clone: clone, purpose: .review)
        #expect(path.path == target)
        #expect(runner.commands == [
            "/usr/bin/git -C \(target) rev-parse --path-format=absolute --git-common-dir",
            "/usr/bin/git -C /code/loja rev-parse --path-format=absolute --git-common-dir",
            "/usr/bin/git -C /code/loja fetch origin +pull/812/head:refs/prumo/pull/812",
            "/usr/bin/git -C \(target) status --porcelain",
            "/usr/bin/git -C \(target) checkout --detach refs/prumo/pull/812"
        ])
    }

    @Test func gitFailureSurfacesStderr() async {
        let runner = RecordingRunner(results: [
            "/usr/bin/git -C /code/loja fetch origin +pull/812/head:refs/prumo/pull/812": (128, "", "fatal: sem rede\n")
        ])
        await #expect(throws: WorktreeError.gitFailed("fatal: sem rede")) {
            try await manager(runner).prepare(pr: .fixture(), clone: clone, purpose: .review)
        }
    }

    @Test func gitFailureFallsBackToStdoutWhenStderrEmpty() async {
        let runner = RecordingRunner(results: [
            "/usr/bin/git -C /code/loja fetch origin +pull/812/head:refs/prumo/pull/812": (1, "saiu pelo stdout\n", "")
        ])
        await #expect(throws: WorktreeError.gitFailed("saiu pelo stdout")) {
            try await manager(runner).prepare(pr: .fixture(), clone: clone, purpose: .review)
        }
    }

    @Test func dirtyWorktreeIsKept() async {
        let runner = RecordingRunner(results: [
            "/usr/bin/git -C \(target) status --porcelain": (0, " M a.swift\n", "")
        ])
        let removed = await manager(runner).removeIfClean(path: URL(fileURLWithPath: target), clone: clone, number: 812)
        #expect(!removed)
        #expect(runner.commands == ["/usr/bin/git -C \(target) status --porcelain"])
    }

    @Test func cleanWorktreeIsRemoved() async {
        let runner = RecordingRunner()
        let removed = await manager(runner).removeIfClean(path: URL(fileURLWithPath: target), clone: clone, number: 812)
        #expect(removed)
        #expect(runner.commands == [
            "/usr/bin/git -C \(target) status --porcelain",
            "/usr/bin/git -C \(target) rev-list HEAD --not --remotes --glob=refs/prumo/pull/*",
            "/usr/bin/git -C /code/loja worktree remove \(target)",
            "/usr/bin/git -C /code/loja update-ref -d refs/prumo/pull/812"
        ])
    }

    @Test func removeFailureReturnsFalse() async {
        let runner = RecordingRunner(results: [
            "/usr/bin/git -C /code/loja worktree remove \(target)": (1, "", "erro")
        ])
        let removed = await manager(runner).removeIfClean(path: URL(fileURLWithPath: target), clone: clone, number: 812)
        #expect(!removed)
    }

    @Test func fetchUsesNamedRefNotFetchHead() async throws {
        let runner = RecordingRunner()
        _ = try await manager(runner).prepare(pr: .fixture(), clone: clone, purpose: .review)
        #expect(!runner.commands.contains { $0.contains("FETCH_HEAD") })
    }

    @Test func existingBranchWithLocalCommitsIsNotReset() async throws {
        let runner = RecordingRunner(results: [
            "/usr/bin/git -C /code/loja merge-base --is-ancestor refs/heads/feat/carrinho refs/remotes/origin/feat/carrinho": (1, "", "")
        ])
        _ = try await manager(runner).prepare(pr: .fixture(), clone: clone, purpose: .fixCI)
        #expect(runner.commands.contains("/usr/bin/git -C /code/loja worktree add -- \(target) feat/carrinho"))
        #expect(!runner.commands.contains { $0.contains(" -B ") })
    }

    @Test func existingBranchBehindOriginIsReset() async throws {
        let runner = RecordingRunner()
        _ = try await manager(runner).prepare(pr: .fixture(), clone: clone, purpose: .fixCI)
        #expect(runner.commands.contains("/usr/bin/git -C /code/loja worktree add -B feat/carrinho -- \(target) refs/remotes/origin/feat/carrinho"))
    }

    @Test func removeKeepsWorktreeWithUnpushedCommits() async {
        let runner = RecordingRunner(results: [
            "/usr/bin/git -C \(target) rev-list HEAD --not --remotes --glob=refs/prumo/pull/*": (0, "abc123\n", "")
        ])
        let removed = await manager(runner).removeIfClean(path: URL(fileURLWithPath: target), clone: clone, number: 812)
        #expect(!removed)
        #expect(!runner.commands.contains { $0.contains("worktree remove") })
    }

    @Test func removeRefusesPathOutsideRoot() async {
        let runner = RecordingRunner()
        let removed = await manager(runner).removeIfClean(path: URL(fileURLWithPath: "/code/loja"), clone: clone, number: 812)
        #expect(!removed)
        #expect(runner.commands.isEmpty)
    }

    @Test func reusedReviewTargetMovesToNewHeadWhenClean() async throws {
        let runner = RecordingRunner()
        _ = try await manager(runner, existing: [target]).prepare(pr: .fixture(), clone: clone, purpose: .review)
        #expect(runner.commands.last == "/usr/bin/git -C \(target) checkout --detach refs/prumo/pull/812")
    }

    @Test func fixCIOnReusedDetachedTargetRecreatesWhenClean() async throws {
        let runner = RecordingRunner(results: [
            "/usr/bin/git -C \(target) symbolic-ref -q HEAD": (1, "", "")
        ])
        let path = try await manager(runner, existing: [target]).prepare(pr: .fixture(), clone: clone, purpose: .fixCI)
        #expect(path.path == target)
        #expect(runner.commands.contains("/usr/bin/git -C /code/loja worktree remove \(target)"))
        #expect(runner.commands.contains("/usr/bin/git -C /code/loja worktree add -B feat/carrinho -- \(target) refs/remotes/origin/feat/carrinho"))
    }

    @Test func fixCIOnDirtyDetachedTargetThrows() async {
        let runner = RecordingRunner(results: [
            "/usr/bin/git -C \(target) symbolic-ref -q HEAD": (1, "", ""),
            "/usr/bin/git -C \(target) status --porcelain": (0, " M a\n", "")
        ])
        await #expect(throws: WorktreeError.gitFailed("A worktree \(target) tem alterações; finalize ou descarte antes de corrigir a CI.")) {
            try await manager(runner, existing: [target]).prepare(pr: .fixture(), clone: clone, purpose: .fixCI)
        }
    }

    @Test func prunableWorktreeIgnored() async throws {
        let porcelain = "worktree /gone\nHEAD abc\nbranch refs/heads/feat/carrinho\nprunable gitdir file points to non-existent location\n"
        let runner = RecordingRunner(results: [
            "/usr/bin/git -C /code/loja worktree list --porcelain": (0, porcelain, "")
        ])
        let path = try await manager(runner).prepare(pr: .fixture(), clone: clone, purpose: .fixCI)
        #expect(path.path == target)
    }

    @Test func pruneRunsBeforeWorktreeAdd() async throws {
        let runner = RecordingRunner()
        _ = try await manager(runner).prepare(pr: .fixture(), clone: clone, purpose: .review)
        let prune = try #require(runner.commands.firstIndex(of: "/usr/bin/git -C /code/loja worktree prune"))
        let add = try #require(runner.commands.firstIndex { $0.contains("worktree add") })
        #expect(prune < add)
    }

    @Test func failedAddRemovesHalfCreatedTarget() async {
        let add = "/usr/bin/git -C /code/loja worktree add --detach -- \(target) refs/prumo/pull/812"
        let runner = RecordingRunner(results: [add: (128, "", "fatal: falhou no meio")])
        await #expect(throws: WorktreeError.gitFailed("fatal: falhou no meio")) {
            try await manager(runner).prepare(pr: .fixture(), clone: clone, purpose: .review)
        }
        #expect(Array(runner.commands.suffix(3)) == [
            add,
            "/usr/bin/git -C /code/loja worktree remove --force \(target)",
            "/usr/bin/git -C /code/loja worktree prune"
        ])
    }

    @Test func timedOutAddRemovesHalfCreatedTarget() async {
        let add = "/usr/bin/git -C /code/loja worktree add -B feat/carrinho -- \(target) refs/remotes/origin/feat/carrinho"
        let runner = RecordingRunner(throwing: [add])
        await #expect(throws: WorktreeError.gitFailed("O git demorou demais para responder.")) {
            try await manager(runner).prepare(pr: .fixture(), clone: clone, purpose: .fixCI)
        }
        #expect(Array(runner.commands.suffix(3)) == [
            add,
            "/usr/bin/git -C /code/loja worktree remove --force \(target)",
            "/usr/bin/git -C /code/loja worktree prune"
        ])
        #expect(!runner.commands.contains { $0.contains("set-upstream-to") })
    }

    @Test func failedFetchDoesNotTouchTarget() async {
        let runner = RecordingRunner(results: [
            "/usr/bin/git -C /code/loja fetch origin +pull/812/head:refs/prumo/pull/812": (128, "", "sem rede")
        ])
        await #expect(throws: WorktreeError.gitFailed("sem rede")) {
            try await manager(runner).prepare(pr: .fixture(), clone: clone, purpose: .review)
        }
        #expect(!runner.commands.contains { $0.contains("worktree remove") })
    }

    @Test func branchStartingWithDashRejected() async {
        let runner = RecordingRunner()
        let pr = PullRequest.fixture(headRefName: "--upload-pack=touch /tmp/pwned")
        for purpose in [SessionPurpose.review, .fixCI] {
            await #expect(throws: WorktreeError.gitFailed("Nome de branch inválido: --upload-pack=touch /tmp/pwned")) {
                try await manager(runner).prepare(pr: pr, clone: clone, purpose: purpose)
            }
        }
        #expect(runner.commands.isEmpty)
    }

    @Test func fetchUsesExplicitRefspec() async throws {
        let runner = RecordingRunner()
        _ = try await manager(runner).prepare(pr: .fixture(), clone: clone, purpose: .fixCI)
        let fetches = runner.commands.filter { $0.contains(" fetch ") }
        #expect(fetches == ["/usr/bin/git -C /code/loja fetch origin +refs/heads/feat/carrinho:refs/remotes/origin/feat/carrinho"])
    }

    @Test func reusedOwnBranchFetchUsesExplicitRefspec() async throws {
        let runner = RecordingRunner()
        _ = try await manager(runner, existing: [target]).prepare(pr: .fixture(), clone: clone, purpose: .fixCI)
        #expect(runner.commands.last == "/usr/bin/git -C \(target) fetch origin +refs/heads/feat/carrinho:refs/remotes/origin/feat/carrinho")
    }

    @Test func crossOrgCollisionUsesOwnerSuffix() async throws {
        let runner = RecordingRunner(results: [
            "/usr/bin/git -C \(target) rev-parse --path-format=absolute --git-common-dir": (0, "/code/outra-org/loja/.git\n", ""),
            "/usr/bin/git -C /code/loja rev-parse --path-format=absolute --git-common-dir": (0, "/code/loja/.git\n", "")
        ])
        let path = try await manager(runner, existing: [target]).prepare(pr: .fixture(), clone: clone, purpose: .review)
        #expect(path.path == "/wt/loja-812-acme")
        #expect(runner.commands.contains("/usr/bin/git -C /code/loja worktree add --detach -- /wt/loja-812-acme refs/prumo/pull/812"))
        #expect(!runner.commands.contains { $0.contains("-C \(target) status") || $0.contains("-C \(target) checkout") })
    }

    @Test func crossOrgSuffixTargetIsReusedWhenPresent() async throws {
        let runner = RecordingRunner(results: [
            "/usr/bin/git -C \(target) rev-parse --path-format=absolute --git-common-dir": (0, "/code/outra-org/loja/.git\n", ""),
            "/usr/bin/git -C /code/loja rev-parse --path-format=absolute --git-common-dir": (0, "/code/loja/.git\n", "")
        ])
        let path = try await manager(runner, existing: [target, "/wt/loja-812-acme"]).prepare(pr: .fixture(), clone: clone, purpose: .review)
        #expect(path.path == "/wt/loja-812-acme")
        #expect(runner.commands.last == "/usr/bin/git -C /wt/loja-812-acme checkout --detach refs/prumo/pull/812")
        #expect(!runner.commands.contains { $0.contains("worktree add") })
    }

    @Test func sameRepoTargetIsReusedWithoutSuffix() async throws {
        let runner = RecordingRunner(results: [
            "/usr/bin/git -C \(target) rev-parse --path-format=absolute --git-common-dir": (0, "/code/loja/.git\n", ""),
            "/usr/bin/git -C /code/loja rev-parse --path-format=absolute --git-common-dir": (0, "/code/loja/.git\n", "")
        ])
        let path = try await manager(runner, existing: [target]).prepare(pr: .fixture(), clone: clone, purpose: .review)
        #expect(path.path == target)
    }
}
