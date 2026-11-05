import Foundation
import Testing
@testable import PRumoKit

struct SnapshotStoreTests {
    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("prumo-tests-\(UUID().uuidString)")
    }

    private func richSnapshot() -> Snapshot {
        let review = Review(id: "R1", author: "maria", state: .approved, submittedAt: .fixed)
        let commented = Review(
            id: "R2", author: "joao", state: .commented, submittedAt: .fixed, body: "Veja isso",
            url: URL(string: "https://github.com/acme/loja/pull/812#pullrequestreview-2")!
        )
        let comment = Comment(
            id: "C1", author: "joao", authorIsBot: false, body: "Olá",
            url: URL(string: "https://github.com/acme/loja/pull/812#c1")!, createdAt: .fixed
        )
        return .fixture(
            mine: [
                .fixture(id: "PR_1", ci: .none),
                .fixture(id: "PR_2", ci: .pending(done: 1, total: 3), reviews: [review, commented], comments: [comment], commentCount: 1),
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

    @Test func reviewSavedBeforeBodyAndURLStillDecodes() throws {
        let json = #"{"id":"R1","author":"maria","state":"COMMENTED","submittedAt":800000000}"#
        let review = try JSONDecoder().decode(Review.self, from: Data(json.utf8))
        #expect(review.id == "R1")
        #expect(review.state == .commented)
        #expect(review.body == "")
        #expect(review.url == nil)
        #expect(!review.authorIsBot)
    }

    @Test func oldSnapshotDecodesTargetAndDecisionDefaults() throws {
        let data = try JSONEncoder().encode(PullRequest.fixture(reviewTarget: .team(name: "backend"), reviewDecision: .approved))
        var object = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        object.removeValue(forKey: "reviewTarget")
        object.removeValue(forKey: "reviewDecision")
        let pr = try JSONDecoder().decode(PullRequest.self, from: JSONSerialization.data(withJSONObject: object))
        #expect(pr.reviewTarget == .you)
        #expect(pr.reviewDecision == nil)
    }

    @Test func targetAndDecisionRoundTrip() throws {
        let original = PullRequest.fixture(reviewTarget: .team(name: "backend"), reviewDecision: .changesRequested)
        let decoded = try JSONDecoder().decode(PullRequest.self, from: JSONEncoder().encode(original))
        #expect(decoded == original)
    }

    @Test func oldSnapshotWithoutNewFieldsDecodes() throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(PullRequest.fixture(headRefName: "feat/x", isCrossRepository: true, failedRunID: 7))
        var object = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        object.removeValue(forKey: "headRefName")
        object.removeValue(forKey: "baseRefName")
        object.removeValue(forKey: "isCrossRepository")
        object.removeValue(forKey: "failedRunID")
        let old = try JSONSerialization.data(withJSONObject: object)
        let pr = try JSONDecoder().decode(PullRequest.self, from: old)
        #expect(pr.headRefName == "")
        #expect(pr.baseRefName == "")
        #expect(!pr.isCrossRepository)
        #expect(pr.failedRunID == nil)
        #expect(pr.id == "PR_812")
    }

    @Test func oldSnapshotWithoutFailedRunNameDecodes() throws {
        let data = try JSONEncoder().encode(PullRequest.fixture(failedRunID: 7, failedRunName: "build"))
        var object = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        object.removeValue(forKey: "failedRunName")
        let old = try JSONSerialization.data(withJSONObject: object)
        let pr = try JSONDecoder().decode(PullRequest.self, from: old)
        #expect(pr.failedRunName == nil)
        #expect(pr.failedRunID == 7)
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

    @Test func oldSnapshotWithoutMergedTodayDecodes() throws {
        let original = Snapshot.fixture(mine: [.fixture(id: "PR_1")])
        let encoded = try JSONEncoder().encode(original)
        var object = try JSONSerialization.jsonObject(with: encoded) as! [String: Any]
        object.removeValue(forKey: "mergedToday")
        let legacy = try JSONSerialization.data(withJSONObject: object)
        let decoded = try JSONDecoder().decode(Snapshot.self, from: legacy)
        #expect(decoded.mergedToday.isEmpty)
        #expect(decoded.mine == original.mine)
    }

    @Test func oldSnapshotJSONWithoutAccountDecodes() throws {
        let snapshot = Snapshot.fixture(
            mine: [.fixture(id: "PR_1", accountID: "a1")],
            toReview: [.fixture(id: "PR_2", accountID: "a1")],
            mergedToday: [MergedPullRequest(
                id: "PR_3", number: 3, title: "Merge", url: URL(string: "https://github.com/acme/loja/pull/3")!,
                repository: "acme/loja", mergedAt: .fixed, accountID: "a1"
            )],
            accountViewers: ["a1": "adriano"]
        )
        var root = try JSONSerialization.jsonObject(with: JSONEncoder().encode(snapshot)) as! [String: Any]
        root.removeValue(forKey: "accountViewers")
        for key in ["mine", "toReview", "mergedToday"] {
            root[key] = (root[key] as! [[String: Any]]).map { item in
                var copy = item
                copy.removeValue(forKey: "accountID")
                return copy
            }
        }
        let decoded = try JSONDecoder().decode(Snapshot.self, from: JSONSerialization.data(withJSONObject: root))
        #expect(decoded.accountViewers == [:])
        #expect(decoded.mine.first?.accountID == "")
        #expect(decoded.toReview.first?.accountID == "")
        #expect(decoded.mergedToday.first?.accountID == "")
    }

    @Test func stampedSetsAccountOnEveryItem() {
        let merged = MergedPullRequest(
            id: "PR_3", number: 3, title: "Merge", url: URL(string: "https://github.com/acme/loja/pull/3")!,
            repository: "acme/loja", mergedAt: .fixed
        )
        let stamped = Snapshot.fixture(
            viewer: "adrianogl", mine: [.fixture(id: "PR_1")], toReview: [.fixture(id: "PR_2")], mergedToday: [merged]
        ).stamped(accountID: "a2")
        #expect(stamped.mine.map(\.accountID) == ["a2"])
        #expect(stamped.toReview.map(\.accountID) == ["a2"])
        #expect(stamped.mergedToday.map(\.accountID) == ["a2"])
        #expect(stamped.accountViewers == ["a2": "adrianogl"])
    }

    @Test func viewerForUsesAccountMap() {
        let snapshot = Snapshot.fixture(viewer: "adrianogl", accountViewers: ["a1": "adrianogl", "a2": "adriano-globex"])
        #expect(snapshot.viewer(for: .fixture(accountID: "a2")) == "adriano-globex")
    }

    @Test func viewerForFallsBackToViewer() {
        let snapshot = Snapshot.fixture(viewer: "adrianogl", accountViewers: ["a1": "adrianogl"])
        #expect(snapshot.viewer(for: .fixture(accountID: "")) == "adrianogl")
        #expect(snapshot.viewer(for: .fixture(accountID: "a9")) == "adrianogl")
    }
}
