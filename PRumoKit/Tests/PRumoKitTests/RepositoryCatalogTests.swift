import Foundation
import Testing
@testable import PRumoKit

@Suite struct RepositoryCatalogTests {
    let snapshot = Snapshot.fixture(
        mine: [
            .fixture(id: "A", repository: "globex/web-app"),
            .fixture(id: "B", repository: "globex/web-app"),
            .fixture(id: "C", repository: "contoso/backend")
        ],
        toReview: [
            .fixture(id: "B", repository: "globex/web-app"),
            .fixture(id: "D", repository: "globex/api-pedidos")
        ]
    )

    @Test func catalogGroupsFavoritesFirstWithCounts() {
        let groups = RepositoryCatalog.groups(
            snapshot: snapshot, known: ["contoso/menu-sso"], favorites: ["contoso/backend"], hideEmpty: false, search: ""
        )
        #expect(groups.map(\.title) == ["FAVORITOS", "CONTOSO", "GLOBEX"])
        #expect(groups[0].entries == [RepositoryEntry(name: "contoso/backend", count: 1, isFavorite: true)])
        #expect(groups[1].entries.map(\.name) == ["contoso/backend", "contoso/menu-sso"])
        #expect(groups[1].entries.map(\.count) == [1, 0])
        #expect(groups[2].entries.map(\.name) == ["globex/api-pedidos", "globex/web-app"])
        #expect(groups[2].entries.map(\.count) == [1, 2])
    }

    @Test func catalogSortsIgnoringCase() {
        let groups = RepositoryCatalog.groups(
            snapshot: Snapshot.fixture(), known: ["Zeta/b", "acme/Z", "acme/a"], favorites: [], hideEmpty: false, search: ""
        )
        #expect(groups.map(\.title) == ["ACME", "ZETA"])
        #expect(groups[0].entries.map(\.name) == ["acme/a", "acme/Z"])
    }

    @Test func catalogHidesEmptyButKeepsFavorites() {
        let groups = RepositoryCatalog.groups(
            snapshot: snapshot, known: ["contoso/menu-sso", "acme/vazio"], favorites: ["acme/vazio"], hideEmpty: true,
            search: ""
        )
        let names = groups.flatMap(\.entries).map(\.name)
        #expect(!names.contains("contoso/menu-sso"))
        #expect(names.contains("acme/vazio"))
        #expect(groups.map(\.title) == ["FAVORITOS", "ACME", "CONTOSO", "GLOBEX"])
    }

    @Test func catalogSearch() {
        let groups = RepositoryCatalog.groups(
            snapshot: snapshot, known: [], favorites: ["contoso/backend"], hideEmpty: false, search: "WEB"
        )
        #expect(groups.map(\.title) == ["GLOBEX"])
        #expect(groups[0].entries.map(\.name) == ["globex/web-app"])
    }

    private let accountA = Account(id: "a", login: "ana", origin: .pasted)
    private let accountB = Account(id: "b", login: "bia", origin: .pasted)

    private func multiAccountGroups(
        snapshot: Snapshot, known: Set<String> = [], favorites: Set<String> = [],
        repositoryAccounts: [String: String] = [:]
    ) -> [RepositoryGroup] {
        RepositoryCatalog.groups(
            snapshot: snapshot, known: known, favorites: favorites, hideEmpty: false, search: "",
            accounts: [accountA, accountB], repositoryAccounts: repositoryAccounts)
    }

    @Test func singleAccountGroupsUnchanged() {
        let plain = RepositoryCatalog.groups(
            snapshot: snapshot, known: ["contoso/menu-sso"], favorites: ["contoso/backend"], hideEmpty: false, search: "")
        let single = RepositoryCatalog.groups(
            snapshot: snapshot, known: ["contoso/menu-sso"], favorites: ["contoso/backend"], hideEmpty: false, search: "",
            accounts: [accountA], repositoryAccounts: [:])
        #expect(single == plain)
        #expect(single.allSatisfy { $0.section == nil })
    }

