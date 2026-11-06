import Foundation
import Testing
@testable import PRumoKit

struct PullRequestActivityTests {
    private let comment = URL(string: "https://github.com/acme/loja/pull/812#c1")!

    @Test func ordersReviewsCommentsAndCIFromNewest() {
        let pr = PullRequest.fixture(
            ci: .failure(failedChecks: ["unit-tests"], total: 2),
            reviews: [Review(id: "r1", author: "carla", state: .approved, submittedAt: .fixed.addingTimeInterval(-3600))],
            comments: [Comment(id: "c1", author: "joao", authorIsBot: false, body: "ok", url: comment, createdAt: .fixed.addingTimeInterval(-7200))],
            checks: [
                CheckRun(name: "unit-tests", state: .failure, startedAt: .fixed.addingTimeInterval(-900), completedAt: .fixed.addingTimeInterval(-720)),
                CheckRun(name: "lint", state: .success, startedAt: .fixed.addingTimeInterval(-900), completedAt: .fixed.addingTimeInterval(-860)),
            ])

        let items = PullRequestActivity.items(for: pr)

        #expect(items.map(\.id) == ["ci", "r1", "c1"])
        #expect(items[0].kind == .ciFailed(checks: ["unit-tests"]))
        #expect(items[0].date == .fixed.addingTimeInterval(-720))
        #expect(items[1].actor == "carla")
    }

    @Test func dropsPendingReviewsAndEmptyCommentReviews() {
        let pr = PullRequest.fixture(reviews: [
            Review(id: "p", author: "a", state: .pending, submittedAt: .fixed),
            Review(id: "e", author: "b", state: .commented, submittedAt: .fixed, body: "  "),
            Review(id: "c", author: "c", state: .commented, submittedAt: .fixed, body: "ajusta o nome"),
            Review(id: "x", author: "d", state: .changesRequested, submittedAt: .fixed),
        ])
        #expect(PullRequestActivity.items(for: pr).map(\.id).sorted() == ["c", "x"])
    }

    @Test func runningCIUsesPendingSinceAndNoDateMeansNoItem() {
        let running = PullRequest.fixture(ci: .pending(done: 1, total: 3), ciPendingSince: .fixed)
        #expect(PullRequestActivity.items(for: running).map(\.kind) == [.ciRunning])
        let passedWithoutDates = PullRequest.fixture(ci: .success(total: 3))
        #expect(PullRequestActivity.items(for: passedWithoutDates).isEmpty)
    }

    @Test func respectsLimit() {
        let reviews = (0..<30).map { Review(id: "r\($0)", author: "a", state: .approved, submittedAt: .fixed.addingTimeInterval(Double($0))) }
        let items = PullRequestActivity.items(for: .fixture(reviews: reviews), limit: 5)
        #expect(items.map(\.id) == ["r29", "r28", "r27", "r26", "r25"])
    }
}
