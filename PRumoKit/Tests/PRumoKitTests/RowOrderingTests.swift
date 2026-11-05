import struct Foundation.Date
import Testing
@testable import PRumoKit

@Suite struct RowOrderingTests {
    func muted(_ pr: PullRequest) -> MutedPullRequest {
        MutedPullRequest(id: pr.id, number: pr.number, title: pr.title, repository: pr.repository, mutedAt: .fixed)
    }

    func hours(_ h: Double) -> Date { Date.fixed.addingTimeInterval(-h * 3600) }

    func ids(
        _ prs: [PullRequest], tab: ListTab = .mine, order: SortOrder, group: Bool = false, marks: RowMarks = RowMarks()
    ) -> [[String]] {
        RowOrdering.sections(
            prs, tab: tab, ordering: TabOrdering(order: order, groupByRepository: group), marks: marks, viewer: "adriano"
        ).map { $0.items.map(\.id) }
    }

    @Test(arguments: SortOrder.allCases)
    func pinnedAlwaysTopMutedAlwaysBottom(order: SortOrder) {
        let prs = [
            PullRequest.fixture(id: "A", number: 1, updatedAt: hours(1)),
            .fixture(id: "B", number: 2, updatedAt: hours(2)),
            .fixture(id: "C", number: 3, updatedAt: hours(3)),
            .fixture(id: "D", number: 4, updatedAt: hours(4))
        ]
        let marks = RowMarks(pinned: ["D"], muted: ["A": muted(prs[0])])
        let result = ids(prs, order: order, marks: marks)[0]
        #expect(result.first == "D")
        #expect(result.last == "A")
    }

    @Test func recentActivityBreaksTiesByNumberDescending() {
        let prs = [PullRequest.fixture(id: "A", number: 1), .fixture(id: "B", number: 2)]
        #expect(ids(prs, order: .recentActivity) == [["B", "A"]])
    }

    @Test func createdAtOrders() {
        let prs = [
            PullRequest.fixture(id: "A", number: 1, createdAt: hours(5)),
            .fixture(id: "B", number: 2, createdAt: hours(1)),
            .fixture(id: "C", number: 3, createdAt: hours(9))
        ]
        #expect(ids(prs, order: .oldestFirst) == [["C", "A", "B"]])
        #expect(ids(prs, order: .newestFirst) == [["B", "A", "C"]])
    }

    @Test func repositoryOrderThenNumberDescending() {
        let prs = [
            PullRequest.fixture(id: "A", number: 1, repository: "acme/b"),
            .fixture(id: "B", number: 2, repository: "acme/a"),
            .fixture(id: "C", number: 3, repository: "acme/a")
        ]
        #expect(ids(prs, order: .repository) == [["C", "B", "A"]])
    }

    @Test func needsActionFirstOrder() {
        let changes = Review(id: "c", author: "bia", state: .changesRequested, submittedAt: .fixed)
        let prs = [
            PullRequest.fixture(id: "ok-new", number: 1, updatedAt: hours(1)),
            .fixture(id: "failing", number: 2, updatedAt: hours(5), ci: .failure(failedChecks: [], total: 1)),
            .fixture(id: "changes", number: 3, updatedAt: hours(3), reviews: [changes]),
            .fixture(id: "conflict", number: 4, updatedAt: hours(4), mergeable: .conflicting)
        ]
        #expect(ids(prs, order: .needsActionFirst) == [["changes", "conflict", "failing", "ok-new"]])

        let review = [
            PullRequest.fixture(id: "team", number: 5, updatedAt: hours(1), reviewTarget: .team(name: "t")),
            .fixture(id: "you", number: 6, updatedAt: hours(8), reviewTarget: .you)
        ]
        #expect(ids(review, tab: .review, order: .needsActionFirst) == [["you", "team"]])
    }

    @Test func diffSizeOrder() {
        let prs = [
            PullRequest.fixture(id: "A", number: 1, additions: 5, deletions: 5),
            .fixture(id: "B", number: 2, additions: 100, deletions: 20),
            .fixture(id: "C", number: 3, additions: 50, deletions: 50)
        ]
        #expect(ids(prs, order: .diffSize) == [["B", "C", "A"]])
    }

    @Test func groupByRepositorySections() {
        let prs = [
            PullRequest.fixture(id: "A", number: 1, repository: "acme/b", updatedAt: hours(1)),
            .fixture(id: "B", number: 2, repository: "acme/a", updatedAt: hours(2)),
            .fixture(id: "C", number: 3, repository: "acme/b", updatedAt: hours(3))
        ]
        let marks = RowMarks(pinned: ["C"])
        let sections = RowOrdering.sections(
            prs, tab: .mine, ordering: TabOrdering(order: .recentActivity, groupByRepository: true),
            marks: marks, viewer: "adriano"
        )
        #expect(sections.map { $0.repository } == ["acme/a", "acme/b"])
        #expect(sections.map { $0.items.map { $0.id } } == [["B"], ["C", "A"]])
    }

    @Test func ungroupedIsSingleSectionWithoutRepository() {
        let sections = RowOrdering.sections(
            [.fixture()], tab: .mine, ordering: TabOrdering(), marks: RowMarks(), viewer: "adriano"
        )
        #expect(sections.count == 1)
        #expect(sections[0].repository == nil)
    }
}
