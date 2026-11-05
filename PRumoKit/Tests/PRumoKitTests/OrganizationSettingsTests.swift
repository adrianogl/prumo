import Foundation
import Testing
@testable import PRumoKit

@Suite struct OrganizationSettingsTests {
    @Test func emptyJSONDecodesToDefaults() throws {
        let settings = try JSONDecoder().decode(OrganizationSettings.self, from: Data("{}".utf8))
        #expect(settings.ignoreDraftsInReview == true)
        #expect(settings.includeTeamRequests == false)
        #expect(settings.rowStyle == .detailed)
        #expect(settings.ordering(for: .review) == TabOrdering())
        #expect(settings == OrganizationSettings.defaults)
    }

    @Test func partialNestedJSONDecodesWithDefaults() throws {
        let json = #"{"filter":{"ci":["failing"]},"orderings":{"review":{"groupByRepository":true}},"marks":{"pinned":["a"]}}"#
        let settings = try JSONDecoder().decode(OrganizationSettings.self, from: Data(json.utf8))
        #expect(settings.filter.ci == [.failing])
        #expect(settings.filter.authors.isEmpty)
        #expect(settings.ordering(for: .review) == TabOrdering(order: .recentActivity, groupByRepository: true))
        #expect(settings.marks.isPinned("a"))
        #expect(settings.marks.muted.isEmpty)
    }

    @Test func roundTripCodable() throws {
        var settings = OrganizationSettings.defaults
        settings.filter = RowFilter(repositories: ["o/r"], ci: [.failing], review: [.noReview], state: [.pinned], request: [.stale], authors: ["ana"])
        settings.setOrdering(TabOrdering(order: .diffSize, groupByRepository: true), for: .merge)
        settings.views = [SavedView(name: "Urgentes", filter: settings.filter)]
        settings.favorites = ["o/r"]
        settings.knownRepositories = ["o/r", "o/s"]
        settings.hideEmptyRepositories = true
        settings.rowStyle = .compact
        settings.ignoreDraftsInReview = false
        settings.includeTeamRequests = true
        settings.marks = RowMarks(
            pinned: ["p1"],
            muted: ["m1": MutedPullRequest(id: "m1", number: 7, title: "T", repository: "o/r", mutedAt: Date(timeIntervalSince1970: 1_000))]
        )
        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(OrganizationSettings.self, from: data)
        #expect(decoded == settings)
        #expect(decoded.ordering(for: .merge).order == .diffSize)
    }

    @Test func criteriaCountIgnoresRepositories() {
        let filter = RowFilter(repositories: ["a", "b", "c"], ci: [.passed, .failing], review: [.approved], state: [.noDrafts], request: [.forYou], authors: ["x", "y"])
        #expect(filter.criteriaCount == 7)
        #expect(RowFilter.empty.criteriaCount == 0)
    }

    @Test func marksPrunedOnlyWhenClosedOrMerged() {
        let muted = { (id: String) in MutedPullRequest(id: id, number: 1, title: "t", repository: "o/r", mutedAt: Date(timeIntervalSince1970: 0)) }
        let marks = RowMarks(
            pinned: ["open", "closed", "merged", "unknown"],
            muted: ["open": muted("open"), "closed": muted("closed"), "merged": muted("merged")]
        )
        let pruned = marks.pruned(states: ["open": .open, "closed": .closed, "merged": .merged])
        #expect(pruned.pinned == ["open", "unknown"])
        #expect(Set(pruned.muted.keys) == ["open"])
        #expect(pruned.isMuted("open"))
        #expect(!pruned.isMuted("closed"))
    }
}
