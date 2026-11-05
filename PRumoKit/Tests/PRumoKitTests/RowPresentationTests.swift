import Foundation
import Testing
@testable import PRumoKit

@testable import struct PRumoKit.Comment
private typealias RowComment = Comment

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
        #expect(row.badges == [Badge("para você", .accent), Badge("carla", .neutral), Badge("✓ CI 5/5", .positive), Badge("+212 \u{2212}48", .neutral)])
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

    @Test func commentsBadgeIgnoresListedAuthors() {
        let pr = PullRequest.fixture(
            comments: [
                RowComment(id: "c1", author: "github-actions", authorIsBot: false, body: "deploy", url: URL(string: "https://x/1")!, createdAt: .fixed),
                RowComment(id: "c2", author: "ana", authorIsBot: false, body: "ok", url: URL(string: "https://x/2")!, createdAt: .fixed)
            ],
            commentCount: 2
        )
        let filter = CommentAuthorFilter(ignoredAuthors: ["github-actions"])
        let row = RowPresenter.mine(pr, viewer: "adriano", now: .fixed, commentFilter: filter)
        #expect(row.badges.filter { $0.icon == .comments } == [Badge("1", .neutral, .comments)])
    }

    @Test func commentsBadgeAndIndexDisappearWhenOnlyIgnoredAuthorsCommented() {
        let pr = PullRequest.fixture(
            comments: [RowComment(id: "c1", author: "Datadog-Official[bot]", authorIsBot: false, body: "relatório", url: URL(string: "https://x/1")!, createdAt: .fixed)],
            commentCount: 1
        )
        let filter = CommentAuthorFilter(ignoredAuthors: ["datadog-official"])
        let row = RowPresenter.mine(pr, viewer: "adriano", now: .fixed, commentFilter: filter)
        #expect(row.badges.contains { $0.icon == .comments } == false)
        #expect(row.commentsBadgeIndex == nil)
    }

    @Test func commentsBadgeIndexIsNilWithoutCommentsOrChangesRequested() {
        #expect(RowPresenter.mine(.fixture(), viewer: "adriano", now: .fixed).commentsBadgeIndex == nil)
    }

    @Test func commentsBadgeIndexIsNilOnReviewRows() {
        let pr = PullRequest.fixture(reviews: [review("ana", .changesRequested, 1)], commentCount: 3)
        #expect(RowPresenter.review(pr, now: .fixed).commentsBadgeIndex == nil)
    }

    @Test func jiraBadgeIsLastOnMineAndReview() {
        let mine = RowPresenter.mine(.fixture(ci: .success(total: 3), commentCount: 2), viewer: "adriano", now: .fixed, jiraKey: "ON-1234")
        #expect(mine.badges.last == Badge("ON-1234", .neutral))
        let review = RowPresenter.review(.fixture(), now: .fixed, jiraKey: "ON-1234")
        #expect(review.badges.last == Badge("ON-1234", .neutral))
    }

    @Test func noJiraBadgeWithoutKey() {
        let withKey = RowPresenter.mine(.fixture(), viewer: "adriano", now: .fixed, jiraKey: "ON-1")
        let without = RowPresenter.mine(.fixture(), viewer: "adriano", now: .fixed)
        #expect(without.badges.count == withKey.badges.count - 1)
        #expect(!RowPresenter.review(.fixture(), now: .fixed).badges.contains(Badge("ON-1", .neutral)))
    }

    @Test func jiraBadgeIndexPointsToLastBadge() {
        let mine = RowPresenter.mine(.fixture(ci: .success(total: 3), commentCount: 2), viewer: "adriano", now: .fixed, jiraKey: "ON-1234")
        #expect(mine.jiraBadgeIndex == mine.badges.count - 1)
        let review = RowPresenter.review(.fixture(), now: .fixed, jiraKey: "ON-1234")
        #expect(review.jiraBadgeIndex == review.badges.count - 1)
        let merge = RowPresenter.merge(.fixture(), viewer: "adriano", now: .fixed, jiraKey: "ON-9")
        #expect(merge.jiraBadgeIndex == merge.badges.count - 1)
    }

    @Test func jiraBadgeIndexIsNilWithoutKey() {
        #expect(RowPresenter.mine(.fixture(), viewer: "adriano", now: .fixed).jiraBadgeIndex == nil)
        #expect(RowPresenter.review(.fixture(), now: .fixed).jiraBadgeIndex == nil)
        #expect(RowPresenter.merge(.fixture(), viewer: "adriano", now: .fixed).jiraBadgeIndex == nil)
    }

    @Test func jiraBadgeDoesNotShiftActionIndices() {
        let pr = PullRequest.fixture(ci: .failure(failedChecks: ["build"], total: 3), commentCount: 2, mergeable: .conflicting)
        let with = RowPresenter.mine(pr, viewer: "adriano", now: .fixed, jiraKey: "ON-1")
        let without = RowPresenter.mine(pr, viewer: "adriano", now: .fixed)
        #expect(with.ciFailureBadgeIndex == without.ciFailureBadgeIndex)
        #expect(with.conflictBadgeIndex == without.conflictBadgeIndex)
        #expect(with.commentsBadgeIndex == without.commentsBadgeIndex)
    }

    @Test func reviewRowShowsForYouBadgeFirst() {
        let row = RowPresenter.review(.fixture(reviewTarget: .you), now: .fixed)
        #expect(row.badges.first == Badge("para você", .accent))
    }

    @Test func reviewRowShowsTeamName() {
        let row = RowPresenter.review(.fixture(reviewTarget: .team(name: "backend")), now: .fixed)
        #expect(row.badges.first == Badge("time backend", .neutral))
    }

    @Test func mergeRowBadges() {
        let pr = PullRequest.fixture(
            ci: .success(total: 12),
            reviews: [review("ana", .approved, 1), review("bia", .approved, 2)]
        )
        let row = RowPresenter.merge(pr, viewer: "adriano", now: .fixed)
        #expect(row.badges == [Badge("✓ CI 12/12", .positive), Badge("✓ 2 aprovações", .positive), Badge("sem conflito", .positive)])
        #expect(row.subtitle == "acme/loja #812 · agora")
    }

    @Test func mergeRowKeepsJiraBadgeLast() {
        let row = RowPresenter.merge(.fixture(), viewer: "adriano", now: .fixed, jiraKey: "ON-9")
        #expect(row.badges.last == Badge("ON-9", .neutral))
    }

    @Test func compactLineMine() {
        let pr = PullRequest.fixture(
            createdAt: Date.fixed.addingTimeInterval(-2 * 3600),
            ci: .success(total: 3),
            reviews: [review("ana", .approved, 1)]
        )
        #expect(RowPresenter.compactLine(pr, tab: .mine, viewer: "adriano", now: .fixed) == "loja #812 · aprovado · CI ok · 2h")
    }

    @Test func compactLineOmitsCIWhenNone() {
        let pr = PullRequest.fixture(createdAt: Date.fixed.addingTimeInterval(-2 * 3600), ci: .none)
        #expect(RowPresenter.compactLine(pr, tab: .merge, viewer: "adriano", now: .fixed) == "loja #812 · sem review · 2h")
    }

    @Test func compactLineShowsConflictDraftAndChangesRequested() {
        let pr = PullRequest.fixture(
            isDraft: true,
            ci: .failure(failedChecks: ["x"], total: 2),
            reviews: [review("ana", .changesRequested, 1)],
            mergeable: .conflicting
        )
        #expect(RowPresenter.compactLine(pr, tab: .mine, viewer: "adriano", now: .fixed) == "loja #812 · alterações pedidas · CI falhou · conflito · draft · agora")
    }

    @Test func compactLineReview() {
        let pr = PullRequest.fixture(
            number: 815,
            author: "maria",
            reviewRequestedAt: Date.fixed.addingTimeInterval(-40 * 60)
        )
        #expect(RowPresenter.compactLine(pr, tab: .review, viewer: "adriano", now: .fixed) == "loja #815 · maria · para você · 40min")
    }

    @Test func compactLineReviewForTeam() {
        let pr = PullRequest.fixture(reviewTarget: .team(name: "backend"))
        #expect(RowPresenter.compactLine(pr, tab: .review, viewer: "adriano", now: .fixed) == "loja #812 · adriano · time backend · agora")
    }

    @Test func reviewRowShowsWaitBadgeAndAttentionDot() {
        let pr = PullRequest.fixture(reviewRequestedAt: Date.fixed.addingTimeInterval(-26.5 * 3600))
        let row = RowPresenter.review(pr, now: .fixed, staleLimit: 24 * 3600)
        #expect(row.dot == .attention)
        #expect(row.badges.contains(Badge("esperando há 26h", .warning, .clock)))
        let fresh = RowPresenter.review(pr, now: .fixed, staleLimit: 48 * 3600)
        #expect(fresh.dot == .ok)
        #expect(!fresh.badges.contains { $0.icon == .clock })
        #expect(RowPresenter.review(pr, now: .fixed).dot == .ok)
    }

    @Test func failingCIStaysFailedWhenStale() {
        let pr = PullRequest.fixture(
            ci: .failure(failedChecks: ["unit"], total: 3),
            reviewRequestedAt: Date.fixed.addingTimeInterval(-30 * 3600)
        )
        #expect(RowPresenter.review(pr, now: .fixed, staleLimit: 24 * 3600).dot == .failed)
    }
}

