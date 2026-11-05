import Foundation
import Testing
@testable import PRumoKit

struct SnapshotStoreTests {
    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("prumo-tests-\(UUID().uuidString)")
    }

    private func richSnapshot() -> Snapshot {
        let review = Review(id: "R1", author: "maria", state: .approved, submittedAt: .fixed)
        let comment = Comment(
            id: "C1", author: "joao", authorIsBot: false, body: "Olá",
            url: URL(string: "https://github.com/acme/loja/pull/812#c1")!, createdAt: .fixed
        )
        return .fixture(
            mine: [
                .fixture(id: "PR_1", ci: .none),
                .fixture(id: "PR_2", ci: .pending(done: 1, total: 3), reviews: [review], comments: [comment], commentCount: 1),
                .fixture(id: "PR_3", ci: .success(total: 3), reviewRequestedAt: .fixed),
            ],
            toReview: [.fixture(id: "PR_4", ci: .failure(failedChecks: ["build", "lint"], total: 4))]
        )
    }

    @Test func roundTripsSnapshot() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = SnapshotStore(fileURL: directory.appendingPathComponent("snapshot.json"))
        let snapshot = richSnapshot()
        try await store.save(snapshot)
        #expect(await store.load() == snapshot)
    }

    @Test func missingFileReturnsNil() async {
        let directory = temporaryDirectory()
        let store = SnapshotStore(fileURL: directory.appendingPathComponent("snapshot.json"))
        #expect(await store.load() == nil)
    }

    @Test func corruptFileReturnsNil() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("snapshot.json")
        try Data("{".utf8).write(to: url)
        let store = SnapshotStore(fileURL: url)
        #expect(await store.load() == nil)
    }

    @Test func saveCreatesMissingDirectoryAndOverwrites() async throws {
        let directory = temporaryDirectory().appendingPathComponent("nested/dir")
        defer { try? FileManager.default.removeItem(at: directory.deletingLastPathComponent().deletingLastPathComponent()) }
        let url = directory.appendingPathComponent("snapshot.json")
        let store = SnapshotStore(fileURL: url)
        try await store.save(.fixture(viewer: "primeiro"))
        try await store.save(.fixture(viewer: "segundo"))
        #expect(FileManager.default.fileExists(atPath: url.path))
        #expect(await store.load()?.viewer == "segundo")
        let contents = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        #expect(contents == ["snapshot.json"])
    }

    @Test func defaultURLPointsToApplicationSupport() {
        let url = SnapshotStore.defaultURL()
        #expect(url.path.hasSuffix("Library/Application Support/PRumo/snapshot.json"))
    }

    @Test func deleteRemovesFile() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = SnapshotStore(fileURL: directory.appendingPathComponent("snapshot.json"))
        try await store.save(.fixture())
        await store.delete()
        #expect(await store.load() == nil)
    }
}
