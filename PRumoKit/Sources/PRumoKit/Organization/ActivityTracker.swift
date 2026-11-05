public enum ActivityTracker {
    public static func touched(old: Snapshot?, new: Snapshot, events: [NotificationEvent]) -> Set<String> {
        guard let old else { return [] }
        var ids = Set(events.map(\.pullRequestID))
        var previousSHAs: [String: String] = [:]
        for pullRequest in old.mine + old.toReview where !pullRequest.headSHA.isEmpty {
            previousSHAs[pullRequest.id] = pullRequest.headSHA
        }
        for pullRequest in new.mine + new.toReview {
            if let previous = previousSHAs[pullRequest.id], previous != pullRequest.headSHA {
                ids.insert(pullRequest.id)
            }
        }
        return ids
    }

    public static func pruned(_ unseen: Set<String>, snapshot: Snapshot) -> Set<String> {
        unseen.intersection(Set((snapshot.mine + snapshot.toReview).map(\.id)))
    }
}
