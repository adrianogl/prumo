import Foundation

public enum NotificationPipeline {
    public static func run(
        events: [NotificationEvent], snapshot: Snapshot, preferences: NotificationPreferences,
        muted: Set<String>, ignoreDrafts: Bool, includeTeam: Bool, reminders: ReminderState,
        now: Date, calendar: Calendar
    ) -> PipelineResult {
        let quiet = QuietPolicy.isQuiet(now: now, dnd: preferences.dnd, hours: preferences.workingHours, calendar: calendar)
        var deliver = quiet ? [] : events.filter { preferences.isEnabled($0.kind) && !muted.contains($0.pullRequestID) }
        var state = reminders

        func due() -> [StaleReminder] {
            StaleReviewTracker.due(
                snapshot: snapshot,
                limit: TimeInterval(preferences.staleReviewHours) * ReminderConstants.secondsPerHour,
                reminded: Set(state.reminded), muted: muted,
                ignoreDrafts: ignoreDrafts, includeTeam: includeTeam, now: now
            )
        }

        if !state.initialized {
            state.insert(due().map(\.key))
            state.initialized = true
        } else if !quiet {
            let stale = due()
            state.insert(stale.map(\.key))
            if preferences.isEnabled(.staleReview) {
                deliver += stale.map(\.event)
            }
        }
        return PipelineResult(deliver: deliver, reminders: state)
    }
}
