import Foundation
import Testing
@testable import PRumoKit

private final class Script: @unchecked Sendable {
    private let lock = NSLock()
    private var steps: [Result<Snapshot, GitHubError>]

    init(_ steps: [Result<Snapshot, GitHubError>]) {
        self.steps = steps
    }

    func next() throws(GitHubError) -> Snapshot {
        let step = lock.withLock { steps.removeFirst() }
        return try step.get()
    }
}

private func temporaryStore() -> (SnapshotStore, URL) {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("prumo-tests-\(UUID().uuidString)")
    return (SnapshotStore(fileURL: directory.appendingPathComponent("snapshot.json")), directory)
}

private func temporaryDirectory() -> URL {
    FileManager.default.temporaryDirectory.appendingPathComponent("prumo-tests-\(UUID().uuidString)")
}

private func coordinator(_ steps: [Result<Snapshot, GitHubError>], store: SnapshotStore) -> RefreshCoordinator {
    let script = Script(steps)
    return RefreshCoordinator(fetch: { () async throws(GitHubError) -> Snapshot in try script.next() }, store: store)
}

private let t1 = Date.fixed.addingTimeInterval(60)
private let t2 = Date.fixed.addingTimeInterval(120)

private func pending() -> Snapshot {
    .fixture(mine: [.fixture(ci: .pending(done: 1, total: 3))], fetchedAt: .fixed)
}

private func failed(at date: Date) -> Snapshot {
    .fixture(mine: [.fixture(ci: .failure(failedChecks: ["lint"], total: 3))], fetchedAt: date)
}

@Suite struct RefreshCoordinatorTests {
    @Test func firstRefreshSavesBaselineWithoutEvents() async {
        let (store, directory) = temporaryStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let result = await coordinator([.success(failed(at: .fixed))], store: store).refresh()
        #expect(result.events.isEmpty)
        #expect(result.state == .ok)
        #expect(result.snapshot == failed(at: .fixed))
        #expect(await store.load() == failed(at: .fixed))
    }

    @Test func secondRefreshEmitsEventsAndSaves() async {
        let (store, directory) = temporaryStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let sut = coordinator([.success(pending()), .success(failed(at: t1))], store: store)
        _ = await sut.refresh()
        let result = await sut.refresh()
        #expect(result.events.map(\.kind) == [.ciFailed])
        #expect(result.state == .ok)
        #expect(await store.load() == failed(at: t1))
    }

    @Test func unauthorizedKeepsStoredSnapshotAndEmitsNothing() async {
        let (store, directory) = temporaryStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let sut = coordinator([.success(pending()), .failure(.unauthorized)], store: store)
        _ = await sut.refresh()
        let result = await sut.refresh()
        #expect(result.state == .unauthorized)
        #expect(result.events.isEmpty)
        #expect(result.snapshot == pending())
        #expect(await store.load() == pending())
    }

    @Test func rateLimitedMapsResetDate() async {
        let (store, directory) = temporaryStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let result = await coordinator([.failure(.rateLimited(resetAt: t2))], store: store).refresh()
        #expect(result.state == .rateLimited(resetAt: t2))
        #expect(result.snapshot == nil)
    }

    @Test func offlineThenBackComparesAgainstStoredSnapshot() async {
        let (store, directory) = temporaryStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let sut = coordinator(
            [.success(pending()), .failure(.network), .failure(.server(status: 502)), .success(failed(at: t2))],
            store: store
        )
        _ = await sut.refresh()
        let offline = await sut.refresh()
        #expect(offline.state == .offline(lastSuccess: .fixed))
        #expect(offline.events.isEmpty)
        #expect(offline.snapshot == pending())
        let stillOffline = await sut.refresh()
        #expect(stillOffline.state == .offline(lastSuccess: .fixed))
        let back = await sut.refresh()
        #expect(back.state == .ok)
        #expect(back.events.map(\.kind) == [.ciFailed])
    }

    @Test func unexpectedResponseIsNotReportedAsOffline() async {
        let (store, directory) = temporaryStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let sut = coordinator([.success(pending()), .failure(.unexpectedResponse)], store: store)
        _ = await sut.refresh()
        let result = await sut.refresh()
        #expect(result.state == .unexpectedResponse(lastSuccess: .fixed))
        #expect(result.snapshot == pending())
        #expect(result.events.isEmpty)
    }

