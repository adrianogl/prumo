import Foundation
import Testing
@testable import PRumoKit

@Suite struct RowOrderingTests {
    func muted(_ pr: PullRequest) -> MutedPullRequest {
        MutedPullRequest(id: pr.id, number: pr.number, title: pr.title, repository: pr.repository, mutedAt: .fixed)
    }

    func hours(_ h: Double) -> Date { Date.fixed.addingTimeInterval(-h * 3600) }

    func ids(
        _ prs: [PullRequest], tab: ListTab = .mine, order: RowSortOrder, group: Bool = false, marks: RowMarks = RowMarks()
    ) -> [[String]] {
        RowOrdering.sections(
            prs, tab: tab, ordering: TabOrdering(order: order, groupByRepository: group), marks: marks, viewer: { _ in "adriano" }
        ).map { $0.items.map(\.id) }
    }

    @Test(arguments: RowSortOrder.allCases)
    func pinnedAlwaysTopMutedAlwaysBottom(order: RowSortOrder) {
        let prs = [
            PullRequest.fixture(id: "A", number: 1, updatedAt: hours(1)),
            .fixture(id: "B", number: 2, updatedAt: hours(2)),
            .fixture(id: "C", number: 3, updatedAt: hours(3)),
            .fixture(id: "D", number: 4, updatedAt: hours(4)),
            .fixture(id: "E", number: 5, updatedAt: hours(5))
        ]
        let marks = RowMarks(pinned: ["D", "E"], muted: ["A": muted(prs[0]), "E": muted(prs[4])])
        let result = ids(prs, order: order, marks: marks)[0]
        let base = ids(prs, order: order)[0]
        let pinnedOnly = base.filter { $0 == "D" }
        let plain = base.filter { ["B", "C"].contains($0) }
        let mutedOnes = base.filter { ["A", "E"].contains($0) }
        #expect(result == pinnedOnly + plain + mutedOnes)
        #expect(result.first == "D")
        #expect(Set(result.suffix(2)) == ["A", "E"])
    }

    @Test func totalOrderIgnoresInputOrder() {
        let prs = [
            PullRequest.fixture(id: "X", number: 7, repository: "acme/b", updatedAt: .fixed),
            .fixture(id: "Y", number: 7, repository: "acme/a", updatedAt: .fixed)
        ]
        for order in RowSortOrder.allCases {
            #expect(ids(prs, order: order) == [["Y", "X"]])
            #expect(ids(prs.reversed(), order: order) == [["Y", "X"]])
        }
    }

    @Test func repositoryOrderIgnoresCase() {
        let prs = [
            PullRequest.fixture(id: "A", number: 1, repository: "Zeta/x"),
            .fixture(id: "B", number: 2, repository: "acme/x")
        ]
        #expect(ids(prs, order: .repository) == [["B", "A"]])
        #expect(ids(prs, order: .recentActivity, group: true) == [["B"], ["A"]])
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
            marks: marks, viewer: { _ in "adriano" }
        )
        #expect(sections.map { $0.repository } == ["acme/a", "acme/b"])
        #expect(sections.map { $0.items.map { $0.id } } == [["B"], ["C", "A"]])
    }

    @Test func ungroupedIsSingleSectionWithoutRepository() {
        let sections = RowOrdering.sections(
            [.fixture()], tab: .mine, ordering: TabOrdering(), marks: RowMarks(), viewer: { _ in "adriano" }
        )
        #expect(sections.count == 1)
        #expect(sections[0].repository == nil)
    }

    @Test func orderingNeedsActionUsesViewerClosure() {
        let ownChanges = Review(id: "R1", author: "adriano-globex", state: .changesRequested, submittedAt: .fixed)
        let prs = [
            PullRequest.fixture(id: "A", number: 1, updatedAt: hours(1)),
            .fixture(id: "B", number: 2, updatedAt: hours(2), reviews: [ownChanges], accountID: "a2")
        ]
        let viewers = ["a2": "adriano-globex"]
        let sections = RowOrdering.sections(
            prs, tab: .mine, ordering: TabOrdering(order: .needsActionFirst), marks: RowMarks(),
            viewer: { viewers[$0.accountID] ?? "adriano" }
        )
        #expect(sections[0].items.map(\.id) == ["A", "B"])
        let plain = RowOrdering.sections(
            prs, tab: .mine, ordering: TabOrdering(order: .needsActionFirst), marks: RowMarks(), viewer: { _ in "adriano" }
        )
        #expect(plain[0].items.map(\.id) == ["B", "A"])
    }

    @Test func sameProjectPathOnTwoHostsAreDistinct() {
        let prs = [
            PullRequest.fixture(
                id: "A", url: URL(string: "https://gitlab.um.com/vendas/api/-/merge_requests/1")!,
                repository: "vendas/api", provider: .gitlab),
            .fixture(
                id: "B", url: URL(string: "https://gitlab.dois.com/vendas/api/-/merge_requests/1")!,
                repository: "vendas/api", provider: .gitlab)
        ]
        let sections = RowOrdering.sections(
            prs, tab: .mine, ordering: TabOrdering(order: .recentActivity, groupByRepository: true),
            marks: RowMarks(), viewer: { _ in "adriano" })
        #expect(sections.map(\.repository) == ["gitlab.dois.com/vendas/api", "gitlab.um.com/vendas/api"])
    }
}
