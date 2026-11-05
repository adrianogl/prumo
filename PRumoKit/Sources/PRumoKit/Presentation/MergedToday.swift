import Foundation

public enum MergedToday {
    public static func items(_ list: [MergedPullRequest], now: Date, calendar: Calendar) -> [MergedPullRequest] {
        let startOfDay = calendar.startOfDay(for: now)
        return list
            .filter { $0.mergedAt >= startOfDay }
            .sorted { $0.mergedAt > $1.mergedAt }
    }
}
