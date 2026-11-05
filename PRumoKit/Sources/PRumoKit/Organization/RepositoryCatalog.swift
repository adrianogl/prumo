import Foundation

public enum RepositoryCatalog {
    public static func groups(
        snapshot: Snapshot, known: Set<String>, favorites: Set<String>, hideEmpty: Bool, search: String,
        accounts: [Account] = [], repositoryAccounts: [String: String] = [:]
    ) -> [RepositoryGroup] {
        var seen = Set<String>()
        var counts: [String: Int] = [:]
        var snapshotAccounts: [String: String] = [:]
        for pr in snapshot.mine + snapshot.toReview where seen.insert(pr.id).inserted {
            counts[pr.repositoryKey, default: 0] += 1
            if !pr.accountID.isEmpty, snapshotAccounts[pr.repositoryKey] == nil {
                snapshotAccounts[pr.repositoryKey] = pr.accountID
            }
        }
        let names = known.union(favorites).union(counts.keys)
        let query = search.trimmingCharacters(in: .whitespaces)
        let entries = names
            .filter { query.isEmpty || $0.localizedCaseInsensitiveContains(query) }
            .map {
                RepositoryEntry(
                    name: $0, count: counts[$0] ?? 0, isFavorite: favorites.contains($0), displayName: displayName($0))
            }
            .filter { !hideEmpty || $0.count > 0 || $0.isFavorite }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }

        var groups: [RepositoryGroup] = []
        let favoriteEntries = entries.filter(\.isFavorite)
        if !favoriteEntries.isEmpty {
            groups.append(RepositoryGroup(title: OrganizationText.favoritesTitle, entries: favoriteEntries))
        }
        if accounts.count > 1 {
            let known = Set(accounts.map(\.id))
            let owners = Dictionary(grouping: entries) { entry -> String in
                [snapshotAccounts[entry.name], repositoryAccounts[entry.name]]
                    .compactMap { $0 }.first { known.contains($0) } ?? accounts[0].id
            }
            for account in accounts {
                groups += orgGroups(owners[account.id] ?? [], section: account.displayName)
            }
        } else {
            groups += orgGroups(entries, section: nil)
        }
        return groups
    }

    private static func orgGroups(_ entries: [RepositoryEntry], section: String?) -> [RepositoryGroup] {
        let byOrg = Dictionary(grouping: entries, by: organization)
        return byOrg.keys
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
            .map { RepositoryGroup(title: $0.uppercased(), entries: byOrg[$0] ?? [], section: section) }
    }

    private static func organization(_ entry: RepositoryEntry) -> String {
        let parts = entry.name.split(separator: "/").map(String.init)
        let path = hasHost(entry.name) ? Array(parts.dropFirst()) : parts
        return path.first ?? entry.name
    }

    private static func hasHost(_ key: String) -> Bool {
        key.split(separator: "/", maxSplits: 1).first?.contains(".") ?? false
    }

    private static func displayName(_ key: String) -> String {
        guard hasHost(key), let slash = key.firstIndex(of: "/") else { return key }
        return String(key[key.index(after: slash)...])
    }
}
