import Foundation
import Testing
@testable import PRumoKit

@Suite struct OrganizationSettingsTests {
    @Test func emptyJSONDecodesToDefaults() throws {
        let settings = try JSONDecoder().decode(OrganizationSettings.self, from: Data("{}".utf8))
        #expect(settings.ignoreDraftsInReview == true)
        #expect(settings.includeTeamRequests == true)
        #expect(settings.rowStyle == .detailed)
        #expect(settings.ordering(for: .review) == TabOrdering())
        #expect(settings == OrganizationSettings.defaults)
    }

    @Test func organizationDefaultsIncludeTeam() {
        #expect(OrganizationSettings.defaults.includeTeamRequests == true)
        #expect(OrganizationSettings().includeTeamRequests == true)
    }

    @Test func jsonWithoutTeamKeyDecodesToIncluded() throws {
        let settings = try JSONDecoder().decode(OrganizationSettings.self, from: Data(#"{"rowStyle":"compact"}"#.utf8))
        #expect(settings.includeTeamRequests == true)
    }

    @Test func savedTeamOptionOffIsRespected() throws {
        let settings = try JSONDecoder().decode(OrganizationSettings.self, from: Data(#"{"includeTeamRequests":false}"#.utf8))
        #expect(settings.includeTeamRequests == false)
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

    @Test func jsonWithoutIgnoredCommentAuthorsDecodesToDefaultList() throws {
        let settings = try JSONDecoder().decode(OrganizationSettings.self, from: Data(#"{"rowStyle":"compact"}"#.utf8))
        #expect(settings.ignoredCommentAuthors == ["github-actions", "datadog-official"])
        #expect(OrganizationSettings.defaults.ignoredCommentAuthors == ["github-actions", "datadog-official"])
    }

    @Test func invalidIgnoredCommentAuthorsFallBackToDefaultList() throws {
        let settings = try JSONDecoder().decode(OrganizationSettings.self, from: Data(#"{"ignoredCommentAuthors":7}"#.utf8))
        #expect(settings.ignoredCommentAuthors == ["github-actions", "datadog-official"])
    }

    @Test func savedEmptyIgnoredCommentAuthorsIsRespected() throws {
        let settings = try JSONDecoder().decode(OrganizationSettings.self, from: Data(#"{"ignoredCommentAuthors":[]}"#.utf8))
        #expect(settings.ignoredCommentAuthors.isEmpty)
        #expect(settings.commentAuthorFilter == .none)
    }

    @Test func commentAuthorFilterUsesNormalizedList() {
        var settings = OrganizationSettings.defaults
        settings.ignoredCommentAuthors = [" Sonar[bot] ", ""]
        #expect(settings.commentAuthorFilter.ignoredAuthors == ["sonar"])
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
        settings.ignoredCommentAuthors = ["sonarcloud"]
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

    @Test func unknownEnumValuesAreDiscardedWithoutLosingTheRest() throws {
        let json = #"{"orderings":{"review":{"order":"futuro","groupByRepository":true}},"rowStyle":"x","filter":{"ci":["failing","novo"],"review":["desconhecido"]},"marks":{"pinned":["a"]}}"#
        let settings = try JSONDecoder().decode(OrganizationSettings.self, from: Data(json.utf8))
        #expect(settings.marks.isPinned("a"))
        #expect(settings.rowStyle == .detailed)
        #expect(settings.ordering(for: .review) == TabOrdering(order: .recentActivity, groupByRepository: true))
        #expect(settings.filter.ci == [.failing])
        #expect(settings.filter.review.isEmpty)
    }

    @Test func topLevelUnknownOrderIsDiscarded() throws {
        let json = #"{"orderings":{"review":{"order":"futuro"},"merge":{"order":"diffSize"}},"marks":{"pinned":["a"]}}"#
        let settings = try JSONDecoder().decode(OrganizationSettings.self, from: Data(json.utf8))
        #expect(settings.ordering(for: .review).order == .recentActivity)
        #expect(settings.ordering(for: .merge).order == .diffSize)
        #expect(settings.marks.isPinned("a"))
    }

    @Test func invalidSavedViewsAreDroppedIndividually() throws {
        let valid = UUID()
        let json = """
        {"views":[
        {"id":"\(valid.uuidString)","name":"Boa","filter":{"ci":["failing"]}},
        {"id":"\(UUID().uuidString)","name":"Ruim","filter":"quebrado"},
        {"name":"Sem id","filter":{}},
        {"id":"nao-e-uuid","name":"Id ruim"}
        ],"marks":{"pinned":["a"]}}
        """
        let settings = try JSONDecoder().decode(OrganizationSettings.self, from: Data(json.utf8))
        #expect(settings.views.map(\.id).contains(valid))
        #expect(settings.views.map(\.name).contains("Boa"))
        #expect(!settings.views.contains { $0.name == "Sem id" || $0.name == "Id ruim" })
        #expect(settings.views.first { $0.id == valid }?.filter.ci == [.failing])
        #expect(settings.marks.isPinned("a"))
    }

    @Test func invalidMutedItemsAreDroppedIndividually() throws {
        let json = #"{"marks":{"muted":{"ok":{"id":"ok","number":3,"title":"T","repository":"o/r","mutedAt":1000},"semId":{"number":1,"title":"x"},"lixo":42,"parcial":{"id":"parcial"}}}}"#
        let settings = try JSONDecoder().decode(OrganizationSettings.self, from: Data(json.utf8))
        #expect(settings.marks.isMuted("ok"))
        #expect(settings.marks.muted["ok"]?.number == 3)
        #expect(settings.marks.isMuted("parcial"))
        #expect(!settings.marks.isMuted("semId"))
        #expect(!settings.marks.isMuted("lixo"))
    }

    @Test func oldOrganizationJSONWithoutRepositoryAccountsDecodes() throws {
        let json = #"{"favorites":["acme/web"],"knownRepositories":["acme/web"]}"#
        let settings = try JSONDecoder().decode(OrganizationSettings.self, from: Data(json.utf8))
        #expect(settings.repositoryAccounts.isEmpty)
        #expect(settings.favorites == ["acme/web"])
    }

    @Test func repositoryAccountsRoundTrips() throws {
        var settings = OrganizationSettings()
        settings.repositoryAccounts = ["acme/web": "a"]
        let decoded = try JSONDecoder().decode(OrganizationSettings.self, from: JSONEncoder().encode(settings))
        #expect(decoded.repositoryAccounts == ["acme/web": "a"])
    }
}
