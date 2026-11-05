import Foundation
import Testing
@testable import PRumoKit

private actor StartCounter {
    private var started = 0

    func start() {
        started += 1
    }

    func count() -> Int {
        started
    }
}

private final class CallCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var calls = 0

    func increment() {
        lock.withLock { calls += 1 }
    }

    var value: Int {
        lock.withLock { calls }
    }
}

private func temporaryStore() -> (SnapshotStore, URL) {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("prumo-tests-\(UUID().uuidString)")
    return (SnapshotStore(fileURL: directory.appendingPathComponent("snapshot.json")), directory)
}

private let savedAt = ISO8601DateFormatter().date(from: "2026-11-05T10:40:00Z")!

private func snapshot(at date: Date = .fixed, viewer: String = "mariana") -> Snapshot {
    .fixture(viewer: viewer, mine: [.fixture(ci: .pending(done: 1, total: 3))], fetchedAt: date)
}

@Suite struct ParallelRefreshTests {
    @Test func oneAccountFailingKeepsOthersFresh() async throws {
        let (storeA, dirA) = temporaryStore()
        let (storeB, dirB) = temporaryStore()
        defer {
            try? FileManager.default.removeItem(at: dirA)
            try? FileManager.default.removeItem(at: dirB)
        }
        try await storeB.save(snapshot(at: savedAt, viewer: "rafael"))
        let accountA = RefreshCoordinator(
            accountID: "a1", fetch: { () async throws(GitHubError) -> Snapshot in snapshot() }, store: storeA
        )
        let accountB = RefreshCoordinator(
            accountID: "b2", fetch: { () async throws(GitHubError) -> Snapshot in throw .network }, store: storeB
        )
        let results = await ParallelRefresh.run(
            [("a1", accountA), ("b2", accountB)], previous: [:], options: .init(), now: .fixed
        )
        #expect(results.map(\.accountID) == ["a1", "b2"])
        #expect(results[0].state == .ok)
        #expect(results[0].snapshot == snapshot().stamped(accountID: "a1"))
        #expect(results[1].state == .offline(lastSuccess: savedAt))
        #expect(results[1].snapshot == snapshot(at: savedAt, viewer: "rafael"))
        #expect(results[1].events.isEmpty)
    }

    @Test func resultsKeepAccountOrder() async {
        let (storeA, dirA) = temporaryStore()
        let (storeB, dirB) = temporaryStore()
        defer {
            try? FileManager.default.removeItem(at: dirA)
            try? FileManager.default.removeItem(at: dirB)
        }
        let slow = RefreshCoordinator(
            accountID: "a1",
            fetch: { () async throws(GitHubError) -> Snapshot in
                try? await Task.sleep(for: .milliseconds(100))
                return snapshot()
            },
            store: storeA
        )
        let fast = RefreshCoordinator(
            accountID: "b2", fetch: { () async throws(GitHubError) -> Snapshot in snapshot() }, store: storeB
        )
        let results = await ParallelRefresh.run(
            [("a1", slow), ("b2", fast)], previous: [:], options: .init(), now: .fixed
        )
        #expect(results.map(\.accountID) == ["a1", "b2"])
        #expect(results.map(\.state) == [.ok, .ok])
    }

    @Test func runsConcurrently() async {
        let (storeA, dirA) = temporaryStore()
        let (storeB, dirB) = temporaryStore()
        defer {
            try? FileManager.default.removeItem(at: dirA)
            try? FileManager.default.removeItem(at: dirB)
        }
        let counter = StartCounter()
        let waitForBoth: RefreshCoordinator.Fetch = { () async throws(GitHubError) -> Snapshot in
            await counter.start()
            let deadline = ContinuousClock.now.advanced(by: .seconds(1))
            while await counter.count() < 2 {
                guard ContinuousClock.now < deadline else { throw .network }
                try? await Task.sleep(for: .milliseconds(5))
            }
            return snapshot()
        }
        let results = await ParallelRefresh.run(
            [
                ("a1", RefreshCoordinator(accountID: "a1", fetch: waitForBoth, store: storeA)),
                ("b2", RefreshCoordinator(accountID: "b2", fetch: waitForBoth, store: storeB))
            ],
            previous: [:], options: .init(), now: .fixed
        )
        #expect(results.map(\.state) == [.ok, .ok])
    }

