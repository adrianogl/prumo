import Testing
@testable import PRumoKit

private let paths = [
    "acme/loja": "~/Code/acme/loja",
    "acme/api": "~/Code/acme/api",
    "beta/app": "~/Code/pessoal/beta-app",
    "solto": "~/Code/solto",
]

private let repositories = ["beta/app", "acme/loja", "solto", "acme/api"]

private func groups(relevant: Set<String> = [], onlyRelevant: Bool = false, query: String = "") -> [CloneGroup] {
    CloneListing.groups(
        repositories: repositories, relevant: relevant, onlyRelevant: onlyRelevant, query: query,
        path: { paths[$0] ?? "" })
}

@Suite struct CloneListingTests {
    @Test func groupsByOwnerSorted() {
        #expect(groups() == [
            CloneGroup(owner: "acme", repositories: ["acme/api", "acme/loja"]),
            CloneGroup(owner: "beta", repositories: ["beta/app"]),
            CloneGroup(owner: "solto", repositories: ["solto"]),
        ])
    }

    @Test func onlyRelevantKeepsRepositoriesFromPullRequests() {
        let result = groups(relevant: ["Acme/Loja", "outro/repo"], onlyRelevant: true)
        #expect(result == [CloneGroup(owner: "acme", repositories: ["acme/loja"])])
    }

    @Test func relevantIsIgnoredWhenShowingAll() {
        #expect(groups(relevant: ["acme/loja"], onlyRelevant: false).count == 3)
    }

    @Test func queryMatchesRepositoryIgnoringCase() {
        #expect(groups(query: "  LOJA ") == [CloneGroup(owner: "acme", repositories: ["acme/loja"])])
    }

    @Test func queryMatchesPath() {
        #expect(groups(query: "Pessoal") == [CloneGroup(owner: "beta", repositories: ["beta/app"])])
    }

    @Test func queryCombinesWithOnlyRelevant() {
        #expect(groups(relevant: ["acme/loja"], onlyRelevant: true, query: "api").isEmpty)
    }

    @Test func repositoryWithoutSlashUsesWholeNameAsOwner() {
        #expect(groups(query: "solto") == [CloneGroup(owner: "solto", repositories: ["solto"])])
    }
}
