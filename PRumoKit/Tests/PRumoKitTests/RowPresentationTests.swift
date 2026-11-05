import Foundation
import Testing
@testable import PRumoKit

@Suite struct RowPresentationTests {
    private func review(_ author: String, _ state: ReviewState, _ offset: TimeInterval) -> Review {
        Review(id: "\(author)\(offset)", author: author, state: state, submittedAt: Date.fixed.addingTimeInterval(offset))
    }

    @Test func failedCIWinsOverChangesRequested() {
        let pr = PullRequest.fixture(
            ci: .failure(failedChecks: ["unit-tests"], total: 9),
            reviews: [review("ana", .changesRequested, 1)]
        )
        let row = RowPresenter.mine(pr, viewer: "adriano", now: .fixed)
        #expect(row.dot == .failed)
        #expect(row.badges == [Badge("✗ unit-tests", .negative), Badge("alterações pedidas", .negative)])
    }

    @Test func changesRequestedWinsOverPendingCI() {
        let pr = PullRequest.fixture(ci: .pending(done: 4, total: 9), reviews: [review("ana", .changesRequested, 1)])
        #expect(RowPresenter.mine(pr, viewer: "adriano", now: .fixed).dot == .attention)
    }

    @Test func pendingCIIsRunning() {
        let pr = PullRequest.fixture(ci: .pending(done: 4, total: 9))
        let row = RowPresenter.mine(pr, viewer: "adriano", now: .fixed)
        #expect(row.dot == .running)
        #expect(row.badges == [Badge("● CI 4/9", .pending)])
    }

    @Test func badgesForSuccessfulPRWithApprovals() {
        let pr = PullRequest.fixture(
            ci: .success(total: 12),
            reviews: [review("ana", .approved, 1), review("bia", .approved, 2)],
            commentCount: 3
        )
        let row = RowPresenter.mine(pr, viewer: "adriano", now: .fixed)
        #expect(row.dot == .ok)
        #expect(row.badges == [Badge("✓ CI 12/12", .positive, .none), Badge("✓ 2 aprovações", .positive, .none), Badge("3", .neutral, .comments)])
    }

    @Test func noCIBadgeWhenCIIsNone() {
        let row = RowPresenter.mine(.fixture(ci: .none), viewer: "adriano", now: .fixed)
        #expect(row.badges.isEmpty)
    }

    @Test func singularApproval() {
        let pr = PullRequest.fixture(reviews: [review("ana", .approved, 1)])
        #expect(RowPresenter.mine(pr, viewer: "adriano", now: .fixed).badges == [Badge("✓ 1 aprovação", .positive)])
    }

    @Test func latestReviewPerAuthorWinsAndViewerIsIgnored() {
        let pr = PullRequest.fixture(reviews: [
            review("ana", .changesRequested, 1),
            review("ana", .approved, 2),
            review("ana", .commented, 3),
            review("adriano", .approved, 4),
            review("bia", .approved, 5),
            review("bia", .changesRequested, 6),
        ])
        let row = RowPresenter.mine(pr, viewer: "adriano", now: .fixed)
        #expect(row.badges == [Badge("✓ 1 aprovação", .positive), Badge("alterações pedidas", .negative)])
        #expect(row.dot == .attention)
    }

    @Test func draftConflictAndCommentsBadges() {
        let pr = PullRequest.fixture(isDraft: true, commentCount: 1, mergeable: .conflicting)
        let row = RowPresenter.mine(pr, viewer: "adriano", now: .fixed)
        #expect(row.badges == [Badge("draft", .neutral), Badge("conflito", .warning, .conflict), Badge("1", .neutral, .comments)])
    }

    @Test func reviewRowShowsAuthorCIAndDiff() {
        let pr = PullRequest.fixture(author: "carla", ci: .success(total: 5), additions: 212, deletions: 48)
        let row = RowPresenter.review(pr, now: .fixed)
        #expect(row.badges == [Badge("carla", .neutral), Badge("✓ CI 5/5", .positive), Badge("+212 \u{2212}48", .neutral)])
        #expect(row.title == pr.title)
        #expect(row.subtitle == "acme/loja #812 · agora")
    }

    @Test func relativeAgeBuckets() {
        let now = Date.fixed
        #expect(RelativeAge.string(from: now.addingTimeInterval(-59), now: now) == "agora")
        #expect(RelativeAge.string(from: now.addingTimeInterval(-40 * 60), now: now) == "40min")
        #expect(RelativeAge.string(from: now.addingTimeInterval(-5 * 3600), now: now) == "5h")
        #expect(RelativeAge.string(from: now.addingTimeInterval(-3 * 86400), now: now) == "3d")
    }

    @Test func reviewSubtitleUsesReviewRequestedAt() {
        let pr = PullRequest.fixture(
            createdAt: Date.fixed.addingTimeInterval(-3 * 86400),
            reviewRequestedAt: Date.fixed.addingTimeInterval(-40 * 60)
        )
        #expect(RowPresenter.review(pr, now: .fixed).subtitle == "acme/loja #812 · 40min")
    }