@Suite struct RowPresentationAccountTests {
    private let label = AccountLabel(provider: .github, text: "adrianogl")
    private let pr = PullRequest.fixture(createdAt: Date.fixed.addingTimeInterval(-2 * 3600))

    @Test func subtitleWithoutAccountUnchanged() {
        #expect(RowPresenter.mine(pr, viewer: "adriano", now: .fixed).subtitle == "acme/loja #812 · 2h")
    }

    @Test func subtitleWithAccountPrefix() {
        let row = RowPresenter.mine(pr, viewer: "adriano", now: .fixed, account: label)
        #expect(row.subtitle == "adrianogl · acme/loja #812 · 2h")
    }

    @Test func staleAccountShowsLastData() {
        let row = RowPresenter.merge(pr, viewer: "adriano", now: .fixed, staleSince: Date.fixed.addingTimeInterval(-12 * 60))
        #expect(row.subtitle == "acme/loja #812 · último dado 12min atrás")
    }

    @Test func staleAccountWithLabelKeepsPrefix() {
        let row = RowPresenter.review(pr, now: .fixed, account: label, staleSince: Date.fixed.addingTimeInterval(-12 * 60))
        #expect(row.subtitle == "adrianogl · acme/loja #812 · último dado 12min atrás")
    }

    @Test func compactLineWithAccount() {
        let line = RowPresenter.compactLine(pr, tab: .mine, viewer: "adriano", now: .fixed, account: label)
        #expect(line.hasPrefix("adrianogl · loja #812"))
    }

    @Test func providerSetOnlyWithAccount() {
        #expect(RowPresenter.mine(pr, viewer: "adriano", now: .fixed).accountProvider == nil)
        #expect(RowPresenter.mine(pr, viewer: "adriano", now: .fixed, account: label).accountProvider == .github)
    }

    @Test func subtitleUsesReference() {
        let pr = PullRequest.fixture(
            number: 341, repository: "vendas/api", createdAt: Date.fixed.addingTimeInterval(-5 * 3600), provider: .gitlab
        )
        #expect(RowPresenter.mine(pr, viewer: "adriano", now: .fixed).subtitle == "vendas/api !341 · 5h")
    }
}
