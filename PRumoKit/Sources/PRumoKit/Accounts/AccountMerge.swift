public enum AccountMerge {
    public static func combine(_ parts: [AccountPart]) -> Snapshot? {
        guard let first = parts.first else { return nil }
        let mine = firstOccurrences(parts.flatMap { $0.snapshot.mine }, id: \.id)
        let mineIDs = Set(mine.map(\.id))
        let toReview = firstOccurrences(
            parts.flatMap { $0.snapshot.toReview }.filter { !mineIDs.contains($0.id) }, id: \.id
        )
        let mergedToday = firstOccurrences(parts.flatMap { $0.snapshot.mergedToday }, id: \.id)
        let accountViewers = parts.reduce(into: [String: String]()) { result, part in
            result.merge(part.snapshot.accountViewers) { current, _ in current }
        }
        return Snapshot(
            viewer: first.snapshot.viewer,
            mine: mine,
            toReview: toReview,
            mergedToday: mergedToday,
            fetchedAt: parts.map { $0.snapshot.fetchedAt }.max() ?? first.snapshot.fetchedAt,
            accountViewers: accountViewers
        )
    }

    public static func events(
        _ perAccount: [(accountID: String, events: [NotificationEvent])], combined: Snapshot
    ) -> [NotificationEvent] {
        let owners = Dictionary(
            (combined.mine + combined.toReview).map { ($0.id, $0.accountID) },
            uniquingKeysWith: { first, _ in first }
        )
        var seen = Set<EventKey>()
        var result: [NotificationEvent] = []
        for event in perAccount.flatMap(\.events) {
            guard owners[event.pullRequestID] == event.accountID else { continue }
            guard seen.insert(EventKey(kind: event.kind, pullRequestID: event.pullRequestID)).inserted else { continue }
            result.append(event)
        }
        return result
    }

    private struct EventKey: Hashable {
        let kind: NotificationKind
        let pullRequestID: String
    }

    private static func firstOccurrences<T>(_ items: [T], id: KeyPath<T, String>) -> [T] {
        var seen = Set<String>()
        return items.filter { seen.insert($0[keyPath: id]).inserted }
    }
}