    @Test func reviewSubtitleFallsBackToCreatedAt() {
        let pr = PullRequest.fixture(createdAt: Date.fixed.addingTimeInterval(-3 * 86400), reviewRequestedAt: nil)
        #expect(RowPresenter.review(pr, now: .fixed).subtitle == "acme/loja #812 · 3d")
    }

    @Test func mineSubtitleUsesCreatedAt() {
        let pr = PullRequest.fixture(
            createdAt: Date.fixed.addingTimeInterval(-3 * 86400),
            reviewRequestedAt: Date.fixed.addingTimeInterval(-40 * 60)
        )
        #expect(RowPresenter.mine(pr, viewer: "adriano", now: .fixed).subtitle == "acme/loja #812 · 3d")
    }

    @Test func ciFailureBadgeIndexPointsToTheFailedCIBadge() {
        let failed = PullRequest.fixture(ci: .failure(failedChecks: ["unit-tests"], total: 9))
        #expect(RowPresenter.mine(failed, viewer: "adriano", now: .fixed).ciFailureBadgeIndex == 0)
        let passing = PullRequest.fixture(ci: .success(total: 9))
        #expect(RowPresenter.mine(passing, viewer: "adriano", now: .fixed).ciFailureBadgeIndex == nil)
    }

    @Test func conflictBadgeIndexPointsToTheConflictBadge() {
        let conflicting = PullRequest.fixture(ci: .success(total: 3), mergeable: .conflicting)
        let presentation = RowPresenter.mine(conflicting, viewer: "adriano", now: .fixed)
        let index = presentation.conflictBadgeIndex
        #expect(index == 1)
        #expect(presentation.badges[index!].icon == .conflict)
        let clean = PullRequest.fixture(mergeable: .mergeable)
        #expect(RowPresenter.mine(clean, viewer: "adriano", now: .fixed).conflictBadgeIndex == nil)
        #expect(RowPresenter.review(conflicting, now: .fixed).conflictBadgeIndex == nil)
    }

    @Test func failureBadgeFallsBackWhenNoCheckNames() {
        let pr = PullRequest.fixture(ci: .failure(failedChecks: [], total: 7))
        #expect(RowPresenter.mine(pr, viewer: "adriano", now: .fixed).badges == [Badge("✗ CI 7", .negative)])
    }

    @Test func commentsBadgeCountsCommentedReviewsWithBody() {
        let pr = PullRequest.fixture(
            reviews: [
                Review(id: "r1", author: "ana", state: .commented, submittedAt: .fixed, body: "Veja"),
                Review(id: "r2", author: "bia", state: .commented, submittedAt: .fixed, body: " "),
                Review(id: "r3", author: "caio", state: .approved, submittedAt: .fixed, body: "LGTM")
            ],
            commentCount: 1
        )
        let row = RowPresenter.mine(pr, viewer: "adriano", now: .fixed)
        #expect(row.badges.filter { $0.icon == .comments } == [Badge("2", .neutral, .comments)])
    }

    @Test func noCommentsBadgeWhenCommentCountIsZero() {
        let row = RowPresenter.mine(.fixture(commentCount: 0), viewer: "adriano", now: .fixed)
        #expect(row.badges.contains { $0.icon == .comments } == false)
    }

    @Test func commentsBadgeIndexPointsToCommentsBadge() {
        let pr = PullRequest.fixture(commentCount: 2)
        let row = RowPresenter.mine(pr, viewer: "adriano", now: .fixed)
        let index = row.commentsBadgeIndex
        #expect(index != nil)
        #expect(row.badges[index!].icon == .comments)
    }

    @Test func commentsBadgeIndexFallsBackToChangesRequestedBadge() {
        let pr = PullRequest.fixture(reviews: [review("ana", .changesRequested, 1)])
        let row = RowPresenter.mine(pr, viewer: "adriano", now: .fixed)
        let index = row.commentsBadgeIndex
        #expect(index != nil)
        #expect(row.badges[index!] == Badge(PresentationText.changesRequested, .negative))
    }

    @Test func commentsBadgeIndexPrefersCommentsBadgeWhenBothApply() {
        let pr = PullRequest.fixture(reviews: [review("ana", .changesRequested, 1)], commentCount: 1)
        let row = RowPresenter.mine(pr, viewer: "adriano", now: .fixed)
        let index = row.commentsBadgeIndex
        #expect(index != nil)
        #expect(row.badges[index!].icon == .comments)
    }

    @Test func commentsBadgeIndexIsNilWithoutCommentsOrChangesRequested() {
        #expect(RowPresenter.mine(.fixture(), viewer: "adriano", now: .fixed).commentsBadgeIndex == nil)
    }

    @Test func commentsBadgeIndexIsNilOnReviewRows() {
        let pr = PullRequest.fixture(reviews: [review("ana", .changesRequested, 1)], commentCount: 3)
        #expect(RowPresenter.review(pr, now: .fixed).commentsBadgeIndex == nil)
    }
}
