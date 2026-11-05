import Foundation

public enum RepositoryCatalog {
    public static func groups(
        snapshot: Snapshot, known: Set<String>, favorites: Set<String>, hideEmpty: Bool, search: String
    ) -> [RepositoryGroup] {
        var seen = Set<String>()
        var counts: [String: Int] = [:]
        for pr in snapshot.mine + snapshot.toReview where seen.insert(pr.id).inserted {
            counts[pr.repository, default: 0] += 1
        }
        let names = known.union(favorites).union(counts.keys)
        let query = search.trimmingCharacters(in: .whitespaces)
        let entries = names
            .filter { query.isEmpty || $0.localizedCaseInsensitiveContains(query) }
            .map { RepositoryEntry(name: $0, count: counts[$0] ?? 0, isFavorite: favorites.contains($0)) }
            .filter { !hideEmpty || $0.count > 0 || $0.isFavorite }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }

        var groups: [RepositoryGroup] = []
        let favoriteEntries = entries.filter(\.isFavorite)
        if !favoriteEntries.isEmpty {
            groups.append(RepositoryGroup(title: OrganizationText.favoritesTitle, entries: favoriteEntries))
        }
        let byOrg = Dictionary(grouping: entries, by: organization)
        let orgs = byOrg.keys.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        for org in orgs {
            groups.append(RepositoryGroup(title: org.uppercased(), entries: byOrg[org] ?? []))
        }
        return groups
    }

    private static func organization(_ entry: RepositoryEntry) -> String {
        entry.name.split(separator: "/", maxSplits: 1).first.map(String.init) ?? entry.name
    }
}
