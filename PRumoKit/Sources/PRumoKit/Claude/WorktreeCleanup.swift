public enum WorktreeCleanup {
    public static func stale(records: [WorktreeRecord], snapshot: Snapshot) -> [WorktreeRecord] {
        let open = Set((snapshot.mine + snapshot.toReview).map(\.id))
        return records.filter { !open.contains($0.pullRequestID) }
    }
}

extension WorktreeCleanup {
    public static func confirmedClosed(candidates: [WorktreeRecord], states: [String: PRState]) -> [WorktreeRecord] {
        candidates.filter { states[$0.pullRequestID] == .closed || states[$0.pullRequestID] == .merged }
    }
}
