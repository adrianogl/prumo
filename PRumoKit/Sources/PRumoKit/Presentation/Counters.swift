public enum Counters {
    public static func reviewBadge(_ s: Snapshot, ignoreDrafts: Bool) -> Int {
        ReviewInclusion.visible(s.toReview, ignoreDrafts: ignoreDrafts, includeTeam: false).count
    }

    public static func hasFailingCI(_ s: Snapshot) -> Bool {
        s.mine.contains { pr in
            if case .failure = pr.ci { return true }
            return false
        }
    }

    public static func readyToMerge(_ s: Snapshot) -> Int {
        s.mine.filter { MergeReadiness.isReady($0, viewer: s.viewer) }.count
    }
}