    @Test func concurrentRefreshesEmitEachEventOnce() async {
        let (store, directory) = temporaryStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let sut = coordinator([.success(pending()), .success(failed(at: t1)), .success(failed(at: t2))], store: store)
        _ = await sut.refresh()
        async let first = sut.refresh()
        async let second = sut.refresh()
        let all = await [first, second].flatMap(\.events)
        #expect(all.map(\.kind) == [.ciFailed])
    }

    @Test func failedSaveStillAdvancesBaseline() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let blocker = directory.appendingPathComponent("blocker")
        try Data().write(to: blocker)
        let store = SnapshotStore(fileURL: blocker.appendingPathComponent("snapshot.json"))
        let sut = coordinator(
            [.success(pending()), .success(failed(at: t1)), .success(failed(at: t2))],
            store: store
        )
        _ = await sut.refresh()
        let second = await sut.refresh()
        #expect(second.events.map(\.kind) == [.ciFailed])
        let third = await sut.refresh()
        #expect(third.events.isEmpty)
    }

    @Test func coordinatorPassesOptionsToEngine() async {
        let draft = Snapshot.fixture(toReview: [.fixture(id: "PR_8", number: 8, isDraft: true)], fetchedAt: t1)
        let baseline = Snapshot.fixture(fetchedAt: .fixed)
        let (storeA, dirA) = temporaryStore()
        let (storeB, dirB) = temporaryStore()
        defer {
            try? FileManager.default.removeItem(at: dirA)
            try? FileManager.default.removeItem(at: dirB)
        }
        let ignoring = coordinator([.success(baseline), .success(draft)], store: storeA)
        _ = await ignoring.refresh()
        #expect(await ignoring.refresh().events.isEmpty)
        let including = coordinator([.success(baseline), .success(draft)], store: storeB)
        _ = await including.refresh(options: .init(ignoreDraftReviews: false))
        let result = await including.refresh(options: .init(ignoreDraftReviews: false))
        #expect(result.events.map(\.kind) == [.reviewRequested])
    }

    private func snapshot(_ mergeable: Mergeable, at date: Date) -> Snapshot {
        .fixture(mine: [.fixture(mergeable: mergeable)], fetchedAt: date)
    }

    @Test func conflictNotifiesOnceAcrossUnknown() async {
        let (store, directory) = temporaryStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let sut = coordinator(
            [.success(snapshot(.mergeable, at: .fixed)), .success(snapshot(.unknown, at: t1)), .success(snapshot(.conflicting, at: t2))],
            store: store
        )
        _ = await sut.refresh()
        let unknown = await sut.refresh()
        let conflicting = await sut.refresh()
        #expect(unknown.events.isEmpty)
        #expect(unknown.snapshot?.mine.first?.mergeable == .mergeable)
        #expect(conflicting.events.map(\.kind) == [.conflict])
    }

    @Test func conflictDoesNotRenotifyAcrossUnknown() async {
        let (store, directory) = temporaryStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let t3 = Date.fixed.addingTimeInterval(180)
        let sut = coordinator(
            [
                .success(snapshot(.conflicting, at: .fixed)), .success(snapshot(.unknown, at: t1)),
                .success(snapshot(.conflicting, at: t2)), .success(snapshot(.conflicting, at: t3))
            ],
            store: store
        )
        _ = await sut.refresh()
        let unknown = await sut.refresh()
        let back = await sut.refresh()
        #expect(unknown.events.isEmpty)
        #expect(back.events.isEmpty)
        #expect(await store.load()?.mine.first?.mergeable == .conflicting)
    }

    @Test func coordinatorStampsAccountOnPullRequestsAndEvents() async {
        let (store, directory) = temporaryStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let script = Script([.success(pending()), .success(failed(at: t1))])
        let sut = RefreshCoordinator(
            accountID: "a2", fetch: { () async throws(GitHubError) -> Snapshot in try script.next() }, store: store
        )
        _ = await sut.refresh()
        let result = await sut.refresh()
        #expect(result.events.map(\.accountID) == ["a2"])
        #expect(result.snapshot?.mine.map(\.accountID) == ["a2"])
        #expect(await sut.lastSnapshot()?.accountViewers == ["a2": "adriano"])
    }
}