    @Test func groupsByAccountThenOrg() {
        let multi = Snapshot.fixture(
            mine: [
                .fixture(id: "1", repository: "acme/web", accountID: "a"),
                .fixture(id: "2", repository: "acme/api", accountID: "a"),
                .fixture(id: "3", repository: "globex/portal", accountID: "b")
            ])
        let groups = multiAccountGroups(snapshot: multi)
        #expect(groups.map(\.title) == ["ACME", "GLOBEX"])
        #expect(groups.map(\.section) == [accountA.displayName, accountB.displayName])
        #expect(groups[0].entries.map(\.name) == ["acme/api", "acme/web"])
        #expect(groups[1].entries.map(\.name) == ["globex/portal"])
    }

    @Test func knownRepoWithoutPRsUsesLearnedAccount() {
        let multi = Snapshot.fixture(mine: [.fixture(id: "1", repository: "acme/web", accountID: "a")])
        let groups = multiAccountGroups(
            snapshot: multi, known: ["globex/legado", "acme/orfao"], repositoryAccounts: ["globex/legado": "b"])
        let globex = groups.first { $0.title == "GLOBEX" }
        #expect(globex?.section == accountB.displayName)
        let orphan = groups.first { $0.entries.contains { $0.name == "acme/orfao" } }
        #expect(orphan?.section == accountA.displayName)
    }

    @Test func repoVisibleByTwoAccountsListedOnce() {
        let multi = Snapshot.fixture(
            mine: [.fixture(id: "1", repository: "acme/web", accountID: "b")],
            toReview: [.fixture(id: "2", repository: "acme/web", accountID: "a")])
        let groups = multiAccountGroups(snapshot: multi)
        #expect(groups.flatMap(\.entries).map(\.name) == ["acme/web"])
        #expect(groups[0].section == accountB.displayName)
    }

    @Test func favoritesStayOnTop() {
        let multi = Snapshot.fixture(
            mine: [
                .fixture(id: "1", repository: "acme/web", accountID: "a"),
                .fixture(id: "3", repository: "globex/portal", accountID: "b")
            ])
        let groups = multiAccountGroups(snapshot: multi, favorites: ["globex/portal"])
        #expect(groups.map(\.title) == ["FAVORITOS", "ACME", "GLOBEX"])
        #expect(groups[0].section == nil)
        #expect(groups[0].entries.map(\.name) == ["globex/portal"])
        #expect(groups[2].section == accountB.displayName)
        #expect(groups[2].entries.map(\.name) == ["globex/portal"])
    }

    @Test func catalogGroupsGitLabByFirstPathSegment() {
        let gitlab = Snapshot.fixture(mine: [
            .fixture(
                id: "G", url: URL(string: "https://gitlab.empresa.com/vendas/api/-/merge_requests/7")!,
                repository: "vendas/api", provider: .gitlab)
        ])
        let groups = RepositoryCatalog.groups(snapshot: gitlab, known: [], favorites: [], hideEmpty: false, search: "")
        #expect(groups.map(\.title) == ["VENDAS"])
        #expect(groups[0].entries.map(\.name) == ["gitlab.empresa.com/vendas/api"])
        #expect(groups[0].entries.map(\.count) == [1])
    }

    @Test func displayNameDropsHost() {
        let gitlab = Snapshot.fixture(mine: [
            .fixture(
                id: "G", url: URL(string: "https://gitlab.empresa.com/vendas/api/-/merge_requests/7")!,
                repository: "vendas/api", provider: .gitlab)
        ])
        let groups = RepositoryCatalog.groups(snapshot: gitlab, known: ["globex/web"], favorites: [], hideEmpty: false, search: "")
        let entries = groups.flatMap(\.entries)
        #expect(entries.first { $0.name == "gitlab.empresa.com/vendas/api" }?.displayName == "vendas/api")
        #expect(entries.first { $0.name == "globex/web" }?.displayName == "globex/web")
        #expect(RepositoryEntry(name: "a/b", count: 0, isFavorite: false).displayName == "a/b")
    }

    @Test func publicDisplayNameDropsGitLabHostOnly() {
        #expect(RepositoryCatalog.displayName("gitlab.empresa.com/vendas/api") == "vendas/api")
        #expect(RepositoryCatalog.displayName("globex/web") == "globex/web")
    }
}