    @Test func rateLimitedAccountSkippedUntilReset() async throws {
        let (store, directory) = temporaryStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        try await store.save(snapshot(at: savedAt))
        let calls = CallCounter()
        let sut = RefreshCoordinator(
            accountID: "a1",
            fetch: { () async throws(GitHubError) -> Snapshot in
                calls.increment()
                return snapshot()
            },
            store: store
        )
        let resetAt = Date.fixed.addingTimeInterval(300)
        let limited: [String: ConnectionState] = ["a1": .rateLimited(resetAt: resetAt)]

        let before = await ParallelRefresh.run([("a1", sut)], previous: limited, options: .init(), now: .fixed)
        #expect(calls.value == 0)
        #expect(before[0].state == .rateLimited(resetAt: resetAt))
        #expect(before[0].snapshot == snapshot(at: savedAt))
        #expect(before[0].events.isEmpty)

        let after = await ParallelRefresh.run(
            [("a1", sut)], previous: limited, options: .init(), now: resetAt.addingTimeInterval(1)
        )
        #expect(calls.value == 1)
        #expect(after[0].state == .ok)
    }

    @Test func unauthorizedAccountNotRefreshed() async throws {
        let (store, directory) = temporaryStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        try await store.save(snapshot(at: savedAt))
        let calls = CallCounter()
        let sut = RefreshCoordinator(
            accountID: "a1",
            fetch: { () async throws(GitHubError) -> Snapshot in
                calls.increment()
                return snapshot()
            },
            store: store
        )
        let results = await ParallelRefresh.run(
            [("a1", sut)], previous: ["a1": .unauthorized], options: .init(), now: .fixed
        )
        #expect(calls.value == 0)
        #expect(results[0].state == .unauthorized)
        #expect(results[0].snapshot == snapshot(at: savedAt))
        #expect(results[0].events.isEmpty)
    }

    @Test func newAccountFirstRefreshHasNoEvents() async {
        let (store, directory) = temporaryStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let busy = Snapshot.fixture(
            viewer: "rafael",
            mine: [.fixture(ci: .failure(failedChecks: ["lint"], total: 3))],
            toReview: [.fixture(id: "PR_77", number: 77, author: "carla", reviewRequestedAt: .fixed)]
        )
        let sut = RefreshCoordinator(
            accountID: "c3", fetch: { () async throws(GitHubError) -> Snapshot in busy }, store: store
        )
        let results = await ParallelRefresh.run([("c3", sut)], previous: [:], options: .init(), now: .fixed)
        #expect(results[0].state == .ok)
        #expect(results[0].events.isEmpty)
    }

    @Test func scheduleSkipsOnlyBlockedStates() {
        let later = Date.fixed.addingTimeInterval(60)
        #expect(AccountSchedule.shouldRefresh(nil, now: .fixed))
        #expect(AccountSchedule.shouldRefresh(.ok, now: .fixed))
        #expect(AccountSchedule.shouldRefresh(.offline(lastSuccess: savedAt), now: .fixed))
        #expect(AccountSchedule.shouldRefresh(.unexpectedResponse(lastSuccess: nil), now: .fixed))
        #expect(AccountSchedule.shouldRefresh(.rateLimited(resetAt: nil), now: .fixed))
        #expect(AccountSchedule.shouldRefresh(.rateLimited(resetAt: .fixed), now: .fixed))
        #expect(!AccountSchedule.shouldRefresh(.rateLimited(resetAt: later), now: .fixed))
        #expect(!AccountSchedule.shouldRefresh(.unauthorized, now: .fixed))
    }

    @Test func statusFlagsProblemOnlyForNonOkState() {
        #expect(!AccountStatus().isProblem)
        #expect(!AccountStatus(state: .ok, lastSuccess: .fixed).isProblem)
        #expect(AccountStatus(state: .unauthorized).isProblem)
        #expect(AccountStatus(state: .offline(lastSuccess: savedAt), lastSuccess: savedAt).isProblem)
    }
}
