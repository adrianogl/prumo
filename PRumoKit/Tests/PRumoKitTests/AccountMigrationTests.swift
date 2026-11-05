import Foundation
import Testing
@testable import PRumoKit

@Suite struct AccountMigrationTests {
    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("prumo-tests-\(UUID().uuidString)")
    }

    private func stage7Snapshot() -> Snapshot {
        let review = Review(id: "R1", author: "maria", state: .approved, submittedAt: .fixed)
        let comment = Comment(
            id: "C1", author: "joao", authorIsBot: false, body: "Olá",
            url: URL(string: "https://github.com/acme/loja/pull/812#c1")!, createdAt: .fixed
        )
        return .fixture(
            viewer: "adrianogl",
            mine: [
                .fixture(id: "PR_1", ci: .failure(failedChecks: ["lint"], total: 3), mergeable: .conflicting),
                .fixture(id: "PR_2", ci: .success(total: 3), reviews: [review], comments: [comment], commentCount: 1),
            ],
            toReview: [.fixture(id: "PR_3", author: "maria", reviewRequestedAt: .fixed)],
            mergedToday: [MergedPullRequest(
                id: "PR_4", number: 4, title: "Merge", url: URL(string: "https://github.com/acme/loja/pull/4")!,
                repository: "acme/loja", mergedAt: .fixed
            )]
        )
    }

    private func stage7JSON(_ snapshot: Snapshot) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        var root = try JSONSerialization.jsonObject(with: encoder.encode(snapshot)) as! [String: Any]
        root.removeValue(forKey: "accountViewers")
        for key in ["mine", "toReview", "mergedToday"] {
            root[key] = (root[key] as! [[String: Any]]).map { item in
                var copy = item
                copy.removeValue(forKey: "accountID")
                return copy
            }
        }
        return try JSONSerialization.data(withJSONObject: root)
    }

    @Test func migratesOnboardedLegacyAccount() {
        let legacy = LegacyAccountState(login: "adrianogl", origin: .ghCLI, onboardingDone: true)
        let account = AccountMigration.account(from: legacy, existing: nil)
        #expect(account?.id == "github-legacy")
        #expect(account?.id == AccountMigration.legacyAccountID)
        #expect(account?.provider == .github)
        #expect(account?.host == "github.com")
        #expect(account?.login == "adrianogl")
        #expect(account?.origin == .ghCLI)
        #expect(account?.nickname == "")
    }

    @Test func migratedAccountWithoutLoginOrOriginUsesDefaults() {
        let legacy = LegacyAccountState(login: nil, origin: nil, onboardingDone: true)
        let account = AccountMigration.account(from: legacy, existing: nil)
        #expect(account?.id == "github-legacy")
        #expect(account?.login == "")
        #expect(account?.origin == .pasted)
    }

    @Test func noMigrationWhenListExists() {
        let legacy = LegacyAccountState(login: "adrianogl", origin: .ghCLI, onboardingDone: true)
        let existing = AccountList(accounts: [Account(id: "a1", login: "fulano-dev", origin: .pasted)])
        #expect(AccountMigration.account(from: legacy, existing: existing) == nil)
        #expect(AccountMigration.account(from: legacy, existing: AccountList()) == nil)
    }

    @Test func noMigrationWhenSavedListIsCorrupt() {
        let legacy = LegacyAccountState(login: "adrianogl", origin: .ghCLI, onboardingDone: true)
        let corrupt = AccountList.decode(Data("{nao é json".utf8))
        #expect(corrupt != nil)
        #expect(AccountMigration.account(from: legacy, existing: corrupt) == nil)
    }

    @Test func noMigrationBeforeOnboarding() {
        let legacy = LegacyAccountState(login: "adrianogl", origin: .ghCLI, onboardingDone: false)
        #expect(AccountMigration.account(from: legacy, existing: nil) == nil)
    }

    @Test func legacyAccountKeepsLegacyStorageNames() {
        #expect(AccountStorage.keychainAccount(for: "github-legacy") == "github-token")
        #expect(AccountStorage.snapshotURL(for: "github-legacy") == SnapshotStore.defaultURL())
        let id = "6F1C2A3B-0000-4000-8000-000000000001"
        #expect(AccountStorage.keychainAccount(for: id) == "token-\(id)")
        let url = AccountStorage.snapshotURL(for: id)
        #expect(url.lastPathComponent == "\(id).json")
        #expect(url.deletingLastPathComponent().lastPathComponent == "snapshots")
        #expect(url.deletingLastPathComponent().deletingLastPathComponent() == SnapshotStore.defaultURL().deletingLastPathComponent())
    }

    @Test func remindersBaselinedForMigratedAccount() {
        let migrated = Account(id: "github-legacy", login: "adrianogl", origin: .ghCLI)
        let state = ReminderState(initialized: true, reminded: ["PR_1@aaa111"], viewer: "adrianogl")
        let result = AccountMigration.reminders(state, migrated: migrated)
        #expect(result.baselined == ["github-legacy"])
        #expect(result.reminded == ["PR_1@aaa111"])
        #expect(result.initialized)
        #expect(result.viewer == "adrianogl")
    }

    @Test func remindersBaselinedWhenViewerUnknown() {
        let migrated = Account(id: "github-legacy", login: "", origin: .pasted)
        let state = ReminderState(initialized: true, reminded: ["PR_1@aaa111"])
        #expect(AccountMigration.reminders(state, migrated: migrated).baselined == ["github-legacy"])
    }

    @Test func remindersUnchangedWhenNotInitializedOrOtherViewer() {
        let migrated = Account(id: "github-legacy", login: "adrianogl", origin: .ghCLI)
        let fresh = ReminderState()
        #expect(AccountMigration.reminders(fresh, migrated: migrated) == fresh)
        let other = ReminderState(initialized: true, reminded: ["PR_1@aaa111"], viewer: "fulano-dev")
        #expect(AccountMigration.reminders(other, migrated: migrated) == other)
    }

    @Test func migratedFirstRefreshProducesNoEvents() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let fileURL = directory.appendingPathComponent("snapshot.json")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let content = stage7Snapshot()
        try stage7JSON(content).write(to: fileURL)
        let store = SnapshotStore(fileURL: fileURL)
        #expect(await store.load()?.mine.map(\.accountID) == ["", ""])
        let sut = RefreshCoordinator(
            accountID: AccountMigration.legacyAccountID,
            fetch: { () async throws(GitHubError) -> Snapshot in content },
            store: store
        )
        let result = await sut.refresh()
        #expect(result.events.isEmpty)
        #expect(result.state == .ok)
        #expect(result.snapshot?.mine.map(\.accountID) == ["github-legacy", "github-legacy"])
        #expect(result.snapshot?.toReview.map(\.accountID) == ["github-legacy"])
        #expect(result.snapshot?.mergedToday.map(\.accountID) == ["github-legacy"])
        #expect(await store.load()?.mine.map(\.accountID) == ["github-legacy", "github-legacy"])
    }
}
