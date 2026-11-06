import Foundation
import Testing
@testable import PRumoKit

struct TerminalSessionRegistryTests {
    private let dir = URL(fileURLWithPath: "/h/Code/.prumo-worktrees/loja-812")

    private func info(_ pr: String, _ purpose: SessionPurpose = .review) -> TerminalSessionInfo {
        TerminalSessionInfo(pullRequestID: pr, reference: "#\(pr)", purpose: purpose, directory: dir, startedAt: .fixed)
    }

    @Test func createsWhenNoSessionAndFocusesNewOne() {
        var registry = TerminalSessionRegistry()
        #expect(registry.decision(forPullRequest: "A", purpose: .review) == .create)
        let a = info("A")
        registry.add(a)
        #expect(registry.focusedID == a.id)
        #expect(registry.hasLiveSessions)
    }

    @Test func samePurposeOnLiveSessionFocusesItDifferentPurposeAsks() {
        var registry = TerminalSessionRegistry()
        let a = info("A", .fixCI)
        registry.add(a)
        #expect(registry.decision(forPullRequest: "A", purpose: .fixCI) == .focus(a.id))
        #expect(registry.decision(forPullRequest: "A", purpose: .review) == .askToReplace(a.id))
    }

    @Test func exitedSessionIsReplacedWithoutAsking() {
        var registry = TerminalSessionRegistry()
        let a = info("A")
        registry.add(a)
        registry.exited(a.id, code: 0)
        #expect(registry.decision(forPullRequest: "A", purpose: .fixCI) == .create)
        let replacement = info("A", .fixCI)
        registry.add(replacement)
        #expect(registry.sessions.map(\.id) == [replacement.id])
        #expect(registry.hasLiveSessions)
    }

    @Test func bellMarksAttentionOnlyWhenNotFocusedAndFocusClearsIt() {
        var registry = TerminalSessionRegistry()
        let a = info("A")
        let b = info("B")
        registry.add(a)
        registry.add(b)
        registry.bell(b.id)
        #expect(registry.session(id: b.id)?.status == .running)
        registry.bell(a.id)
        #expect(registry.session(id: a.id)?.status == .attention)
        registry.focus(pullRequest: "A")
        #expect(registry.session(id: a.id)?.status == .running)
        #expect(registry.focusedID == a.id)
    }

    @Test func bellIgnoredAfterExit() {
        var registry = TerminalSessionRegistry()
        let a = info("A")
        let b = info("B")
        registry.add(a)
        registry.add(b)
        registry.exited(a.id, code: 3)
        registry.bell(a.id)
        #expect(registry.session(id: a.id)?.status == .exited(code: 3))
        #expect(registry.hasLiveSessions)
        registry.exited(b.id, code: 0)
        #expect(!registry.hasLiveSessions)
    }

    @Test func closeFocusesNeighbour() {
        var registry = TerminalSessionRegistry()
        let a = info("A"), b = info("B"), c = info("C")
        [a, b, c].forEach { registry.add($0) }
        registry.focus(b.id)
        registry.close(b.id)
        #expect(registry.focusedID == c.id)
        registry.close(c.id)
        #expect(registry.focusedID == a.id)
        registry.close(a.id)
        #expect(registry.focusedID == nil)
        #expect(registry.sessions.isEmpty)
    }

    @Test func nextCyclesThroughSessions() {
        var registry = TerminalSessionRegistry()
        let a = info("A"), b = info("B")
        registry.add(a)
        registry.add(b)
        #expect(registry.next(after: a.id) == b.id)
        #expect(registry.next(after: b.id) == a.id)
        #expect(registry.next(after: nil) == a.id)
        #expect(TerminalSessionRegistry().next(after: nil) == nil)
    }
}
