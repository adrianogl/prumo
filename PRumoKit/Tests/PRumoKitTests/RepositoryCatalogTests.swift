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
}
