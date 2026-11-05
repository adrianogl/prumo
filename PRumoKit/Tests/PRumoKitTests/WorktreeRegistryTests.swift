import Foundation
import Testing
@testable import PRumoKit

private func tempURL() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("prumo-wt-\(UUID().uuidString)")
        .appendingPathComponent("worktrees.json")
}

private func record(_ id: String, number: Int = 1, path: String? = nil) -> WorktreeRecord {
    WorktreeRecord(pullRequestID: id, number: number, path: path ?? "/wt/loja-\(number)", clone: "/code/loja")
}

@Suite struct WorktreeRegistryTests {
    @Test func staleWhenPRLeftBothLists() {
        let open = PullRequest.fixture(id: "PR_1")
        let snapshot = Snapshot.fixture(mine: [open], toReview: [])
        let records = [record("PR_1", number: 1), record("PR_2", number: 2)]
        #expect(WorktreeCleanup.stale(records: records, snapshot: snapshot).map(\.pullRequestID) == ["PR_2"])
    }

    @Test func notStaleWhileInReview() {
        let reviewing = PullRequest.fixture(id: "PR_3")
        let snapshot = Snapshot.fixture(mine: [], toReview: [reviewing])
        #expect(WorktreeCleanup.stale(records: [record("PR_3", number: 3)], snapshot: snapshot).isEmpty)
    }

    @Test func confirmedClosedKeepsOnlyClosedOrMerged() {
        let records = [record("OPEN1", number: 1), record("GONE", number: 2), record("MRG", number: 3), record("CLS", number: 4)]
        let states: [String: PRState] = ["OPEN1": .open, "MRG": .merged, "CLS": .closed]
        #expect(WorktreeCleanup.confirmedClosed(candidates: records, states: states).map(\.pullRequestID) == ["MRG", "CLS"])
    }

    @Test func registryRoundTrip() async {
        let url = tempURL()
        let registry = WorktreeRegistry(fileURL: url)
        await registry.add(record("PR_1", number: 1))
        await registry.add(record("PR_2", number: 2))
        let reloaded = WorktreeRegistry(fileURL: url)
        #expect(await reloaded.records().map(\.path) == ["/wt/loja-1", "/wt/loja-2"])
        await reloaded.remove(path: "/wt/loja-1")
        #expect(await WorktreeRegistry(fileURL: url).records().map(\.path) == ["/wt/loja-2"])
    }

    @Test func addDedupesByPath() async {
        let registry = WorktreeRegistry(fileURL: tempURL())
        await registry.add(record("PR_1", number: 1))
        await registry.add(record("PR_1", number: 1))
        #expect(await registry.records().count == 1)
    }

    @Test func corruptFileIsEmpty() async throws {
        let url = tempURL()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: url)
        let registry = WorktreeRegistry(fileURL: url)
        #expect(await registry.records().isEmpty)
        await registry.add(record("PR_1"))
        #expect(await registry.records().count == 1)
    }

    @Test func missingNumberDecodesAsZero() throws {
        let json = Data(#"{"pullRequestID":"PR_1","path":"/wt/a","clone":"/c"}"#.utf8)
        let decoded = try JSONDecoder().decode(WorktreeRecord.self, from: json)
        #expect(decoded.number == 0)
    }

    @Test func externalPathNotRegistered() {
        let pr = PullRequest.fixture(id: "PR_812", number: 812)
        let root = URL(fileURLWithPath: "/wt")
        let clone = URL(fileURLWithPath: "/code/loja")
        let inside = WorktreeRecord.registrable(
            pr: pr, directory: URL(fileURLWithPath: "/wt/loja-812"), clone: clone, worktreesRoot: root)
        #expect(inside == WorktreeRecord(pullRequestID: "PR_812", number: 812, path: "/wt/loja-812", clone: "/code/loja"))
        #expect(WorktreeRecord.registrable(
            pr: pr, directory: URL(fileURLWithPath: "/code/loja"), clone: clone, worktreesRoot: root) == nil)
        #expect(WorktreeRecord.registrable(
            pr: pr, directory: URL(fileURLWithPath: "/wt-other/loja-812"), clone: clone, worktreesRoot: root) == nil)
    }

    @Test func worktreeRecordWithoutAccountDecodes() throws {
        let json = #"{"pullRequestID":"PR_1","number":1,"path":"/wt/loja-1","clone":"/code/loja"}"#
        let decoded = try JSONDecoder().decode(WorktreeRecord.self, from: Data(json.utf8))
        #expect(decoded.accountID == nil)
    }

    @Test func registrableRecordsAccountWhenPresent() {
        let root = URL(fileURLWithPath: "/wt")
        let directory = URL(fileURLWithPath: "/wt/loja-1")
        let clone = URL(fileURLWithPath: "/code/loja")
        let withAccount = WorktreeRecord.registrable(
            pr: .fixture(accountID: "a2"), directory: directory, clone: clone, worktreesRoot: root)
        let withoutAccount = WorktreeRecord.registrable(
            pr: .fixture(), directory: directory, clone: clone, worktreesRoot: root)
        #expect(withAccount?.accountID == "a2")
        #expect(withoutAccount?.accountID == nil)
    }
}
