import Foundation

public enum StuckCI {
    public static func since(pr: PullRequest, now: Date, threshold: TimeInterval) -> TimeInterval? {
        guard case .pending = pr.ci, let start = pr.ciPendingSince else { return nil }
        let elapsed = now.timeIntervalSince(start)
        return elapsed >= threshold ? elapsed : nil
    }

    public static func stuckRunIDs(pr: PullRequest, now: Date, threshold: TimeInterval) -> [Int] {
        guard case .pending = pr.ci else { return [] }
        return pr.pendingRuns.filter { now.timeIntervalSince($0.since) >= threshold }.map(\.id)
    }

    public static func isCancelable(pr: PullRequest, now: Date, threshold: TimeInterval) -> Bool {
        !stuckRunIDs(pr: pr, now: now, threshold: threshold).isEmpty
    }

    public static func text(_ elapsed: TimeInterval) -> String {
        let minutes = max(0, Int(elapsed / PresentationMetrics.secondsPerMinute))
        let duration = minutes < PresentationMetrics.minutesPerHour
            ? "\(minutes) \(PresentationText.minuteUnit)"
            : "\(minutes / PresentationMetrics.minutesPerHour) \(PresentationText.hourUnit)"
        return "\(PresentationText.ciStuckPrefix) \(duration)"
    }
}
