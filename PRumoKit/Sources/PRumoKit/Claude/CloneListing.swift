import Foundation

public struct CloneListing {
    public static func groups(
        repositories: [String], relevant: Set<String>, onlyRelevant: Bool, query: String,
        path: (String) -> String
    ) -> [CloneGroup] {
        let relevantKeys = Set(relevant.map { $0.lowercased() })
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let visible = repositories.filter { repository in
            if onlyRelevant && !relevantKeys.contains(repository.lowercased()) { return false }
            if needle.isEmpty { return true }
            return repository.lowercased().contains(needle) || path(repository).lowercased().contains(needle)
        }
        let byOwner = Dictionary(grouping: visible, by: owner(of:))
        return byOwner.keys.sorted().map { key in
            CloneGroup(owner: key, repositories: byOwner[key, default: []].sorted())
        }
    }

    static func owner(of repository: String) -> String {
        repository.split(separator: "/", maxSplits: 1).first.map(String.init) ?? repository
    }
}
