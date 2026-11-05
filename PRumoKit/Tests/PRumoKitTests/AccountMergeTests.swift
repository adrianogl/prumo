import Foundation
import Testing
@testable import PRumoKit

@Suite struct AccountMergeTests {
    let failure = CIStatus.failure(failedChecks: ["build"], total: 3)

    func part(_ accountID: String, viewer: String = "ana", mine: [PullRequest] = [], toReview: [PullRequest] = [],
              merged: [MergedPullRequest] = [], fetchedAt: Date = .fixed) -> AccountPart {
        AccountPart(
            accountID: accountID,
            snapshot: Snapshot.fixture(
                viewer: viewer, mine: mine, toReview: toReview, mergedToday: merged, fetchedAt: fetchedAt
            ).stamped(accountID: accountID)
        )
    }

    func event(_ kind: NotificationKind, _ id: String, account: String) -> NotificationEvent {
        NotificationEvent(
            kind: kind, pullRequestID: id, title: "t", body: "b",
            url: URL(string: "https://github.com/acme/loja/pull/1")!, accountID: account
        )
    }

    func merged(_ id: String) -> MergedPullRequest {
        MergedPullRequest(
            id: id, number: 1, title: "t", url: URL(string: "https://github.com/acme/loja/pull/1")!,
            repository: "acme/loja", mergedAt: .fixed
        )
    }

    @Test func prAuthoredInOneAndRequestedInOtherStaysInMine() throws {
        let a = part("A", mine: [.fixture(id: "X")])
        let b = part("B", toReview: [.fixture(id: "X")])
        let combined = try #require(AccountMerge.combine([a, b]))
        #expect(combined.mine.map(\.accountID) == ["A"])
        #expect(combined.toReview.isEmpty)
    }

    @Test func authoredInSecondAccountStaysInMineEvenWhenFirstListsItToReview() throws {
        let a = part("A", toReview: [.fixture(id: "X")])
        let b = part("B", mine: [.fixture(id: "X")])
        let combined = try #require(AccountMerge.combine([a, b]))
        #expect(combined.mine.map(\.accountID) == ["B"])
        #expect(combined.toReview.isEmpty)
    }

    @Test func reviewSeenByTwoAccountsBelongsToFirstInList() throws {
        let a = part("A", toReview: [.fixture(id: "Y")])
        let b = part("B", toReview: [.fixture(id: "Y")])
        let combined = try #require(AccountMerge.combine([b, a]))
        #expect(combined.toReview.map(\.accountID) == ["B"])
    }

    @Test func reviewRequestedEventFromNonOwnerDropped() throws {
        let a = part("A", mine: [.fixture(id: "X")])
        let b = part("B", toReview: [.fixture(id: "X")])
        let combined = try #require(AccountMerge.combine([a, b]))
        let result = AccountMerge.events(
            [("A", []), ("B", [event(.reviewRequested, "X", account: "B")])], combined: combined
        )
        #expect(result.isEmpty)
    }

    @Test func sameEventFromTwoAccountsDeliveredOnce() throws {
        let a = part("A", toReview: [.fixture(id: "Y")])
        let b = part("B", toReview: [.fixture(id: "Y")])
        let combined = try #require(AccountMerge.combine([a, b]))
        let result = AccountMerge.events(
            [("A", [event(.newComment, "Y", account: "A")]), ("B", [event(.newComment, "Y", account: "B")])],
            combined: combined
        )
        #expect(result.map(\.accountID) == ["A"])
    }

    @Test func eventsKeepAccountOrderAndDifferentKinds() throws {
        let a = part("A", mine: [.fixture(id: "X")])
        let b = part("B", toReview: [.fixture(id: "Y")])
        let combined = try #require(AccountMerge.combine([a, b]))
        let result = AccountMerge.events(
            [
                ("A", [event(.ciFailed, "X", account: "A"), event(.approved, "X", account: "A")]),
                ("B", [event(.reviewRequested, "Y", account: "B"), event(.reviewRequested, "Z", account: "B")])
            ],
            combined: combined
        )
        #expect(result.map(\.kind) == [.ciFailed, .approved, .reviewRequested])
        #expect(result.map(\.pullRequestID) == ["X", "X", "Y"])
    }

    @Test func mergedTodayDeduplicated() throws {
        let a = part("A", merged: [merged("M1")])
        let b = part("B", merged: [merged("M1"), merged("M2")])
        let combined = try #require(AccountMerge.combine([a, b]))
        #expect(combined.mergedToday.map(\.id) == ["M1", "M2"])
        #expect(combined.mergedToday.map(\.accountID) == ["A", "B"])
    }

    @Test func singleAccountCombineKeepsContent() throws {
        let a = part("A", mine: [.fixture(id: "X")], toReview: [.fixture(id: "Y")], merged: [merged("M1")])
        let combined = try #require(AccountMerge.combine([a]))
        #expect(combined == a.snapshot)
    }

    @Test func viewerFetchedAtAndViewersCombined() throws {
        let later = Date.fixed.addingTimeInterval(60)
        let a = part("A", viewer: "ana")
        let b = part("B", viewer: "bia", fetchedAt: later)
        let combined = try #require(AccountMerge.combine([a, b]))
        #expect(combined.viewer == "ana")
        #expect(combined.fetchedAt == later)
        #expect(combined.accountViewers == ["A": "ana", "B": "bia"])
    }

    @Test func emptyPartsIsNil() {
        #expect(AccountMerge.combine([]) == nil)
    }

    @Test func widgetAndCounterSumCombined() throws {
        let a = part("A", mine: [.fixture(id: "F", ci: failure)], toReview: [.fixture(id: "R1")])
        let b = part("B", toReview: [.fixture(id: "R1"), .fixture(id: "R2")])
        let combined = try #require(AccountMerge.combine([a, b]))
        #expect(Counters.reviewBadge(combined, ignoreDrafts: true, includeTeam: true) == 2)
        let widget = WidgetSummary.make(
            snapshot: combined, ignoreDrafts: true, includeTeam: true, muted: [], staleLimit: 24 * 3600, now: .fixed
        )
        #expect(widget.toReview == 2)
        #expect(widget.ciFailing == 1)
    }
}
