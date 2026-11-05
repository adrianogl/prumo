import Foundation
import Testing
@testable import PRumoKit

@Suite struct RowFilteringTests {
    let context = FilterContext(viewer: "adriano", now: .fixed)

    func ids(_ prs: [PullRequest], _ filter: RowFilter, tab: ListTab = .mine, context: FilterContext? = nil) -> [String] {
        RowFiltering.apply(prs, filter: filter, tab: tab, context: context ?? self.context).map(\.id)
    }

    func approval(_ author: String = "ana") -> Review {
        Review(id: "r-\(author)", author: author, state: .approved, submittedAt: .fixed)
    }

    @Test func emptyFilterKeepsAll() {
        let prs = [PullRequest.fixture(id: "A"), .fixture(id: "B", isDraft: true)]
        #expect(ids(prs, .empty) == ["A", "B"])
    }

    @Test func repositorySelectionFilters() {
        let prs = [
            PullRequest.fixture(id: "A", repository: "acme/loja"),
            .fixture(id: "B", repository: "acme/api")
        ]
        #expect(ids(prs, RowFilter(repositories: ["acme/api"])) == ["B"])
    }

    @Test func ciGroupIsOrWithinAndAcrossGroups() {
        let prs = [
            PullRequest.fixture(id: "A", ci: .failure(failedChecks: ["x"], total: 3)),
            .fixture(id: "B", ci: .pending(done: 1, total: 3)),
            .fixture(id: "C", ci: .success(total: 3), reviews: [approval()]),
            .fixture(id: "D", ci: .success(total: 3))
        ]
        #expect(ids(prs, RowFilter(ci: [.failing, .running])) == ["A", "B"])
        #expect(ids(prs, RowFilter(ci: [.passed], review: [.approved])) == ["C"])
    }

    @Test func noChecksCountsAsPassed() {
        let prs = [PullRequest.fixture(id: "A", ci: .none), .fixture(id: "B", ci: .pending(done: 0, total: 2))]
        #expect(ids(prs, RowFilter(ci: [.passed])) == ["A"])
    }

    @Test func reviewGroupUsesSummary() {
        let changes = Review(id: "c", author: "bia", state: .changesRequested, submittedAt: .fixed)
        let prs = [
            PullRequest.fixture(id: "A", reviews: [approval()]),
            .fixture(id: "B", reviews: [approval(), changes]),
            .fixture(id: "C")
        ]
        #expect(ids(prs, RowFilter(review: [.approved])) == ["A"])
        #expect(ids(prs, RowFilter(review: [.changesRequested])) == ["B"])
        #expect(ids(prs, RowFilter(review: [.noReview])) == ["C"])
    }

    @Test func noDraftsExcludesDrafts() {
        let prs = [PullRequest.fixture(id: "A"), .fixture(id: "B", isDraft: true)]
        #expect(ids(prs, RowFilter(state: [.noDrafts])) == ["A"])
    }

    @Test func stateFiltersAreOrBetweenThemselves() {
        let prs = [
            PullRequest.fixture(id: "A", mergeable: .conflicting),
            .fixture(id: "B"),
            .fixture(id: "C"),
            .fixture(id: "D", isDraft: true, mergeable: .conflicting)
        ]
        let ctx = FilterContext(viewer: "adriano", marks: RowMarks(pinned: ["B"]), unseen: ["C"], now: .fixed)
        #expect(ids(prs, RowFilter(state: [.conflicting, .pinned]), context: ctx) == ["A", "B", "D"])
        #expect(ids(prs, RowFilter(state: [.noDrafts, .conflicting, .newActivity]), context: ctx) == ["A", "C"])
    }

    @Test func requestFilterOnlyAppliesToReviewTab() {
        let prs = [
            PullRequest.fixture(id: "A", reviewTarget: .you),
            .fixture(id: "B", reviewTarget: .team(name: "time"))
        ]
        let filter = RowFilter(request: [.forTeam])
        #expect(ids(prs, filter, tab: .review) == ["B"])
        #expect(ids(prs, filter, tab: .mine) == ["A", "B"])
        #expect(ids(prs, RowFilter(request: [.forYou]), tab: .review) == ["A"])
    }

    @Test func staleRequestFilterUsesLimit() {
        let old = Date.fixed.addingTimeInterval(-25 * 3600)
        let recent = Date.fixed.addingTimeInterval(-2 * 3600)
        let prs = [
            PullRequest.fixture(id: "A", createdAt: old, reviewRequestedAt: recent),
            .fixture(id: "B", createdAt: recent, reviewRequestedAt: old),
            .fixture(id: "C", createdAt: old)
        ]
        let filter = RowFilter(request: [.stale])
        #expect(ids(prs, filter, tab: .review) == ["B", "C"])
        let strict = FilterContext(viewer: "adriano", staleLimit: 1 * 3600, now: .fixed)
        #expect(ids(prs, filter, tab: .review, context: strict) == ["A", "B", "C"])
    }

    @Test func authorFilterIgnoresCase() {
        let prs = [PullRequest.fixture(id: "A", author: "Ana"), .fixture(id: "B", author: "bia")]
        #expect(ids(prs, RowFilter(authors: ["ana"])) == ["A"])
    }

    static let gitlabURL = URL(string: "https://gitlab.empresa.com/vendas/api/-/merge_requests/7")!

    @Test func filterMatchesGitLabByKey() {
        let prs = [
            PullRequest.fixture(id: "G", url: Self.gitlabURL, repository: "vendas/api", provider: .gitlab),
            .fixture(id: "H", repository: "globex/vendas")
        ]
        #expect(ids(prs, RowFilter(repositories: ["gitlab.empresa.com/vendas/api"])) == ["G"])
        #expect(ids(prs, RowFilter(repositories: ["vendas/api"])).isEmpty)
    }

    @Test func githubKeysUnchanged() {
        let pr = PullRequest.fixture(id: "A", repository: "acme/loja")
        #expect(pr.repositoryKey == "acme/loja")
        #expect(ids([pr], RowFilter(repositories: ["acme/loja"])) == ["A"])
    }
}
