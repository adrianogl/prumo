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
}
