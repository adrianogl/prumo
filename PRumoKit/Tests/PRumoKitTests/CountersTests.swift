import Foundation
import Testing
@testable import PRumoKit

@Suite struct CountersTests {
    @Test func reviewBadgeExcludesTeamAndIgnoredDrafts() {
        let snapshot = Snapshot.fixture(toReview: [
            .fixture(id: "A", number: 1),
            .fixture(id: "B", number: 2, isDraft: true),
            .fixture(id: "C", number: 3, reviewTarget: .team(name: "time"))
        ])
        #expect(Counters.reviewBadge(snapshot, ignoreDrafts: true, includeTeam: false) == 1)
        #expect(Counters.reviewBadge(snapshot, ignoreDrafts: false, includeTeam: false) == 2)
    }

    @Test func reviewBadgeCountsTeamWhenIncluded() {
        let snapshot = Snapshot.fixture(toReview: [
            .fixture(id: "A", number: 1),
            .fixture(id: "B", number: 2, isDraft: true),
            .fixture(id: "C", number: 3, reviewTarget: .team(name: "time"))
        ])
        #expect(Counters.reviewBadge(snapshot, ignoreDrafts: true, includeTeam: true) == 2)
        #expect(Counters.reviewBadge(snapshot, ignoreDrafts: false, includeTeam: true) == 3)
    }

    @Test func visibleReviewsRespectDraftAndTeamOptions() {
        let prs: [PullRequest] = [
            .fixture(id: "A", number: 1),
            .fixture(id: "B", number: 2, isDraft: true),
            .fixture(id: "C", number: 3, reviewTarget: .team(name: "time")),
            .fixture(id: "D", number: 4, isDraft: true, reviewTarget: .team(name: "time"))
        ]
        func ids(_ drafts: Bool, _ team: Bool) -> [String] {
            ReviewInclusion.visible(prs, ignoreDrafts: drafts, includeTeam: team).map(\.id)
        }
        #expect(ids(true, false) == ["A"])
        #expect(ids(false, false) == ["A", "B"])
        #expect(ids(true, true) == ["A", "C"])
        #expect(ids(false, true) == ["A", "B", "C", "D"])
    }

    @Test func readyCountUsesMergeReadiness() {
        let snapshot = Snapshot.fixture(mine: [
            .fixture(id: "A", number: 1, reviewDecision: .approved),
            .fixture(id: "B", number: 2, reviewDecision: .reviewRequired),
            .fixture(id: "C", number: 3, isDraft: true, reviewDecision: .approved)
        ])
        #expect(Counters.readyToMerge(snapshot) == 1)
    }

    @Test func failingCIDetected() {
        let ok = Snapshot.fixture(mine: [.fixture(ci: .success(total: 2))])
        let bad = Snapshot.fixture(mine: [.fixture(ci: .success(total: 2)), .fixture(id: "B", number: 2, ci: .failure(failedChecks: ["lint"], total: 2))])
        #expect(!Counters.hasFailingCI(ok))
        #expect(Counters.hasFailingCI(bad))
    }
}
